import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/data/push_notifications.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 1),
      start = DateTime.utc(2026, 10, 21, 2);
  test('reminder anchor and due; edit/delete invalidate generation while title edits preserve dispatch', () {
    final a = AgendaInput(title: 'A', startAtUtc: start);
    final first = nextReminder(
      null,
      a,
      agendaId: 'a',
      sourceVersion: 1,
      deleted: false,
      now: now,
      enabled: true,
    );
    expect(first['status'], 'queued');
    expect(
      (first['dueAtUtc'] as Timestamp).toDate().toUtc(),
      start.subtract(const Duration(minutes: 10)),
    );
    final sent = {
      ...first,
      'status': 'sent',
      'deviceResults': {'device': 'sent'},
    };
    final title = nextReminder(
      sent,
      AgendaInput(title: 'B', startAtUtc: start),
      agendaId: 'a',
      sourceVersion: 2,
      deleted: false,
      now: now,
    );
    expect(title['generation'], 1);
    expect(title['status'], 'sent');
    expect(title['sourceVersion'], 2);
    final moved = nextReminder(
      sent,
      AgendaInput(title: 'A', startAtUtc: start.add(const Duration(hours: 1))),
      agendaId: 'a',
      sourceVersion: 2,
      deleted: false,
      now: now,
    );
    expect(moved['generation'], 2);
    expect(moved['status'], 'queued');
    expect(moved['deviceResults'], isEmpty);
    final deleted = nextReminder(
      first,
      a,
      agendaId: 'a',
      sourceVersion: 2,
      deleted: true,
      now: now,
    );
    expect(deleted['status'], 'cancelled');
    expect(deleted['enabled'], true);
    final restored = nextReminder(
      deleted,
      a,
      agendaId: 'a',
      sourceVersion: 3,
      deleted: false,
      now: now,
    );
    expect(restored['status'], 'queued');
    expect(restored['generation'], 3);
    final deadline = nextReminder(
      null,
      AgendaInput(title: 'Tugas', deadlineAtUtc: start),
      agendaId: 'b',
      sourceVersion: 1,
      deleted: false,
      now: now,
      enabled: true,
    );
    expect(deadline['anchorAtUtc'], Timestamp.fromDate(start));
  });
  test('invalid notification payload cannot route across arbitrary paths; id is stable', () {
    final good = {
      'uid': 'u',
      'agendaId': 'a',
      'generation': '2',
      'sourceVersion': '3',
      'notificationId': 'a_2',
    };
    expect(NotificationTarget.parse(good)?.id, 'a_2');
    for (final bad in [
      {...good, 'agendaId': '../other'},
      {...good, 'generation': '-1'},
        {...good, 'generation':'1000000001','notificationId':'a_1000000001'},
      {...good, 'notificationId': 'forged'},
      {...good, 'uid': null},
    ]) {
      expect(NotificationTarget.parse(bad), isNull);
    }
    expect(notificationNumber('a_2'), notificationNumber('a_2'));
    expect(notificationNumber('a_2'), isNot(notificationNumber('a_3')));
  });
}
