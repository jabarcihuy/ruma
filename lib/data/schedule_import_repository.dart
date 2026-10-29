import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'agenda.dart';
import 'agenda_repository.dart';
import 'assistant_draft.dart';
import 'recurrence.dart';
import 'reminders.dart';
import 'schedule_import.dart';

class ImportNeedsReview extends DraftFailure {
  const ImportNeedsReview(super.message);
}

class ImportPreviewRow {
  ImportPreviewRow(
    this.row, {
    this.input,
    this.existing,
    this.action = 'new',
    this.message = '',
    this.blocked = false,
    this.requiresChoice = false,
  });
  final ScheduleRow row;
  final AgendaInput? input;
  final AgendaItem? existing;
  String action, message;
  bool blocked;
  final bool requiresChoice;
  bool get writes =>
      row.included && !blocked && ['new', 'update', 'delete'].contains(action);
}

class ImportPreview {
  const ImportPreview(this.rows, this.revision, {this.error = ''});
  final List<ImportPreviewRow> rows;
  final int revision;
  final String error;
  List<ImportPreviewRow> get writes => rows.where((r) => r.writes).toList();
  bool get canSave =>
      error.isEmpty &&
      !rows.any((r) => r.row.included && r.blocked) &&
      writes.isNotEmpty;
}

class ScheduleImportRepository {
  ScheduleImportRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  DocumentReference<Map<String, dynamic>> get user =>
      db.collection('users').doc(uid);
  void check() {
    if (auth.currentUser?.uid != uid) {
      throw const DraftFailure('Sesi berubah. Buka impor dari akunmu.');
    }
  }

  String newId() => user.collection('agenda').doc().id;

  Future<List<Map<String, dynamic>>> previousSources(
    String calendarKey,
  ) async =>
      (await _sourceRecords(calendarKey))
          .map((r) => r.data()['importSource'] as Map<String, dynamic>)
          .toList();
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _sourceRecords(
    String key,
  ) async {
    check();
    final result = await user
        .collection('agenda')
        .where('importSource.calendarKey', isEqualTo: key)
        .limit(501)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    if (result.docs.length > 500) {
      throw const DraftFailure(
        'Riwayat impor terlalu besar. Persempit kalender sumber.',
      );
    }
    return result.docs;
  }

  AgendaItem _item(String id, Map<String, dynamic> d) => AgendaItem(
    id: id,
    version: d['version'] as int,
    importSource: d['importSource'] == null
        ? null
        : Map<String, dynamic>.from(d['importSource'] as Map),
    input: AgendaInput(
      title: d['title'] as String,
      description: d['description'] as String,
      kind: d['kind'] as String,
      durationMinutes: d['durationMinutes'] as int,
      startAtUtc: (d['startAtUtc'] as Timestamp?)?.toDate().toUtc(),
      deadlineAtUtc: (d['deadlineAtUtc'] as Timestamp?)?.toDate().toUtc(),
      priority: d['priority'] as String,
      status: d['status'] as String,
      recurrence: d['recurrence']?['type'] == 'weekly'
          ? Map<String, dynamic>.from(d['recurrence'] as Map)
          : null,
    ),
  );

