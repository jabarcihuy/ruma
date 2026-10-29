import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'agenda.dart';
import 'assistant_draft.dart';
import 'finance.dart' show dateKey;
import 'schedule_import.dart';

class CalendarChoice {
  const CalendarChoice(this.id, this.title, this.timezone, this.readable);
  final String id, title, timezone;
  final bool readable;
}

class GoogleCalendarService {
  GoogleCalendarService({
    HttpClient? client,
    this.authorizer,
    this.checkSession,
    this.baseUrl = 'https://www.googleapis.com/calendar/v3',
  }) : _client = client ?? HttpClient();
  final HttpClient _client;
  final String baseUrl;
  final Future<Map<String, dynamic>> Function()? authorizer;
  final void Function()? checkSession;
  static const _channel = MethodChannel('id.ruma.app/calendar');
  String _token = '', account = '';
  bool _closed = false;
  void check() {
    if (_closed) throw const DraftFailure('Sesi kalender sudah ditutup.');
    checkSession?.call();
  }

  Future<void> authorize() async {
    check();
    try {
      final result = authorizer == null
          ? Map<String, dynamic>.from(
              (await _channel
                      .invokeMapMethod<String, dynamic>('authorize')
                      .timeout(const Duration(seconds: 90))) ??
                  {},
            )
          : await authorizer!();
      check();
      if (result['accessToken'] is! String ||
          (result['accessToken'] as String).isEmpty ||
          result['account'] is! String) {
        throw const DraftFailure('Kalender belum memberikan akses baca.');
      }
      _token = result['accessToken'] as String;
      account = result['account'] as String;
    } on PlatformException catch (e) {
      throw DraftFailure(
        e.code == 'cancelled' ? 'Pemilihan kalender dibatalkan.' : 'Google Calendar belum dapat dihubungkan. Coba lagi atau gunakan gambar jadwal.',
      );
    }
  }

