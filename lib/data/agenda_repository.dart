import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'agenda.dart';
import 'finance.dart' show dateKey;
import 'recurrence.dart';

import 'dart:convert';

import 'reminders.dart';
import 'push_notifications.dart';

class AgendaRepository {
  AgendaRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  DocumentReference<Map<String, dynamic>> get _user =>
      db.collection('users').doc(uid);
  void _checkSession() {
    if (auth.currentUser?.uid != uid) {
      throw const AgendaFailure(
        'Sesi akun berubah. Buka kembali agenda dari akunmu.',
      );
    }
  }

  String newId() => _user.collection('agenda').doc().id;

  Future<AgendaSnapshot> read() async {
    _checkSession();
    const server = GetOptions(source: Source.server);
    final core = _user.collection('state').doc('core');
    final before = await core.get(server).timeout(const Duration(seconds: 15));
    // ponytail: bounded full scan for this coursework slice; move to range queries
    // and recurring-series expansion before supporting more than 500 active items.
    final docs = await _user
        .collection('agenda')
        .where('deletedAt', isNull: true)
        .limit(501)
        .get(server)
        .timeout(const Duration(seconds: 15));
    final after = await core.get(server).timeout(const Duration(seconds: 15));
    _checkSession();
    final revision = (after.data()?['agendaRevision'] as int?) ?? 0;
    if (revision != ((before.data()?['agendaRevision'] as int?) ?? 0)) {
      throw const AgendaFailure(
        'Agenda baru berubah. Muat ulang sebelum melanjutkan.',
      );
    }
    if (docs.docs.length > 500) {
      throw const AgendaFailure(
        'Agenda aktif melebihi batas tahap ini. Tidak ada data yang dipotong atau disimpan.',
      );
    }
    final items = docs.docs.map((doc) {
      final d = doc.data();
      if (!['none', 'weekly'].contains(d['recurrence']?['type']) ||
          d['timezone'] != 'Asia/Jakarta') {
        throw const AgendaFailure(
          'Agenda ini memerlukan dukungan pengulangan atau zona waktu lain.',
        );
      }
      return AgendaItem(
        id: doc.id,
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
              ? Map<String, dynamic>.from(d['recurrence'])
              : null,
        ),
      );
    }).toList();
    final series = items.where((a) => a.input.recurrence != null).toList();
    if (series.length > 30) {
      throw const AgendaFailure('Batas tahap ini 30 seri aktif.');
    }
    final singles = items.where((a) => a.input.recurrence == null).toList();
    final now = DateTime.now().toUtc();
    final window = expandWeekly(
      series,
      now.subtract(const Duration(days: 7)),
      now.add(const Duration(days: 15)),
    );
    final expanded = {for (final a in window) a.id: a};
    for (final s in series) {
      final next = nextWeekly(s, now);
      if (next != null) expanded[next.id] = next;
    }
    return AgendaSnapshot(
      [...singles, ...expanded.values],
      revision,
      series: series,
      singles: singles,
    );
  }

  Future<AgendaSnapshot> save(AgendaMutation mutation) async {
    _checkSession();
    final originalRequestKey = mutation.requestKey;
    final occurrence = occurrenceKey(mutation.id);
    if (occurrence != null) {
      final receipt = await _user
          .collection('operations')
          .doc(mutation.operationId)
          .get(const GetOptions(source: Source.server));
      _checkSession();
      if (receipt.exists) {
        if (receipt.data()?['result']?['requestKey'] != originalRequestKey) {
          throw const AgendaFailure('Identitas operasi berbeda.');
        }
        return read();
      }
    }
    if (mutation.restore &&
        (mutation.delete || mutation.originalVersion == null)) {
      throw const AgendaFailure('Permintaan pemulihan tidak valid.');
    }
    final invalid = mutation.input.validate();
    if (invalid != null) throw AgendaFailure(invalid);
    final snapshot = await read();
    if (occurrence != null) {
      final raw = snapshot.series
          .where((a) => a.id == occurrence.$1)
          .firstOrNull;
      if (raw == null ||
          raw.version != mutation.originalVersion ||
          weeklyMeeting(raw, occurrence.$2) == null) {
        throw const AgendaFailure('Seri berubah. Buka ulang pertemuan.');
      }
      final r = Map<String, dynamic>.from(raw.input.recurrence!);
      if (mutation.scope == 'future' && mutation.delete) {
        r['untilLocalDate'] = dateKey(
          DateTime.parse('${occurrence.$2}T00:00:00Z')
              .subtract(const Duration(days: 1)),
        );
        // Cancelling from the very first meeting is equivalent to deleting the series.
        if ((r['untilLocalDate'] as String).compareTo(
              r['originDate'] as String,
            ) <
            0) {
          mutation = AgendaMutation(
            operationId: mutation.operationId,
            id: raw.id,
            input: raw.input,
            originalVersion: raw.version,
            delete: true,
          );
        } else {
          mutation = AgendaMutation(
            operationId: mutation.operationId,
            id: raw.id,
            input: agendaCopy(raw.input, recurrence: r),
            originalVersion: raw.version,
          );
        }
      } else {
        final field = mutation.scope == 'future' ? 'changes' : 'exceptions',
            map = Map<String, dynamic>.from(jsonDecode(r[field] as String));
        map[occurrence.$2] = agendaCopy(
          mutation.input,
          status: mutation.delete ? 'cancelled' : mutation.input.status,
        ).toJson();
        r[field] = jsonEncode(map);
        mutation = AgendaMutation(
          operationId: mutation.operationId,
          id: raw.id,
          input: agendaCopy(raw.input, recurrence: r),
          originalVersion: raw.version,
        );
      }
      final bad = mutation.input.validate();
      if (bad != null) throw AgendaFailure(bad);
    }
    if (!mutation.delete) {
      if (mutation.input.recurrence != null) {
        if (snapshot.series.where((a) => a.id != mutation.id).length >= 30) {
          throw const AgendaFailure('Batas tahap ini 30 seri aktif.');
        }
        final patterns = [
          ...snapshot.series.where((a) => a.id != mutation.id),
          AgendaItem(id: mutation.id, version: 1, input: mutation.input),
        ];
        final checkpoints = <DateTime>{
          mutation.input.startAtUtc!,
          DateTime.now().toUtc(),
        };
        for (final a in patterns) {
          checkpoints.add(a.input.startAtUtc!);
          final r = a.input.recurrence!;
          for (final f in ['exceptions', 'changes']) {
            for (final v in (jsonDecode(r[f] as String) as Map).values) {
              checkpoints.add(
                agendaJson(Map<String, dynamic>.from(v)).startAtUtc!,
              );
            }
          }
        }
        for (final a in snapshot.singles ?? snapshot.items) {
          if (a.input.startAtUtc != null) checkpoints.add(a.input.startAtUtc!);
        }
        for (final d in checkpoints) {
          final entries = [
            ...(snapshot.singles ?? snapshot.items).where(
              (a) =>
                  a.input.recurrence == null &&
                  !a.id.contains('__') &&
                  a.id != mutation.id,
            ),
            ...expandWeekly(
              patterns,
              d.subtract(const Duration(days: 1)),
              d.add(const Duration(days: 8)),
            ),
          ];
          final mine = entries
              .where((a) => occurrenceKey(a.id)?.$1 == mutation.id)
              .toList();
          for (final a in mine) {
            for (final b in entries) {
              if (a.id != b.id && a.input.overlaps(b.input)) {
                throw AgendaFailure(
                  'Pengulangan berbenturan dengan “${b.input.title}”. Pilih waktu lain.',
                );
              }
            }
          }
        }
      }
      final candidates = mutation.input.startAtUtc == null
          ? snapshot.items
          : snapshot.between(
              mutation.input.startAtUtc!.subtract(const Duration(days: 1)),
              mutation.input.endAtUtc!.add(const Duration(days: 1)),
            );
      final conflicts = candidates.where(
        (a) =>
            mutation.input.recurrence == null &&
            a.id != mutation.id &&
            occurrenceKey(a.id)?.$1 != mutation.id &&
            a.input.overlaps(mutation.input),
      );
      if (conflicts.isNotEmpty) {
        throw AgendaFailure(
          'Jam ini berbenturan dengan “${conflicts.first.input.title}”. Pilih waktu lain; isianmu tetap ada.',
        );
      }
    }
    final target = _user.collection('agenda').doc(mutation.id);
    final coreRef = _user.collection('state').doc('core');
    final opRef = _user.collection('operations').doc(mutation.operationId);
    final version = await db.runTransaction<int?>(
      (tx) async {
        _checkSession();
        final operation = await tx.get(opRef);
        if (operation.exists) {
          if (operation.data()?['result']?['requestKey'] !=
              originalRequestKey) {
            throw const AgendaFailure(
              'Permintaan sebelumnya sudah diproses. Muat ulang agenda sebelum menyimpan perubahan lain.',
            );
          }
          return null;
        }
        final core = await tx.get(coreRef);
        final current = await tx.get(target);
        final reminderRef = _user.collection('reminders').doc(mutation.id);
        final reminder = await tx.get(reminderRef);
        final c = core.data();
        if (((c?['agendaRevision'] as int?) ?? 0) != snapshot.revision) {
          throw const AgendaFailure(
            'Agenda berubah di perangkat lain. Coba lagi untuk memeriksa waktu terbaru.',
          );
        }
        if (mutation.originalVersion == null
            ? current.exists
            : (!current.exists ||
                  current.data()?['version'] != mutation.originalVersion ||
                  ((current.data()?['deletedAt'] != null) !=
                      mutation.restore))) {
          throw const AgendaFailure(
            'Kegiatan sudah berubah atau dihapus. Buka ulang detailnya; perubahan baru belum disimpan.',
          );
        }
        final nextVersion = (mutation.originalVersion ?? 0) + 1;
        final now = FieldValue.serverTimestamp();
        final input = mutation.input;
        tx.set(
          target,
          mutation.delete
              ? {
                  ...current.data()!,
                  'version': nextVersion,
                  'operationId': mutation.operationId,
                  'updatedAt': now,
                  'deletedAt': now,
                }
              : {
                  'schemaVersion': 1,
                  'version': nextVersion,
                  'createdAt': current.data()?['createdAt'] ?? now,
                  'updatedAt': now,
                  'deletedAt': null,
                  'operationId': mutation.operationId,
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
                  if (current.data()?['importSource'] != null)
                    'importSource': current.data()!['importSource'],
                },
        );
        if (reminder.exists) {
          tx.set(
            reminderRef,
            nextReminder(
              reminder.data(),
              input,
              agendaId: mutation.id,
              sourceVersion: nextVersion,
              deleted: mutation.delete,
              now: DateTime.now().toUtc(),
            ),
          );
        }
        tx.set(coreRef, {
          ...?c,
          'schemaVersion': 1,
          'version': ((c?['version'] as int?) ?? 0) + 1,
          'createdAt': c?['createdAt'] ?? now,
          'updatedAt': now,
          'agendaRevision': snapshot.revision + 1,
          'financeRevision': c?['financeRevision'] ?? 0,
          'balanceRupiah': c?['balanceRupiah'] ?? 0,
          'lifetimeIncomeRupiah': c?['lifetimeIncomeRupiah'] ?? 0,
          'lifetimeExpenseRupiah': c?['lifetimeExpenseRupiah'] ?? 0,
          'lastUndoOperationId': mutation.operationId,
        });
        tx.set(opRef, {
          'schemaVersion': 1,
          'version': 1,
          'createdAt': now,
          'updatedAt': now,
          'draftId': 'manual',
          'approvedRevision': 1,
          'kind': mutation.kind,
          'targets': ['agenda/${mutation.id}'],
          'result': {
            'agendaId': mutation.id,
            'version': nextVersion,
            'requestKey': originalRequestKey,
          },
          'undoState': 'unavailable',
        });
        return nextVersion;
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    _checkSession();
    if (version == null ||
        mutation.input.recurrence != null ||
        occurrence != null) {
      return read();
    }
    return AgendaSnapshot([
      ...snapshot.items.where((a) => a.id != mutation.id),
      if (!mutation.delete)
        AgendaItem(id: mutation.id, version: version, input: mutation.input),
    ], snapshot.revision + 1);
  }
}

class AgendaStore extends ChangeNotifier {
  AgendaStore(this.repository);
  final AgendaRepository repository;
  int defaultDurationMinutes = 60;
  RumaNotifications? notifications;
  List<AgendaItem> items = [];
  List<AgendaItem> series = [], singles = [];
  List<AgendaItem> forDay(DateTime day) =>
      AgendaSnapshot(
        items,
        0,
        series: series,
        singles: singles.isEmpty && series.isEmpty ? items : singles,
      ).between(
        agendaUtc(day, 0, 0),
        agendaUtc(day.add(const Duration(days: 1)), 0, 0),
      );
  AgendaItem? meeting(String id) {
    final key = occurrenceKey(id);
    if (key == null) return items.where((a) => a.id == id).firstOrNull;
    final raw = series.where((a) => a.id == key.$1).firstOrNull;
    return raw == null ? null : weeklyMeeting(raw, key.$2);
  }

  bool loading = false, saving = false, loaded = false, _disposed = false;
  String? error;
  int _generation = 0;
  Future<void> load() async {
    if (_disposed || loading || saving) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.read();
      if (_disposed || generation != _generation) return;
      items = result.items;
      series = result.series;
      singles = result.singles ?? result.items;
      loaded = true;
      if (notifications != null) unawaited(notifications!.reconcileSnoozes());
    } catch (e) {
      if (!_disposed && generation == _generation) error = agendaError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(AgendaMutation mutation) async {
    if (_disposed || saving) return false;
    final generation = ++_generation;
    saving = true;
    loading = false;
    error = null;
    notifyListeners();
    try {
      final result = await repository.save(mutation);
      if (_disposed || generation != _generation) return false;
      items = result.items;
      series = result.series;
      singles = result.singles ?? result.items;
      loaded = true;
      if (notifications != null) unawaited(notifications!.reconcileSnoozes());
      return true;
    } catch (e) {
      if (!_disposed && generation == _generation) error = agendaError(e);
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    items = [];
    super.dispose();
  }
}

String agendaError(Object error) {
  if (error is AgendaFailure) return error.message;
  if (error is TimeoutException) {
    return 'Penyimpanan belum terkonfirmasi. Periksa internet lalu coba lagi; isianmu tetap ada.';
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return 'Akses agenda belum diizinkan. Data belum diubah; coba muat ulang atau masuk kembali.';
  }
  if (error is FirebaseException &&
      ['unavailable', 'deadline-exceeded', 'cancelled'].contains(error.code)) {
    return 'Belum terhubung ke server. Isianmu tetap ada; coba lagi saat online.';
  }
  return 'Agenda belum dapat diproses. Coba muat ulang; isianmu tetap ada.';
}