  Future<ImportPreview> preview(ScheduleWorkspace w) async {
    check();
    final snapshot = await AgendaRepository(db, auth).read();
    final bases = [
      ...snapshot.singles ??
          snapshot.items.where((a) => a.input.recurrence == null),
      ...snapshot.series,
    ];
    final bySource = {
      for (final a in bases)
        if (a.importSource != null) a.importSource!['key'] as String: a,
    };
    final deleted = <String>{};
    for (final key
        in w.rows
            .where((r) => r.calendarKey.isNotEmpty)
            .map((r) => r.calendarKey)
            .toSet()) {
      for (final doc in await _sourceRecords(key)) {
        final a = _item(doc.id, doc.data());
        bySource[a.importSource!['key'] as String] = a;
        if (doc.data()['deletedAt'] != null) deleted.add(a.id);
      }
    }
    final identities = {for (final a in bases) scheduleIdentity(a.input): a};
    final selected = <String>{};
    final rows = <ImportPreviewRow>[];
    for (final row in w.rows) {
      final existing = bySource[row.sourceKey];
      if (row.cancelled) {
        rows.add(
          ImportPreviewRow(
            row,
            input: existing?.input,
            existing: existing,
            action: existing == null || deleted.contains(existing.id)
                ? 'skip'
                : 'delete',
            message: existing == null || deleted.contains(existing.id)
                ? 'Pembatalan sudah tercermin di Ruma.'
                : 'Sumber dibatalkan: usulan menghapus salinan Ruma.',
          ),
        );
        continue;
      }
      final invalid = row.validate(w.from, w.to);
      if (invalid != null) {
        rows.add(
          ImportPreviewRow(
            row,
            existing: existing,
            message: invalid,
            blocked: true,
          ),
        );
        continue;
      }
      final input = row.build(w.from, w.to),
          fingerprint = scheduleFingerprint(input),
          identity = scheduleIdentity(input);
      if (existing != null && deleted.contains(existing.id)) {
        rows.add(
          ImportPreviewRow(
            row,
            input: input,
            existing: existing,
            action: 'skip',
            message: 'Sudah dihapus di Ruma. Tidak diimpor kembali otomatis.',
          ),
        );
      } else if (existing != null) {
        final oldFingerprint = existing.importSource!['fingerprint'];
        if (scheduleFingerprint(existing.input) == fingerprint ||
            existing.importSource!['version'] == row.sourceVersion &&
                oldFingerprint == (row.originalFingerprint ?? fingerprint)) {
          rows.add(
            ImportPreviewRow(
              row,
              input: input,
              existing: existing,
              action: 'skip',
              message: 'Sudah ada di Ruma.',
            ),
          );
        } else if (oldFingerprint != scheduleFingerprint(existing.input) &&
            !row.useSource) {
          rows.add(
            ImportPreviewRow(
              row,
              input: input,
              existing: existing,
              action: 'update',
              blocked: true,
              requiresChoice: true,
              message: 'Salinan Ruma sudah disunting. Pilih versi yang ingin dipertahankan.',
            ),
          );
        } else {
          rows.add(
            ImportPreviewRow(
              row,
              input: input,
              existing: existing,
              action: 'update',
              message: 'Perubahan sumber siap ditinjau.',
            ),
          );
        }
      } else if (identities.containsKey(identity)) {
        rows.add(
          ImportPreviewRow(
            row,
            input: input,
            existing: identities[identity],
            action: 'skip',
            message: 'Jadwal yang sama sudah ada; tidak dibuat ulang.',
          ),
        );
      } else if (row.included && !selected.add(identity)) {
        rows.add(
          ImportPreviewRow(
            row,
            input: input,
            action: 'skip',
            message: 'Duplikat dengan baris lain pada impor ini.',
          ),
        );
      } else {
        rows.add(ImportPreviewRow(row, input: input, message: 'Jadwal baru.'));
      }
    }
    final writes = rows.where((r) => r.writes).toList();
    final replaced = writes
        .map((r) => r.existing?.id)
        .whereType<String>()
        .toSet();
    final retained = bases.where((a) => !replaced.contains(a.id)).toList();
    for (final candidate in writes.where((r) => r.action != 'delete')) {
      final occurrences = scheduleOccurrences(
        candidate.input!,
        'candidate',
        w.from,
        w.to,
      );
      String? conflict;
      for (final occurrence in occurrences) {
        if (occurrence.input.status != 'planned') continue;
        final low = occurrence.input.startAtUtc!,
            high = occurrence.input.endAtUtc!;
        final existing = [
          ...retained.where((a) => a.input.recurrence == null),
          ...expandWeekly(
            retained.where((a) => a.input.recurrence != null).toList(),
            low,
            high,
          ),
        ];
        final other = writes
            .where((r) => r != candidate && r.action != 'delete')
            .expand(
              (r) => scheduleOccurrences(r.input!, 'other', w.from, w.to),
            );
        for (final a in [...existing, ...other]) {
          if (occurrence.input.overlaps(a.input)) {
            conflict =
                'Bentrok dengan “${a.input.title}” pada ${agendaLocal(low).toIso8601String().substring(0, 10)}.';
            break;
          }
        }
        if (conflict != null) break;
      }
      if (conflict != null) {
        candidate.blocked = true;
        candidate.message = conflict;
      }
    }
    var weight = 0;
    for (final row in rows.where((r) => r.writes)) {
      weight++;
      if (row.existing != null) {
        final reminder = await user
            .collection('reminders')
            .doc(row.existing!.id)
            .get(const GetOptions(source: Source.server));
        weight += reminder.exists ? 2 : 1;
      }
    }
    check();
    return ImportPreview(
      rows,
      snapshot.revision,
      error:
          retained.where((a) => a.input.recurrence != null).length +
                  writes
                      .where(
                        (r) =>
                            r.action != 'delete' && r.input?.recurrence != null,
                      )
                      .length >
              30
          ? 'Ruma mendukung maksimal 30 seri aktif. Kurangi pilihan atau arsipkan seri lama.'
          : !w.periodConfirmed
          ? 'Pilih tanggal awal dan akhir periode terlebih dahulu.'
          : writes.length > scheduleImportLimit
          ? 'Pilih maksimal $scheduleImportLimit jadwal untuk satu persetujuan.'
          : weight > 18
          ? 'Pilih lebih sedikit perubahan sekaligus agar seluruh pilihan tersimpan bersama.'
          : '',
    );
  }