  String calendarKey(String id) => scheduleHash([account.toLowerCase(), id]);

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params, {
    bool allowMissing = false,
  }) async {
    check();
    if (_token.isEmpty) {
      throw const DraftFailure('Hubungkan Google Calendar terlebih dahulu.');
    }
    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: params);
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      if (bytes.length + chunk.length > 2000000) {
        throw const DraftFailure(
          'Jawaban kalender terlalu besar. Pilih periode lebih pendek.',
        );
      }
      bytes.addAll(chunk);
    }
    check();
    if (allowMissing && response.statusCode == 404) {
      // A 404 can also hide a resource the account cannot read.
      // Only an explicit cancelled event can propose deletion.
      return {'status': 'unavailable'};
    }
    if (response.statusCode == 401) {
      _token = '';
      throw const DraftFailure(
        'Akses Google berakhir. Hubungkan kembali untuk memeriksa pembaruan.',
      );
    }
    if (response.statusCode != 200) {
      throw const DraftFailure(
        'Kalender belum dapat dibaca. Periksa izin akun dan koneksi; agenda Ruma tetap tersimpan.',
      );
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) {
      throw const DraftFailure('Format kalender tidak dapat dibaca.');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> _pages(
    String path,
    Map<String, String> params,
    int limit,
  ) async {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? page;
    do {
      final data = await _get(path, {...params, 'pageToken': ?page});
      final items = data['items'];
      if (items != null && items is! List) {
        throw const DraftFailure('Daftar kalender belum valid.');
      }
      result.addAll(
        (items as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (result.length > limit) {
        throw const DraftFailure(
          'Jadwal terlalu banyak untuk satu tinjauan. Pilih periode lebih pendek.',
        );
      }
      page = data['nextPageToken'] as String?;
      if (page != null && (!seen.add(page) || seen.length > 20)) {
        throw const DraftFailure(
          'Halaman kalender tidak dapat diselesaikan. Coba periode lebih pendek.',
        );
      }
    } while (page != null);
    return result;
  }

  Future<List<CalendarChoice>> calendars() async =>
      (await _pages('users/me/calendarList', {
            'maxResults': '250',
            'fields': 'nextPageToken,items(id,summary,timeZone,accessRole)',
          }, 500))
          .map(
            (e) => CalendarChoice(
              e['id'] as String,
              e['summary'] as String? ?? 'Kalender',
              e['timeZone'] as String? ?? '',
              [
                'owner',
                'writer',
                'reader',
                'writerWithoutPrivateAccess',
              ].contains(e['accessRole']),
            ),
          )
          .toList();

  Future<List<ScheduleRow>> schedules(
    String calendar,
    String from,
    String to, {
    List<Map<String, dynamic>> previousSources = const [],
  }) async {
    final low = agendaUtc(DateTime.parse('${from}T00:00:00Z'), 0, 0);
    final high = agendaUtc(
      DateTime.parse('${to}T00:00:00Z').add(const Duration(days: 1)),
      0,
      0,
    );
    if (!low.isBefore(high) || high.difference(low).inDays > 367) {
      throw const DraftFailure(
        'Pilih periode kalender paling banyak satu tahun.',
      );
    }
    final prefix = 'calendars/${Uri.encodeComponent(calendar)}/events';
    final events = await _pages(prefix, {
      'timeMin': low.toIso8601String(),
      'timeMax': high.toIso8601String(),
      'singleEvents': 'true',
      'showDeleted': 'true',
      'timeZone': 'Asia/Jakarta',
      'maxResults': '250',
      'fields': 'nextPageToken,items(id,etag,status,summary,location,start,end,recurringEventId,originalStartTime)',
    }, 500);
    final masters = <String, Map<String, dynamic>>{};
    final ids = {
      ...events
          .where((e) => e['recurringEventId'] is String)
          .map((e) => e['recurringEventId'] as String),
      ...previousSources
          .map((e) => e['remote'])
          .whereType<Map>()
          .where((m) => m['series'] == true)
          .map((m) => m['eventId'] as String),
    };
    if (ids.length > 40) {
      throw const DraftFailure(
        'Kalender memuat terlalu banyak seri. Pilih periode lebih pendek.',
      );
    }
    for (final id in ids) {
      masters[id] = await _get('$prefix/${Uri.encodeComponent(id)}', {
        'fields': 'id,etag,status,summary,location,start,end,recurrence',
      }, allowMissing: true);
    }
    final rows = calendarRows(
      events,
      masters,
      calendar: calendar,
      account: account,
      from: from,
      to: to,
    );
    final keys = rows.map((r) => r.sourceKey).toSet();
    for (final old in previousSources) {
      final remote = Map<String, dynamic>.from(old['remote'] as Map? ?? {});
      final key = old['key'] as String;
      if (keys.contains(key) || remote['eventId'] is! String) continue;
      final id = remote['eventId'] as String;
      final current =
          masters[id] ??
          await _get('$prefix/${Uri.encodeComponent(id)}', {
            'fields': 'id,etag,status,summary,location,start,end,recurrence,originalStartTime,recurringEventId',
          }, allowMissing: true);
      if (current['status'] == 'cancelled') {
        rows.add(
          ScheduleRow(
            id: key,
            title: current['summary'] as String? ?? 'Jadwal sumber dibatalkan',
            provider: 'google',
            sourceKey: key,
            calendarKey: calendarKey(calendar),
            sourceVersion: current['etag'] as String? ?? 'cancelled',
            remote: remote,
            cancelled: true,
          ),
        );
      }
      // A live event outside the selected interval is not inferred to be deleted.
    }
    return rows;
  }

  void close() {
    _closed = true;
    _token = '';
    account = '';
    _client.close(force: true);
  }
}

DateTime? _instant(dynamic value) => value is Map && value['dateTime'] is String
    ? (RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value['dateTime'] as String)
          ? DateTime.tryParse(value['dateTime'] as String)?.toUtc()
          : null)
    : null;
String _clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

List<ScheduleRow> calendarRows(
  List<Map<String, dynamic>> events,
  Map<String, Map<String, dynamic>> masters, {
  required String calendar,
  required String account,
  required String from,
  required String to,
}) {
  final rows = <ScheduleRow>[];
  final calendarKey = scheduleHash([account.toLowerCase(), calendar]);
  String key(String id, [int? weekday]) =>
      'google:${scheduleHash([calendarKey, id, weekday])}';
  Map<String, dynamic> remote(String id, bool series) => {
    'calendarId': calendar,
    'eventId': id,
    'account': account,
    'series': series,
  };
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final e in events) {
    if (e['id'] is! String) {
      throw const DraftFailure('Identitas event kalender belum valid.');
    }
    final master = masters[e['recurringEventId']];
    final rule = master?['recurrence'];
    final rules = rule is List ? rule.whereType<String>().toList() : <String>[];
    final weekly =
        rules.length == 1 &&
        rules.first.startsWith('RRULE:') &&
        rules.first
            .substring(6)
            .split(';')
            .every(
              (p) => RegExp(
                r'^(FREQ=WEEKLY|INTERVAL=1|BYDAY=(MO|TU|WE|TH|FR|SA|SU)(,(MO|TU|WE|TH|FR|SA|SU))*|UNTIL=\d{8}(T\d{6}Z)?|COUNT=\d+|WKST=(MO|TU|WE|TH|FR|SA|SU))$',
              ).hasMatch(p),
            ) &&
        rules.first.contains('FREQ=WEEKLY');
    final original = _instant(e['originalStartTime']) ?? _instant(e['start']);
    if (weekly &&
        original != null &&
        _instant(master?['start']) != null &&
        _instant(master?['end']) != null) {
      final day = agendaLocal(original).weekday;
      groups.putIfAbsent('${e['recurringEventId']}|$day', () => []).add(e);
      continue;
    }
    final start = _instant(e['start']), end = _instant(e['end']);
    final local = start == null ? null : agendaLocal(start),
        finish = end == null ? null : agendaLocal(end);
    final cancelled = e['status'] == 'cancelled';
    rows.add(
      ScheduleRow(
        id: key(e['id'] as String),
        title: e['summary'] as String? ?? 'Tanpa judul',
        weekly: false,
        date: local == null
            ? (e['start'] is Map ? e['start']['date'] as String? : null)
            : dateKey(local),
        start: local == null ? '' : _clock(local),
        end: finish == null ? '' : _clock(finish),
        location: e['location'] as String? ?? '',
        provider: 'google',
        sourceKey: key(e['id'] as String),
        sourceVersion: e['etag'] as String? ?? '',
        calendarKey: calendarKey,
        remote: remote(e['id'] as String, false),
        cancelled: cancelled,
        included: cancelled || start != null,
        issue: cancelled
            ? ''
            : start == null
            ? 'Kegiatan sepanjang hari: pilih jam atau keluarkan dari impor.'
            : finish == null || dateKey(local!) != dateKey(finish)
            ? 'Periksa waktu kegiatan yang melewati tengah malam.'
            : '',
      ),
    );
  }
  for (final group in groups.values) {
    group.sort(
      (a, b) =>
          (_instant(a['originalStartTime']) ?? _instant(a['start']))!.compareTo(
            (_instant(b['originalStartTime']) ?? _instant(b['start']))!,
          ),
    );
    final masterId = group.first['recurringEventId'] as String,
        master = masters[masterId]!;
    final original = agendaLocal(
      (_instant(group.first['originalStartTime']) ??
          _instant(group.first['start']))!,
    );
    final last = agendaLocal(
      (_instant(group.last['originalStartTime']) ??
          _instant(group.last['start']))!,
    );
    final baseStart = agendaLocal(_instant(master['start'])!),
        baseEnd = agendaLocal(_instant(master['end'])!);
    final title = master['summary'] as String? ?? 'Tanpa judul',
        location = master['location'] as String? ?? '';
    final exceptions = <String, dynamic>{};
    final byDate = {
      for (final e in group)
        dateKey(
          agendaLocal(
            (_instant(e['originalStartTime']) ?? _instant(e['start']))!,
          ),
        ): e,
    };
    for (
      var day = DateTime.utc(original.year, original.month, original.day);
      !day.isAfter(DateTime.utc(last.year, last.month, last.day));
      day = day.add(const Duration(days: 7))
    ) {
      final date = dateKey(day), e = byDate[date];
      final expected = agendaUtc(day, baseStart.hour, baseStart.minute);
      final at = _instant(e?['start']) ?? expected;
      final end = _instant(e?['end']) ?? at.add(baseEnd.difference(baseStart));
      final cancelled = e == null || e['status'] == 'cancelled';
      if (cancelled ||
          at != expected ||
          end.difference(at) != baseEnd.difference(baseStart)) {
        exceptions[date] = AgendaInput(
          title: title,
          kind: 'class',
          description: location.isEmpty ? '' : 'Lokasi: $location',
          startAtUtc: at,
          durationMinutes: end.difference(at).inMinutes,
          status: cancelled ? 'cancelled' : 'planned',
        ).toJson();
      }
    }
    rows.add(
      ScheduleRow(
        id: key(masterId, original.weekday),
        title: title,
        weekday: original.weekday,
        start: _clock(baseStart),
        end: _clock(baseEnd),
        location: location,
        date: dateKey(original),
        until: dateKey(last),
        exceptions: exceptions,
        provider: 'google',
        sourceKey: key(masterId, original.weekday),
        calendarKey: calendarKey,
        sourceVersion: scheduleHash([
          master['etag'],
          group
              .map(
                (e) => [e['id'], e['etag'], e['status'], e['start'], e['end']],
              )
              .toList(),
        ]),
        remote: remote(masterId, true),
        issue:
            baseStart.isBefore(baseEnd) &&
                dateKey(baseStart) == dateKey(baseEnd)
            ? ''
            : 'Periksa durasi seri dari Google Calendar.',
      ),
    );
  }
  return rows;
}
