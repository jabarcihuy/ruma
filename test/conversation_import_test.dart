import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_snapshot.dart';
import 'package:ruma/data/conversation.dart';
import 'package:ruma/data/google_calendar_service.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/schedule_import.dart';

import 'assistant_test.dart' as f;

class ConversationService extends f.ServiceFake {
  final responses = <Map<String, dynamic>>[];
  final requests = <List<Map<String, String>>>[];
  final proposals = <List<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>> propose(
    String message,
    String id, {
    List<Map<String, String>>? messages,
    List<Map<String, dynamic>> activeProposal = const [],
    String? conversationId,
  }) async {
    calls++;
    requests.add(messages ?? []);
    proposals.add(activeProposal);
    return responses.removeAt(0);
  }
}

Map<String, dynamic> study(String time) => {
  ...f.proposal(),
  'title': 'Belajar',
  'sourceQuote': 'Besok belajar satu jam',
  'durationMinutes': 60,
  'startLocal': '2026-11-03T$time',
  'localDate': '2026-11-03',
};

void main() {
  test('follow-up completes and revises one proposal; ordinary chat does not discard it or save data', () async {
    final service = ConversationService()
      ..responses.addAll([
        {
          'type': 'clarification',
          'reason': 'conversation',
          'content': 'Jam berapa?',
          'items': [],
        },
        {
          'type': 'draft_proposal',
          'content': 'Periksa usulan.',
          'items': [study('10:00')],
        },
        {
          'type': 'draft_proposal',
          'content': 'Periksa usulan.',
          'items': [study('11:00')],
        },
        {'type': 'answer', 'content': 'Sama-sama!'},
      ]);
    final repo = f.DraftRepoFake(),
        store = f.makeStore(repo, service)..consent = true;
    await store.send('Besok belajar satu jam');
    await store.send('Jam 10 aja');
    expect(store.draft!.items.single.agenda!.durationMinutes, 60);
    expect(agendaLocal(store.draft!.items.single.agenda!.startAtUtc!).hour, 10);
    final id = store.draft!.id, key = store.draft!.requestKey;
    await store.send('Ganti jadi jam 11');
    expect(store.draft!.id, id);
    expect(store.draft!.requestKey, isNot(key));
    expect(agendaLocal(store.draft!.items.single.agenda!.startAtUtc!).hour, 11);
    final current = store.draft;
    await store.send('Terima kasih');
    expect(store.draft, same(current));
    expect(repo.saves, 0);
    expect(
      service.requests[1].map((m) => m['content']),
      containsAllInOrder([
        'Besok belajar satu jam',
        'Jam berapa?',
        'Jam 10 aja',
      ]),
    );
    expect(service.proposals[2].single['title'], 'Belajar');
    await store.save();
    await store.save();
    expect(repo.saves, 1);
    store.dispose();
    store.agenda.dispose();
    store.finance.dispose();
  });
  test('model context is bounded and excludes computed ledger replies and legacy replies', () {
    final history = [
      {
        'message': 'Berapa saldo?',
        'reply': 'PRIVATE_LEDGER_123',
        'kind': 'read_request',
      },
      {'message': 'Pesan lama', 'reply': 'PRIVATE_OLD_REPLY'},
      {
        'message': 'Besok belajar',
        'reply': 'Jam berapa?',
        'kind': 'clarification',
      },
    ];
    final rows = conversationMessages(history, 'Jam 10');
    expect(jsonEncode(rows), isNot(contains('PRIVATE_')));
    expect(jsonEncode(rows), contains('Jam berapa?'));
    final long = conversationMessages(
      List.generate(
        20,
        (i) => {'message': 'x' * 3000, 'reply': 'y' * 3000, 'kind': 'answer'},
      ),
      'baru',
    );
    expect(
      long.fold<int>(0, (n, m) => n + m['content']!.length),
      lessThanOrEqualTo(12000),
    );
    expect(long.length, lessThanOrEqualTo(17));
    expect(long.last['content'], 'baru');
  });
  test('schema one migrates without replay; schema two preserves conversation and import operation identity', () {
    final old =
        jsonDecode(AssistantSnapshot().encode('owner')) as Map<String, dynamic>;
    old['schemaVersion'] = 1;
    old.remove('conversationId');
    old.remove('replyKind');
    old.remove('scheduleWorkspace');
    expect(
      AssistantSnapshot.decode(jsonEncode(old), 'owner').conversationId,
      '',
    );
    final workspace = ScheduleWorkspace(
      id: 'import',
      from: '2026-10-27',
      to: '2027-03-01',
      rows: [],
      periodConfirmed: true,
      operationId: 'same-operation',
      attempted: true,
      plans: [
        {
          'id': 'target',
          'version': 0,
          'input': {'title': 'Belajar'},
        },
      ],
    );
    final next = AssistantSnapshot.decode(
      AssistantSnapshot(
        conversationId: 'thread',
        replyKind: 'answer',
        scheduleWorkspace: workspace.toJson(),
      ).encode('owner'),
      'owner',
    );
    final restored = ScheduleWorkspace.fromJson(next.scheduleWorkspace!);
    expect(next.conversationId, 'thread');
    expect(restored.requestKey, workspace.requestKey);
    expect(() => restored.changed(), throwsA(isA<DraftFailure>()));
  });
  test('semester pattern starts on correct weekday and expands beyond ninety days without extra meetings', () {
    final row = ScheduleRow(
      id: 'class',
      title: 'Algoritma',
      weekday: 1,
      start: '08:00',
      end: '09:40',
    );
    expect(row.validate('2026-10-27', '2027-03-01'), isNull);
    final input = row.build('2026-10-27', '2027-03-01');
    expect(input.recurrence!['originDate'], '2026-11-02');
    final instances = scheduleOccurrences(
      input,
      'series',
      '2026-10-27',
      '2027-03-01',
    );
    expect(instances.first.input.startAtUtc, DateTime.utc(2026, 11, 2, 1));
    expect(instances.last.input.startAtUtc, DateTime.utc(2027, 3, 1, 1));
    expect(instances.length, 18);
    expect(instances.map((e) => e.id).toSet().length, 18);
    expect(
      ScheduleRow(
        id: 'bad',
        title: 'X',
        weekday: 2,
        start: '11:00',
        end: '10:00',
      ).validate('2026-10-27', '2027-03-01'),
      isNotNull,
    );
  });
  test('Google weekly series retains a cancelled and moved occurrence; all-day remains unresolved', () {
    Map<String, dynamic> time(String v) => {'dateTime': v};
    final master = {
      'id': 'master',
      'etag': 'm1',
      'summary': 'Basis Data',
      'location': 'Lab 2',
      'start': time('2026-10-27T10:00:00+07:00'),
      'end': time('2026-10-27T11:40:00+07:00'),
      'recurrence': ['RRULE:FREQ=WEEKLY;COUNT=3'],
    };
    final events = <Map<String, dynamic>>[
      {
        'id': 'first',
        'etag': '1',
        'recurringEventId': 'master',
        'originalStartTime': time('2026-10-27T10:00:00+07:00'),
        'start': time('2026-10-27T10:00:00+07:00'),
        'end': time('2026-10-27T11:40:00+07:00'),
      },
      {
        'id': 'cancelled',
        'etag': '2',
        'recurringEventId': 'master',
        'status': 'cancelled',
        'originalStartTime': time('2026-11-03T10:00:00+07:00'),
      },
      {
        'id': 'moved',
        'etag': '3',
        'recurringEventId': 'master',
        'originalStartTime': time('2026-11-10T10:00:00+07:00'),
        'start': time('2026-11-11T11:00:00+07:00'),
        'end': time('2026-11-11T12:40:00+07:00'),
      },
      {
        'id': 'holiday',
        'summary': 'Libur',
        'start': {'date': '2026-11-12'},
        'end': {'date': '2026-11-13'},
      },
    ];
    final rows = calendarRows(
      events,
      {'master': master},
      calendar: 'college',
      account: 'test@example.invalid',
      from: '2026-10-27',
      to: '2026-11-20',
    );
    final weekly = rows.singleWhere((r) => r.weekly);
    expect(weekly.validate('2026-10-27', '2026-11-20'), isNull);
    final occurrences = scheduleOccurrences(
      weekly.build('2026-10-27', '2026-11-20'),
      'series',
      '2026-10-27',
      '2026-11-20',
    );
    expect(
      occurrences.singleWhere((e) => e.id.endsWith('2026-11-03')).input.status,
      'cancelled',
    );
    expect(
      agendaLocal(
        occurrences
            .singleWhere((e) => e.id.endsWith('2026-11-10'))
            .input
            .startAtUtc!,
      ),
      DateTime.utc(2026, 11, 11, 11),
    );
    final holiday = rows.singleWhere((r) => r.title == 'Libur');
    expect(holiday.included, false);
    expect(holiday.start, '');
    expect(holiday.issue, isNotEmpty);
  });
  test('Calendar API paginates, requests readonly data, converts offsets, and keeps credentials out of import rows', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    final sub = server.listen((request) async {
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer synthetic-token',
      );
      paths.add(request.uri.path);
      final isCalendars = request.uri.path.endsWith('/calendarList');
      final next = request.uri.queryParameters['pageToken'] == 'next';
      final body = isCalendars
          ? {
              'items': [
                {
                  'id': next ? 'secondary' : 'primary',
                  'summary': next ? 'Kuliah' : 'Pribadi',
                  'timeZone': 'Asia/Jakarta',
                  'accessRole': 'reader',
                },
              ],
              if (!next) 'nextPageToken': 'next',
            }
          : {
              'items': [
                {
                  'id': 'one',
                  'summary': 'Kuliah',
                  'etag': 'v1',
                  'start': {'dateTime': '2026-11-02T01:00:00Z'},
                  'end': {'dateTime': '2026-11-02T02:00:00Z'},
                },
              ],
            };
      if (!isCalendars) {
        expect(request.uri.queryParameters['singleEvents'], 'true');
        expect(
          request.uri.queryParameters['timeMax'],
          '2026-11-03T17:00:00.000Z',
        );
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    final service = GoogleCalendarService(
      baseUrl: 'http://127.0.0.1:${server.port}',
      authorizer: () async => {
        'account': 'test@example.invalid',
        'accessToken': 'synthetic-token',
      },
    );
    await service.authorize();
    expect((await service.calendars()).length, 2);
    final rows = await service.schedules('college', '2026-11-01', '2026-11-03');
    expect(rows.single.start, '08:00');
    expect(rows.single.end, '09:00');
    expect(paths.length, 3);
    expect(
      jsonEncode(rows.single.toJson()),
      isNot(contains('synthetic-token')),
    );
    service.close();
    await sub.cancel();
    await server.close(force: true);
  });
  test(
    'an unreadable missing Google event never implies source cancellation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final listener = server.listen((request) async {
        if (request.uri.path.endsWith('/events')) {
          request.response.write(jsonEncode({'items': []}));
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });
      final service = GoogleCalendarService(
        baseUrl: 'http://127.0.0.1:${server.port}',
        authorizer: () async => {
          'account': 'fixture@example.invalid',
          'accessToken': 'synthetic',
        },
      );
      try {
        await service.authorize();
        final rows = await service.schedules(
          'college',
          '2026-10-27',
          '2026-11-20',
          previousSources: [
            {
              'key': 'google:missing',
              'remote': {'eventId': 'missing', 'series': false},
            },
          ],
        );
        expect(rows, isEmpty);
      } finally {
        service.close();
        await listener.cancel();
        await server.close(force: true);
      }
    },
  );
}