  void prepare(ScheduleWorkspace w, ImportPreview preview) {
    if (w.locked || !preview.canSave) {
      throw const DraftFailure(
        'Selesaikan informasi dan bentrokan sebelum menyimpan.',
      );
    }
    w.operationId = newId();
    w.baseRevision = preview.revision;
    w.plans = preview.writes
        .map(
          (r) => {
            'id': r.existing?.id ?? newId(),
            'version': r.existing?.version ?? 0,
            'delete': r.action == 'delete',
            'input': r.input!.toJson(),
            'source': r.row.cancelled
                ? r.existing!.importSource
                : r.row.source(r.input!),
          },
        )
        .toList();
    if (w.requestKey.length > 120000) {
      w.plans = [];
      throw const DraftFailure(
        'Tinjauan terlalu besar. Pilih lebih sedikit jadwal.',
      );
    }
  }

  Future<int> apply(ScheduleWorkspace w) async {
    check();
    if (w.operationId.isEmpty ||
        w.plans.isEmpty ||
        w.plans.length > scheduleImportLimit) {
      throw const DraftFailure('Persetujuan impor tidak valid.');
    }
    final key = w.requestKey;
    final receipt = user.collection('operations').doc(w.operationId),
        core = user.collection('state').doc('core');
    final result = await db
        .runTransaction<int>((tx) async {
          check();
          final operation = await tx.get(receipt);
          if (operation.exists) {
            if (operation.data()?['kind'] != 'schedule_import' ||
                operation.data()?['result']?['requestKey'] != key) {
              throw const DraftFailure(
                'Bukti impor tidak cocok. Buka kembali tinjauan.',
              );
            }
            return (operation.data()!['result']['ids'] as List).length;
          }
          final state = await tx.get(core);
          if ((state.data()?['agendaRevision'] ?? 0) != w.baseRevision) {
            throw const ImportNeedsReview(
              'Agenda berubah. Muat ulang tinjauan sebelum menyetujui lagi.',
            );
          }
          final current = <String, Map<String, dynamic>?>{},
              reminders = <String, Map<String, dynamic>?>{};
          for (final plan in w.plans) {
            final id = plan['id'] as String;
            final target = await tx.get(user.collection('agenda').doc(id));
            if (plan['version'] == 0
                ? target.exists
                : !target.exists ||
                      target.data()?['version'] != plan['version'] ||
                      target.data()?['deletedAt'] != null) {
              throw const ImportNeedsReview(
                'Salah satu jadwal berubah. Periksa tinjauan terbaru.',
              );
            }
            current[id] = target.data();
            if (target.exists) {
              reminders[id] = (await tx.get(
                user.collection('reminders').doc(id),
              )).data();
            }
          }
          check();
          final now = FieldValue.serverTimestamp();
          for (final plan in w.plans) {
            final id = plan['id'] as String,
                old = current[id],
                input = agendaJson(
                  Map<String, dynamic>.from(plan['input'] as Map),
                );
            final version = (plan['version'] as int) + 1,
                deleted = plan['delete'] == true;
            final invalid = input.validate();
            if (invalid != null) throw DraftFailure(invalid);
            tx.set(user.collection('agenda').doc(id), {
              'schemaVersion': 1,
              'version': version,
              'createdAt': old?['createdAt'] ?? now,
              'updatedAt': now,
              'deletedAt': deleted ? now : null,
              'operationId': w.operationId,
              'kind': input.kind,
              'title': input.title.trim(),
              'description': input.description,
              'startAtUtc': input.startAtUtc == null
                  ? null
                  : Timestamp.fromDate(input.startAtUtc!),
              'endAtUtc': input.endAtUtc == null
                  ? null
                  : Timestamp.fromDate(input.endAtUtc!),
              'durationMinutes': input.durationMinutes,
              'deadlineAtUtc': input.deadlineAtUtc == null
                  ? null
                  : Timestamp.fromDate(input.deadlineAtUtc!),
              'priority': input.priority,
              'status': input.status,
              'timezone': 'Asia/Jakarta',
              'recurrence': input.recurrence ?? {'type': 'none'},
              'importSource': plan['source'],
            });
            if (reminders[id] != null) {
              tx.set(
                user.collection('reminders').doc(id),
                nextReminder(
                  reminders[id],
                  input,
                  agendaId: id,
                  sourceVersion: version,
                  deleted: deleted,
                  now: DateTime.now().toUtc(),
                ),
              );
            }
          }
          final old = state.data();
          tx.set(core, {
            'schemaVersion': 1,
            'version': (old?['version'] as int? ?? 0) + 1,
            'createdAt': old?['createdAt'] ?? now,
            'updatedAt': now,
            'agendaRevision': w.baseRevision + 1,
            'financeRevision': old?['financeRevision'] ?? 0,
            'balanceRupiah': old?['balanceRupiah'] ?? 0,
            'lifetimeIncomeRupiah': old?['lifetimeIncomeRupiah'] ?? 0,
            'lifetimeExpenseRupiah': old?['lifetimeExpenseRupiah'] ?? 0,
            'lastUndoOperationId': w.operationId,
          });
          tx.set(receipt, {
            'schemaVersion': 1,
            'version': 1,
            'createdAt': now,
            'updatedAt': now,
            'draftId': w.id,
            'approvedRevision': w.revision,
            'kind': 'schedule_import',
            'targets': w.plans.map((p) => p['id']).toList(),
            'result': {
              'ids': w.plans.map((p) => p['id']).toList(),
              'versions': w.plans
                  .map((p) => (p['version'] as int) + 1)
                  .toList(),
              'requestKey': key,
            },
            'undoState': 'unavailable',
          });
          return w.plans.length;
        })
        .timeout(const Duration(seconds: 30));
    check();
    w.applied = true;
    w.resultCount = result;
    return result;
  }
}
