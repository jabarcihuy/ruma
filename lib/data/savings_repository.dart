import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'finance.dart';
import 'savings.dart';

/// Per-account savings; production writes require the savings Rules rollout.
class SavingsRepository {
  SavingsRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  static const _server = GetOptions(source: Source.server);
  DocumentReference<Map<String, dynamic>> get _user =>
      db.collection('users').doc(uid);

  void _check() {
    if (auth.currentUser?.uid != uid) {
      throw const FinanceFailure('Sesi akun berubah. Buka kembali tabungan.');
    }
  }

  String newId() => _user.collection('savingsGoals').doc().id;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _all(
    String collection,
  ) async {
    // ponytail: coursework ceiling of 1000 documents per collection, including
    // history. Introduce paged history/server reconciliation before raising it.
    final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    while (true) {
      Query<Map<String, dynamic>> query = _user
          .collection(collection)
          .limit(100);
      if (result.isNotEmpty) query = query.startAfterDocument(result.last);
      final page = await query
          .get(_server)
          .timeout(const Duration(seconds: 15));
      _check();
      result.addAll(page.docs);
      if (result.length > 1000) {
        throw const FinanceFailure(
          'Catatan tabungan melebihi batas tahap ini. Ringkasan tidak ditampilkan sebagian.',
        );
      }
      if (page.size < 100) return result;
    }
  }

  Future<SavingsSnapshot> read() async {
    _check();
    final coreRef = _user.collection('state').doc('core');
    final before = await coreRef
        .get(_server)
        .timeout(const Duration(seconds: 15));
    final summary = await _user
        .collection('state')
        .doc('savings')
        .get(_server)
        .timeout(const Duration(seconds: 15));
    final goals = await _all('savingsGoals');
    final movements = await _all('savingsMovements');
    final after = await coreRef
        .get(_server)
        .timeout(const Duration(seconds: 15));
    _check();
    if ((before.data()?['financeRevision'] ?? 0) !=
        (after.data()?['financeRevision'] ?? 0)) {
      throw const FinanceFailure('Keuangan berubah. Muat ulang tabungan.');
    }
    final result = SavingsSnapshot(
      goals:
          goals
              .map(
                (d) => SavingsGoal(
                  id: d.id,
                  version: d.data()['version'] as int,
                  balanceRupiah: d.data()['balanceRupiah'] as int,
                  input: _goal(d.data()),
                ),
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id)),
      movements:
          movements
              .map(
                (d) => SavingsMovement(
                  id: d.id,
                  goalId: d.data()['goalId'] as String,
                  input: SavingsMovementInput(
                    type: d.data()['type'] as String,
                    amountRupiah: d.data()['amountRupiah'] as int,
                    localDate: d.data()['localDate'] as String,
                    description: d.data()['description'] as String,
                  ),
                ),
              )
              .toList()
            ..sort((a, b) {
              final date = b.input.localDate.compareTo(a.input.localDate);
              return date != 0 ? date : a.id.compareTo(b.id);
            }),
      recordedBalance: after.data()?['balanceRupiah'] as int? ?? 0,
      totalSavedRupiah: summary.data()?['totalSavedRupiah'] as int? ?? 0,
      revision: after.data()?['financeRevision'] as int? ?? 0,
    );
    result.verify();
    return result;
  }

  Future<void> save(SavingsMutation m) async {
    _check();
    final error = m.validate();
    if (error != null) throw FinanceFailure(error);
    final coreRef = _user.collection('state').doc('core');
    final summaryRef = _user.collection('state').doc('savings');
    final goalRef = _user.collection('savingsGoals').doc(m.goalId);
    final receiptRef = _user.collection('operations').doc(m.operationId);
    final movementRef = _user.collection('savingsMovements').doc(m.operationId);
    // Preserve the existing online-only write contract; no queued offline save.
    await coreRef.get(_server).timeout(const Duration(seconds: 15));
    _check();
    await db.runTransaction(
      (tx) async {
        _check();
        final receipt = await tx.get(receiptRef);
        if (receipt.exists) {
          if (receipt.data()?['kind'] != m.kind ||
              receipt.data()?['result']?['requestKey'] != m.requestKey) {
            throw const FinanceFailure(
              'Permintaan sudah diproses dengan isian berbeda.',
            );
          }
          return;
        }
        final core = (await tx.get(coreRef)).data();
        final prior = (await tx.get(goalRef)).data();
        final summary = (await tx.get(summaryRef)).data();
        if (m.originalVersion == null
            ? prior != null
            : prior == null || prior['version'] != m.originalVersion) {
          throw const FinanceFailure(
            'Tujuan sudah berubah. Muat ulang sebelum menyimpan.',
          );
        }
        final before = prior?['balanceRupiah'] as int? ?? 0;
        final total = summary?['totalSavedRupiah'] as int? ?? 0;
        final next = m.balanceAfter(
          goalBalance: before,
          totalSaved: total,
          recordedBalance: core?['balanceRupiah'] as int? ?? 0,
        );
        final now = FieldValue.serverTimestamp();
        final version = (prior?['version'] as int? ?? 0) + 1;
        Map<String, dynamic> metadata(Map<String, dynamic>? old) => {
          'schemaVersion': 1,
          'version': (old?['version'] as int? ?? 0) + 1,
          'createdAt': old?['createdAt'] ?? now,
          'updatedAt': now,
        };
        tx.set(goalRef, {
          ...metadata(prior),
          ...(m.goal ?? _goal(prior!)).toJson(),
          'balanceRupiah': next,
          'operationId': m.operationId,
        });
        if (m.movement != null) {
          tx.set(movementRef, {
            ...metadata(null),
            'goalId': m.goalId,
            'operationId': m.operationId,
            'source': 'manual',
            ...m.movement!.toJson(),
          });
        }
        tx.set(summaryRef, {
          ...metadata(summary),
          'totalSavedRupiah': total + next - before,
          'operationId': m.operationId,
        });
        tx.set(coreRef, {
          ...metadata(core),
          'agendaRevision': core?['agendaRevision'] ?? 0,
          'financeRevision': (core?['financeRevision'] as int? ?? 0) + 1,
          'balanceRupiah': core?['balanceRupiah'] ?? 0,
          'lifetimeIncomeRupiah': core?['lifetimeIncomeRupiah'] ?? 0,
          'lifetimeExpenseRupiah': core?['lifetimeExpenseRupiah'] ?? 0,
          'lastUndoOperationId': m.operationId,
        });
        tx.set(receiptRef, {
          ...metadata(null),
          'draftId': 'manual',
          'approvedRevision': 1,
          'kind': m.kind,
          'targets': [
            'savingsGoals/${m.goalId}',
            if (m.movement != null) 'savingsMovements/${m.operationId}',
          ],
          'result': {
            'entityId': m.goalId,
            'version': version,
            'movementId': m.movement == null ? null : m.operationId,
            'requestKey': m.requestKey,
          },
          'undoState': 'unavailable',
        });
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    _check();
  }
}

SavingsGoalInput _goal(Map<String, dynamic> d) => SavingsGoalInput(
  name: d['name'] as String,
  targetRupiah: d['targetRupiah'] as int,
  targetDate: d['targetDate'] as String?,
  iconId: d['iconId'] as String?,
);
