import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'agenda.dart';
import 'recurrence.dart';

const reminderLeads = [5, 10, 15, 30, 60];
DateTime? reminderAnchor(AgendaInput input) =>
    input.startAtUtc ?? input.deadlineAtUtc;

// Config and dispatch share a document so agenda mutations can invalidate a lease atomically.
Map<String, dynamic> nextReminder(
  Map<String, dynamic>? old,
  AgendaInput input, {
  required String agendaId,
  required int sourceVersion,
  required bool deleted,
  required DateTime now,
  bool? enabled,
  int? leadMinutes,
}) {
  final meeting = input.recurrence == null
      ? null
      : nextWeekly(
          AgendaItem(id: agendaId, version: sourceVersion, input: input),
          now,
        );
  final anchor = input.recurrence == null
          ? reminderAnchor(input)
          : meeting?.input.startAtUtc,
      lead = leadMinutes ?? old?['leadMinutes'] as int? ?? 10;
  final on = enabled ?? old?['enabled'] as bool? ?? false;
  final eligible =
      on &&
      !deleted &&
      input.status == 'planned' &&
      anchor != null &&
      anchor.isAfter(now);
  final oldAnchor = (old?['anchorAtUtc'] as Timestamp?)?.toDate().toUtc();
  final reset =
      old == null ||
      oldAnchor != anchor ||
      old['enabled'] != on ||
      old['leadMinutes'] != lead ||
      (old['status'] == 'cancelled' && eligible) ||
      (!eligible && old['status'] != 'cancelled');
  final due = anchor?.subtract(Duration(minutes: lead));
  final stamp = FieldValue.serverTimestamp();
  return {
    ...?old,
    'schemaVersion': 1,
    'agendaId': agendaId,
    'sourceVersion': sourceVersion,
    if (input.recurrence != null || old?.containsKey('occurrenceDate') == true)
      'occurrenceDate': meeting == null ? null : occurrenceKey(meeting.id)!.$2,
    'generation': (old?['generation'] as int? ?? 0) + (reset ? 1 : 0),
    'enabled': on,
    'leadMinutes': lead,
    'anchorAtUtc': anchor == null ? null : Timestamp.fromDate(anchor),
    'dueAtUtc': due == null ? null : Timestamp.fromDate(due),
    'createdAt': old?['createdAt'] ?? stamp,
    'updatedAt': stamp,
    if (reset) ...{
      'availableAtUtc': Timestamp.fromDate(due ?? DateTime.utc(2100)),
      'status': eligible ? 'queued' : 'cancelled',
      'attempts': 0,
      'leaseId': null,
      'leaseUntilUtc': null,
      'lastError': null,
      'deviceResults': <String, dynamic>{},
    },
  };
}

class ReminderRepository {
  ReminderRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  DocumentReference<Map<String, dynamic>> get user =>
      db.collection('users').doc(uid);
  void check() {
    if (auth.currentUser?.uid != uid) {
      throw const AgendaFailure('Sesi berubah. Buka kembali pengingat.');
    }
  }

  Future<Map<String, dynamic>?> read(String id) async {
    check();
    final d = await user
        .collection('reminders')
        .doc(occurrenceKey(id)?.$1 ?? id)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    check();
    return d.data();
  }

  Future<void> configure(AgendaItem item, bool enabled, int lead) async {
    check();
    if (!reminderLeads.contains(lead)) {
      throw const AgendaFailure('Pilihan pengingat tidak valid.');
    }
    final sourceId = occurrenceKey(item.id)?.$1 ?? item.id;
    await db.runTransaction(
      (tx) async {
        check();
        final source = await tx.get(user.collection('agenda').doc(sourceId));
        final job = await tx.get(user.collection('reminders').doc(sourceId));
        final data = source.data();
        if (data == null ||
            data['deletedAt'] != null ||
            data['version'] != item.version) {
          throw const AgendaFailure(
            'Agenda sudah berubah. Buka ulang sebelum mengatur pengingat.',
          );
        }
        if (job.exists &&
            job.data()?['enabled'] == enabled &&
            job.data()?['leadMinutes'] == lead &&
            job.data()?['sourceVersion'] == item.version) {
          return;
        }
        final input = AgendaInput(
          title: data['title'] as String,
          kind: data['kind'] as String,
          durationMinutes: data['durationMinutes'] as int,
          startAtUtc: (data['startAtUtc'] as Timestamp?)?.toDate().toUtc(),
          deadlineAtUtc: (data['deadlineAtUtc'] as Timestamp?)
              ?.toDate()
              .toUtc(),
          status: data['status'] as String,
          recurrence: data['recurrence']?['type'] == 'weekly'
              ? Map<String, dynamic>.from(data['recurrence'])
              : null,
        );
        final anchor = input.recurrence == null
            ? reminderAnchor(input)
            : nextWeekly(
                AgendaItem(id: sourceId, version: item.version, input: input),
                DateTime.now().toUtc(),
              )?.input.startAtUtc;
        if (enabled &&
            (item.input.status != 'planned' ||
                anchor == null ||
                !anchor.isAfter(DateTime.now().toUtc()))) {
          throw const AgendaFailure(
            'Atur waktu mulai atau deadline yang masih akan datang.',
          );
        }
        tx.set(
          job.reference,
          nextReminder(
            job.data(),
            input,
            agendaId: sourceId,
            sourceVersion: item.version,
            deleted: false,
            now: DateTime.now().toUtc(),
            enabled: enabled,
            leadMinutes: lead,
          ),
        );
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    check();
  }
}
