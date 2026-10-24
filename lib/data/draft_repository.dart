import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'agenda_repository.dart';
import 'agenda.dart';
import 'recurrence.dart';
import 'finance.dart';
import 'assistant_draft.dart';
import 'assistant_snapshot.dart';
import 'agent_tools.dart';

class DraftRepository {
  DraftRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  DocumentReference<Map<String, dynamic>> get user =>
      db.collection('users').doc(uid);
  String newId() => user.collection('operations').doc().id;
  void check() {
    if (auth.currentUser?.uid != uid) {
      throw const DraftFailure(
        'Sesi akun berubah. Draf akun lama tidak dapat digunakan.',
      );
    }
  }

  Future<(int, String?)> readAssistant() async {
    check();
    final result = await user
        .collection('assistant')
        .doc('session')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    if (!result.exists) return (0, null);
    final d = result.data()!;
    if (d['schemaVersion'] != 1 ||
        d['revision'] is! int ||
        d['revision'] < 1 ||
        d['payload'] is! String) {
      throw const DraftFailure(
        'Format riwayat tidak didukung. Data tidak ditimpa.',
      );
    }
    return (d['revision'] as int, d['payload'] as String);
  }

  Future<int> writeAssistant(String payload, int expected) async {
    check();
    if (payload.length > assistantPayloadLimit) {
      throw const DraftFailure('Riwayat terlalu besar.');
    }
    final ref = user.collection('assistant').doc('session');
    final version = await db.runTransaction<int>(
      (tx) async {
        check();
        final old = (await tx.get(ref)).data(), version = old?['revision'] ?? 0;
        if (old?['payload'] == payload &&
            (version == expected || version == expected + 1)) {
          return version as int;
        }
        if (version != expected) {
          throw const DraftFailure(
            'Riwayat berubah di perangkat lain. Muat ulang sebelum melanjutkan.',
          );
        }
        tx.set(ref, {
          'schemaVersion': 1,
          'revision': expected + 1,
          'payload': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return expected + 1;
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    check();
    return version;
  }

  Future<bool> recordReceipt(RecordDraft d, {bool undo = false}) async {
    check();
    final id = undo ? d.undoOperationId : d.operationId;
    if (id == null) return false;
    final key = d.agenda != null
        ? AgendaMutation(
            operationId: id,
            id: d.id,
            originalVersion: d.version + (undo ? 1 : 0),
            input: undo ? d.beforeAgenda! : d.agenda!,
            delete: !undo && d.delete,
            restore: undo && d.delete,
          ).requestKey
        : FinanceMutation(
            operationId: id,
            id: d.id,
            originalVersion: d.version + (undo ? 1 : 0),
            input: undo ? d.beforeMoney! : d.money!,
            delete: !undo && d.delete,
            restore: undo && d.delete,
          ).requestKey;
    final op = await user
        .collection('operations')
        .doc(id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    if (!op.exists) return false;
    if (op.data()?['result']?['requestKey'] != key) {
      throw const DraftFailure('Bukti penyimpanan tidak cocok dengan draf.');
    }
    return true;
  }

  Future<Map<String, int>> revisions() async {
    check();
    final d = await user
        .collection('state')
        .doc('core')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    return {
      'agenda': d.data()?['agendaRevision'] ?? 0,
      'finance': d.data()?['financeRevision'] ?? 0,
    };
  }

  Future<bool> receipt(AssistantDraft d) async {
    check();
    final r = await user
        .collection('operations')
        .doc(d.operationId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    if (!r.exists) return false;
    if (r.data()?['result']?['requestKey'] != d.requestKey) {
      throw const DraftFailure(
        'Identitas penyimpanan dipakai oleh draf berbeda.',
      );
    }
    return true;
  }

  Future<void> apply(AssistantDraft d) async {
    check();
    if (d.uid != uid) throw const DraftFailure('Draf bukan milik sesi aktif.');
    final invalid = d.validate();
    if (invalid != null) throw DraftFailure(invalid);
    if (await receipt(d)) {
      d.applied = true;
      return;
    }
    final agenda = await AgendaRepository(db, auth).read();
    final entries = d.included.toList(),
        agendas = entries.where((e) => e.agenda != null).toList(),
        money = entries.where((e) => e.money != null).toList();
    for (var i = 0; i < agendas.length; i++) {
      final a = agendas[i].agenda!;
      if ((a.startAtUtc == null
                  ? agenda.items
                  : agenda.between(
                      a.startAtUtc!.subtract(const Duration(days: 1)),
                      a.endAtUtc!.add(const Duration(days: 1)),
                    ))
              .any((old) => old.input.overlaps(a)) ||
          agendas.take(i).any((old) => old.agenda!.overlaps(a))) {
        throw const DraftFailure(
          'Ada jam kegiatan yang berbenturan. Ubah draf; tidak ada item yang disimpan.',
        );
      }
    }
    if (agenda.revision != d.baseAgendaRevision) {
      throw const DraftFailure(
        'Agenda berubah sejak draf dibuat. Tinjau ulang sebelum menyimpan.',
      );
    }
    final cr = user.collection('state').doc('core'),
        op = user.collection('operations').doc(d.operationId);
    final key = d.requestKey;
    d.attempted = true;
    await db.runTransaction(
      (tx) async {
        check();
        if (key != d.requestKey) {
          throw const DraftFailure('Draf berubah saat penyimpanan.');
        }
        final r = await tx.get(op);
        if (r.exists) {
          if (r.data()?['result']?['requestKey'] != key) {
            throw const DraftFailure(
              'Draf berbeda memakai identitas simpan yang sama.',
            );
          }
          return;
        }
        final core = (await tx.get(cr)).data();
        if ((core?['agendaRevision'] ?? 0) != d.baseAgendaRevision ||
            (core?['financeRevision'] ?? 0) != d.baseFinanceRevision) {
          throw const DraftFailure(
            'Catatan berubah sejak draf dibuat. Tinjau ulang; belum ada item yang disimpan.',
          );
        }
        for (final e in entries) {
          final target = await tx.get(
            user
                .collection(e.agenda != null ? 'agenda' : 'transactions')
                .doc(e.id),
          );
          if (target.exists) {
            throw const DraftFailure(
              'Identitas item sudah digunakan. Muat ulang tinjauan.',
            );
          }
        }
        final months = <String, Map<String, dynamic>?>{};
        for (final month in money.map((e) => e.money!.monthKey).toSet()) {
          months[month] = (await tx.get(user.collection('months').doc(month)))
              .data();
        }
        check();
        final now = FieldValue.serverTimestamp();
        Map<String, dynamic> base() => {
          'schemaVersion': 1,
          'version': 1,
          'createdAt': now,
          'updatedAt': now,
        };
        for (final e in agendas) {
          final a = e.agenda!;
          tx.set(user.collection('agenda').doc(e.id), {
            ...base(),
            'deletedAt': null,
            'operationId': d.operationId,
            'kind': a.kind,
            'title': a.title.trim(),
            'description': a.description,
            'startAtUtc': a.startAtUtc == null
                ? null
                : Timestamp.fromDate(a.startAtUtc!),
            'endAtUtc': a.endAtUtc == null
                ? null
                : Timestamp.fromDate(a.endAtUtc!),
            'durationMinutes': a.durationMinutes,
            'deadlineAtUtc': a.deadlineAtUtc == null
                ? null
                : Timestamp.fromDate(a.deadlineAtUtc!),
            'priority': a.priority,
            'status': a.status,
            'timezone': 'Asia/Jakarta',
            'recurrence': {'type': 'none'},
          });
        }
        for (final e in money) {
          tx.set(user.collection('transactions').doc(e.id), {
            ...base(),
            'deletedAt': null,
            'operationId': d.operationId,
            ...e.money!.toJson(),
            'monthKey': e.money!.monthKey,
            'source': 'ai',
          });
        }
        for (final m in months.entries) {
          final previous = m.value;
          final inputs = money
              .where((e) => e.money!.monthKey == m.key)
              .map((e) => e.money!)
              .toList();
          tx.set(user.collection('months').doc(m.key), {
            ...base(),
            'version': (previous?['version'] as int? ?? 0) + 1,
            'createdAt': previous?['createdAt'] ?? now,
            'operationId': d.operationId,
            'incomeRupiah':
                (previous?['incomeRupiah'] as int? ?? 0) +
                inputs.fold<int>(0, (a, b) => a + b.income),
            'expenseRupiah':
                (previous?['expenseRupiah'] as int? ?? 0) +
                inputs.fold<int>(0, (a, b) => a + b.expense),
            'categoryExpenseRupiah': {
              for (final c in expenseCategories.keys)
                c:
                    (previous?['categoryExpenseRupiah']?[c] as int? ?? 0) +
                    inputs
                        .where((t) => t.categoryId == c)
                        .fold<int>(0, (a, b) => a + b.expense),
            },
            'budgetTotalRupiah': previous?['budgetTotalRupiah'],
            'categoryBudgetRupiah':
                previous?['categoryBudgetRupiah'] ??
                {for (final c in expenseCategories.keys) c: null},
          });
        }
        final income = money.fold<int>(0, (a, b) => a + b.money!.income),
            expense = money.fold<int>(0, (a, b) => a + b.money!.expense);
        tx.set(cr, {
          ...base(),
          'version': (core?['version'] as int? ?? 0) + 1,
          'createdAt': core?['createdAt'] ?? now,
          'agendaRevision': d.baseAgendaRevision + (agendas.isEmpty ? 0 : 1),
          'financeRevision': d.baseFinanceRevision + (money.isEmpty ? 0 : 1),
          'balanceRupiah':
              (core?['balanceRupiah'] as int? ?? 0) + income - expense,
          'lifetimeIncomeRupiah':
              (core?['lifetimeIncomeRupiah'] as int? ?? 0) + income,
          'lifetimeExpenseRupiah':
              (core?['lifetimeExpenseRupiah'] as int? ?? 0) + expense,
          'lastUndoOperationId': d.operationId,
        });
        tx.set(op, {
          ...base(),
          'draftId': d.id,
          'approvedRevision': d.revision,
          'kind': 'create_batch',
          'targets': entries
              .map(
                (e) =>
                    '${e.agenda != null ? 'agenda' : 'transactions'}/${e.id}',
              )
              .toList(),
          'result': {
            'agendaIds': agendas.map((e) => e.id).toList(),
            'transactionIds': money.map((e) => e.id).toList(),
            'requestKey': key,
          },
          'undoState': 'unavailable',
        });
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    check();
    d.applied = true;
  }
}
