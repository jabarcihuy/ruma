import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agenda.dart';
import 'assistant_draft.dart';
import 'finance.dart' show dateKey, validDate;
import 'recurrence.dart';

// Bounded approval: leaves room for receipt/core and reminder validation in Rules.
const scheduleImportLimit = 8;
String scheduleHash(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
String scheduleFingerprint(AgendaInput input) => scheduleHash(input.toJson());
String scheduleIdentity(AgendaInput input) => scheduleHash({
  'title': input.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
  'start': input.startAtUtc?.toIso8601String(),
  'minutes': input.durationMinutes,
  'recurrence': input.recurrence,
});

class ScheduleRow {
  ScheduleRow({
    required this.id,
    this.title = '',
    this.weekday,
    this.start = '',
    this.end = '',
    this.location = '',
    this.issue = '',
    this.imageIndex,
    this.weekly = true,
    this.date,
    this.until,
    this.exceptions = const {},
    this.provider = 'image',
    this.sourceKey = '',
    this.sourceVersion = '',
    this.calendarKey = '',
    this.remote = const {},
    this.included = true,
    this.useSource = false,
    this.cancelled = false,
    this.originalFingerprint,
  });
  final String id;
  String title,
      start,
      end,
      location,
      issue,
      provider,
      sourceKey,
      sourceVersion,
      calendarKey;
  int? weekday, imageIndex;
  bool weekly, included, useSource, cancelled;
  String? date, until;
  Map<String, dynamic> exceptions, remote;
  String? originalFingerprint;

  String? validate(String from, String to) {
    if (cancelled) return null;
    if (issue.isNotEmpty) return issue;
    if (title.trim().isEmpty || title.length > 120) {
      return 'Periksa nama mata kuliah.';
    }
    final clock = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (!clock.hasMatch(start) ||
        !clock.hasMatch(end) ||
        end.compareTo(start) <= 0) {
      return 'Periksa jam mulai dan selesai.';
    }
    if (weekly && (weekday == null || weekday! < 1 || weekday! > 7)) {
      return 'Pilih hari pertemuan.';
    }
    if (!weekly && (date == null || !validDate(date!))) {
      return 'Pilih tanggal kegiatan.';
    }
    if (!validDate(from) || !validDate(to) || from.compareTo(to) > 0) {
      return 'Periksa periode semester.';
    }
    if (!weekly && date!.compareTo(from) < 0) {
      return 'Tanggal kegiatan berada di luar periode pilihan.';
    }
    if (DateTime.parse(to).difference(DateTime.parse(from)).inDays > 366) {
      return 'Pilih periode paling banyak satu tahun.';
    }
    if (weekly &&
        exceptions.keys.any((key) => DateTime.parse(key).weekday != weekday)) {
      return 'Seri ini memiliki pertemuan khusus. Pertahankan hari sumber saat impor, lalu ubah pertemuan di Agenda.';
    }
    try {
      return build(from, to).validate();
    } catch (_) {
      return 'Periksa hari, waktu, dan periode jadwal.';
    }
  }

  AgendaInput build(String from, String to) {
    var day = DateTime.parse('${date ?? from}T00:00:00Z');
    if (weekly) {
      if (date == null || date!.compareTo(from) < 0) {
        day = DateTime.parse('${from}T00:00:00Z');
      }
      day = day.add(Duration(days: (weekday! - day.weekday + 7) % 7));
    }
    final endDate = until != null && until!.compareTo(to) < 0 ? until! : to;
    if (dateKey(day).compareTo(endDate) > 0) {
      throw const DraftFailure('Tidak ada pertemuan dalam periode ini.');
    }
    final parts = start.split(':').map(int.parse).toList();
    final finish = end.split(':').map(int.parse).toList();
    final at = agendaUtc(day, parts[0], parts[1]);
    return AgendaInput(
      title: title.trim(),
      kind: weekly ? 'class' : 'task',
      description: location.isEmpty ? '' : 'Lokasi: $location',
      startAtUtc: at,
      durationMinutes: finish[0] * 60 + finish[1] - parts[0] * 60 - parts[1],
      recurrence: weekly
          ? {
              ...weeklyPattern(at, until: endDate),
              'exceptions': jsonEncode(
                Map.fromEntries(
                  exceptions.entries.where(
                    (e) =>
                        e.key.compareTo(dateKey(day)) >= 0 &&
                        e.key.compareTo(endDate) <= 0,
                  ),
                ),
              ),
            }
          : null,
    );
  }

  Map<String, dynamic> source(AgendaInput input) => {
    'provider': provider,
    'key': sourceKey.isEmpty ? 'image:${scheduleIdentity(input)}' : sourceKey,
    'version': sourceVersion,
    'calendarKey': calendarKey,
    'fingerprint': originalFingerprint ?? scheduleFingerprint(input),
    'remote': remote,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'weekday': weekday,
    'start': start,
    'end': end,
    'location': location,
    'issue': issue,
    'imageIndex': imageIndex,
    'weekly': weekly,
    'date': date,
    'until': until,
    'exceptions': exceptions,
    'provider': provider,
    'sourceKey': sourceKey,
    'sourceVersion': sourceVersion,
    'calendarKey': calendarKey,
    'remote': remote,
    'included': included,
    'useSource': useSource,
    'cancelled': cancelled,
    'originalFingerprint': originalFingerprint,
  };
  factory ScheduleRow.fromJson(Map<String, dynamic> v) => ScheduleRow(
    id: v['id'] as String,
    title: v['title'] as String? ?? '',
    weekday: v['weekday'] as int?,
    start: v['start'] as String? ?? '',
    end: v['end'] as String? ?? '',
    location: v['location'] as String? ?? '',
    issue: v['issue'] as String? ?? '',
    imageIndex: v['imageIndex'] as int?,
    weekly: v['weekly'] as bool? ?? true,
    date: v['date'] as String?,
    until: v['until'] as String?,
    exceptions: Map<String, dynamic>.from(v['exceptions'] as Map? ?? {}),
    provider: v['provider'] as String? ?? 'image',
    sourceKey: v['sourceKey'] as String? ?? '',
    sourceVersion: v['sourceVersion'] as String? ?? '',
    calendarKey: v['calendarKey'] as String? ?? '',
    remote: Map<String, dynamic>.from(v['remote'] as Map? ?? {}),
    included: v['included'] as bool? ?? true,
    useSource: v['useSource'] as bool? ?? false,
    cancelled: v['cancelled'] as bool? ?? false,
    originalFingerprint: v['originalFingerprint'] as String?,
  );
}

class ScheduleWorkspace {
  ScheduleWorkspace({
    required this.id,
    required this.from,
    required this.to,
    required this.rows,
    this.source = 'Gambar jadwal',
    this.revision = 1,
    this.operationId = '',
    this.attempted = false,
    this.applied = false,
    this.plans = const [],
    this.baseRevision = 0,
    this.resultCount = 0,
    this.periodConfirmed = false,
    this.corrections = const [],
  });
  final String id;
  String from, to, source, operationId;
  final List<ScheduleRow> rows;
  int revision, baseRevision, resultCount;
  bool attempted, applied;
  bool periodConfirmed;
  List<Map<String, dynamic>> plans;
  List<Map<String, String>> corrections;
  bool get locked => attempted || applied;
  void changed() {
    if (locked) {
      throw const DraftFailure(
        'Periksa hasil penyimpanan sebelum mengubah usulan.',
      );
    }
    revision++;
    operationId = '';
    plans = [];
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'from': from,
    'to': to,
    'source': source,
    'revision': revision,
    'operationId': operationId,
    'attempted': attempted,
    'applied': applied,
    'plans': plans,
    'baseRevision': baseRevision,
    'resultCount': resultCount,
    'rows': rows.map((r) => r.toJson()).toList(),
    'periodConfirmed': periodConfirmed,
    'corrections': corrections,
  };
  factory ScheduleWorkspace.fromJson(Map<String, dynamic> v) {
    if (v['schemaVersion'] != 1 ||
        v['rows'] is! List ||
        (v['rows'] as List).length > 500) {
      throw const DraftFailure('Tinjauan impor tidak dapat dibaca.');
    }
    return ScheduleWorkspace(
      id: v['id'] as String,
      from: v['from'] as String,
      to: v['to'] as String,
      source: v['source'] as String,
      revision: v['revision'] as int,
      operationId: v['operationId'] as String? ?? '',
      attempted: v['attempted'] as bool? ?? false,
      applied: v['applied'] as bool? ?? false,
      baseRevision: v['baseRevision'] as int? ?? 0,
      resultCount: v['resultCount'] as int? ?? 0,
      periodConfirmed: v['periodConfirmed'] as bool? ?? false,
      corrections: (v['corrections'] as List? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      plans: (v['plans'] as List? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList(),
      rows: (v['rows'] as List)
          .map((r) => ScheduleRow.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
  String get requestKey => jsonEncode({
    'id': id,
    'revision': revision,
    'baseRevision': baseRevision,
    'plans': plans,
  });
}

List<AgendaItem> scheduleOccurrences(
  AgendaInput input,
  String id,
  String from,
  String to,
) {
  if (input.recurrence == null) {
    return [AgendaItem(id: id, version: 1, input: input)];
  }
  final result = <AgendaItem>[];
  var low = agendaUtc(DateTime.parse('${from}T00:00:00Z'), 0, 0);
  final end = agendaUtc(
    DateTime.parse('${to}T00:00:00Z').add(const Duration(days: 1)),
    0,
    0,
  );
  while (low.isBefore(end)) {
    final high = low.add(const Duration(days: 60)).isBefore(end)
        ? low.add(const Duration(days: 60))
        : end;
    result.addAll(
      expandWeekly([AgendaItem(id: id, version: 1, input: input)], low, high),
    );
    low = high;
  }
  return {for (final item in result) item.id: item}.values.toList();
}
