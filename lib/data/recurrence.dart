import 'dart:convert';

import 'agenda.dart';
import 'finance.dart';

DateTime _day(String value) => DateTime.parse('${value}T00:00:00Z');

// Weekly patterns keep stable original dates; moving a meeting never changes its key.
(String, String)? occurrenceKey(String id) {
  final m = RegExp(r'^([A-Za-z0-9_-]{1,60})__(\d{4}-\d{2}-\d{2})$')
      .firstMatch(id);
  return m != null && validDate(m[2]!) ? (m[1]!, m[2]!) : null;
}

AgendaInput agendaJson(Map<String, dynamic> m) => AgendaInput(
  title: m['title'] as String,
  description: m['description'] as String? ?? '',
  kind: m['kind'] as String? ?? 'class',
  durationMinutes: m['durationMinutes'] as int,
  startAtUtc: m['startAtUtc'] == null
      ? null
      : DateTime.parse(m['startAtUtc'] as String).toUtc(),
  deadlineAtUtc: m['deadlineAtUtc'] == null
      ? null
      : DateTime.parse(m['deadlineAtUtc'] as String).toUtc(),
  priority: m['priority'] as String? ?? 'normal',
  status: m['status'] as String? ?? 'planned',
  recurrence: m['recurrence'] as Map<String, dynamic>?,
);
AgendaInput agendaCopy(
  AgendaInput a, {
  DateTime? start,
  String? status,
  Map<String, dynamic>? recurrence,
}) => AgendaInput(
  title: a.title,
  description: a.description,
  kind: a.kind,
  durationMinutes: a.durationMinutes,
  startAtUtc: start ?? a.startAtUtc,
  deadlineAtUtc: a.deadlineAtUtc,
  priority: a.priority,
  status: status ?? a.status,
  recurrence: recurrence ?? a.recurrence,
);
Map<String, dynamic> weeklyPattern(DateTime start, {String? until}) => {
  'type': 'weekly',
  'originDate': dateKey(agendaLocal(start)),
  'untilLocalDate': until,
  'exceptions': '{}',
  'changes': '{}',
};
Map<String, dynamic> _map(Map<String, dynamic> r, String field) {
  final raw = r[field];
  if (raw is! String || raw.length > 60000) {
    throw const AgendaFailure('Pola pengulangan tidak valid.');
  }
  final map = jsonDecode(raw);
  if (map is! Map<String, dynamic> ||
      map.length > (field == 'exceptions' ? 64 : 16)) {
    throw const AgendaFailure('Pengecualian seri melebihi batas.');
  }
  for (final e in map.entries) {
    if (!validDate(e.key) ||
        e.value is! Map<String, dynamic> ||
        agendaJson(e.value).recurrence != null ||
        agendaJson(e.value).kind != 'class' ||
        agendaJson(e.value).deadlineAtUtc != null ||
        agendaJson(e.value).validate() != null ||
        _day(e.key).difference(_day(r['originDate'] as String)).inDays < 0 ||
        _day(e.key).difference(_day(r['originDate'] as String)).inDays % 7 !=
            0) {
      throw const AgendaFailure('Pengecualian seri tidak valid.');
    }
  }
  return map;
}

String? validateWeekly(AgendaInput a) {
  try {
    final r = a.recurrence!;
    if (jsonEncode(a.toJson()).length > 60000) {
      return 'Seri terlalu besar. Kurangi pengecualian atau mulai seri baru.';
    }
    if (a.kind != 'class' ||
        a.startAtUtc == null ||
        a.deadlineAtUtc != null ||
        r['type'] != 'weekly' ||
        !validDate(r['originDate'] as String) ||
        r['untilLocalDate'] != null &&
            (!validDate(r['untilLocalDate'] as String) ||
                (r['untilLocalDate'] as String).compareTo(
                      r['originDate'] as String,
                    ) <
                    0)) {
      return 'Periksa tanggal pengulangan kuliah.';
    }
    _map(r, 'exceptions');
    _map(r, 'changes');
    return null;
  } catch (_) {
    return 'Pola pengulangan tidak valid.';
  }
}

AgendaItem? weeklyMeeting(AgendaItem series, String originalDate) {
  final a = series.input,
      r = a.recurrence!,
      origin = _day(r['originDate'] as String),
      date = _day(originalDate),
      days = date.difference(origin).inDays;
  if (days < 0 ||
      days % 7 != 0 ||
      r['untilLocalDate'] != null &&
          originalDate.compareTo(r['untilLocalDate'] as String) > 0) {
    return null;
  }
  final changes = _map(r, 'changes'), exceptions = _map(r, 'exceptions');
  var input = a, base = origin;
  for (final key in changes.keys.toList()..sort()) {
    if (key.compareTo(originalDate) <= 0) {
      input = agendaJson(changes[key]);
      base = _day(key);
    }
  }
  var projected = agendaCopy(
    input,
    start: input.startAtUtc!.add(Duration(days: date.difference(base).inDays)),
  );
  // Derived inputs never carry a repeating pattern into a single-meeting editor.
  projected = AgendaInput(
    title: projected.title,
    description: projected.description,
    kind: projected.kind,
    durationMinutes: projected.durationMinutes,
    startAtUtc: projected.startAtUtc,
    priority: projected.priority,
    status: a.status == 'planned' ? projected.status : a.status,
  );
  if (exceptions[originalDate] != null) {
    projected = agendaJson(exceptions[originalDate]);
  }
  if (a.status != 'planned') projected = projected.withStatus(a.status);
  return AgendaItem(
    id: '${series.id}__$originalDate',
    version: series.version,
    importSource: series.importSource,
    input: projected,
  );
}

List<AgendaItem> expandWeekly(
  List<AgendaItem> series,
  DateTime from,
  DateTime to,
) {
  final output = <AgendaItem>[];
  if (to.difference(from).inDays > 90) {
    throw const AgendaFailure('Pilih rentang paling banyak 90 hari.');
  }
  for (final s in series) {
    final invalid = validateWeekly(s.input);
    if (invalid != null) throw AgendaFailure(invalid);
    final r = s.input.recurrence!,
        origin = _day(r['originDate'] as String),
        candidates = <String>{};
    final phases = {
      r['originDate'] as String: s.input.toJson(),
      ..._map(r, 'changes'),
    };
    for (final e in phases.entries) {
      final a = agendaJson(Map<String, dynamic>.from(e.value as Map)),
          base = _day(e.key),
          first = a.startAtUtc!;
      final low =
              ((from.difference(first).inMinutes - s.input.durationMinutes) /
                      10080)
                  .floor() -
              1,
          high = (to.difference(first).inMinutes / 10080).ceil() + 1;
      if (high - low > 20) {
        throw const AgendaFailure('Rentang seri terlalu besar.');
      }
      for (var n = low; n <= high; n++) {
        final d = base.add(Duration(days: n * 7));
        if (!d.isBefore(origin)) candidates.add(dateKey(d));
      }
    }
    candidates.addAll(_map(r, 'exceptions').keys);
    for (final d in candidates) {
      final a = weeklyMeeting(s, d);
      if (a != null &&
          a.input.startAtUtc!.isBefore(to) &&
          a.input.endAtUtc!.isAfter(from)) {
        output.add(a);
      }
    }
  }
  output.sort((a, b) => a.input.startAtUtc!.compareTo(b.input.startAtUtc!));
  return output;
}

AgendaItem? nextWeekly(AgendaItem s, DateTime now) {
  final r = s.input.recurrence!, candidates = <AgendaItem>[];
  final phases = {
    r['originDate'] as String: s.input.toJson(),
    ..._map(r, 'changes'),
  };
  for (final e in phases.entries) {
    final a = agendaJson(Map<String, dynamic>.from(e.value as Map)),
        base = _day(e.key);
    var n = (now.difference(a.startAtUtc!).inMinutes / 10080).floor();
    if (n < 0) n = 0;
    // 64 overrides + 16 changes bound skips; no expansion of an infinite series.
    for (var i = 0; i < 82; i++, n++) {
      final m = weeklyMeeting(s, dateKey(base.add(Duration(days: n * 7))));
      if (m != null &&
          m.input.status == 'planned' &&
          m.input.startAtUtc!.isAfter(now)) {
        candidates.add(m);
        if (!_map(r, 'exceptions').containsKey(occurrenceKey(m.id)!.$2)) break;
      }
    }
  }
  for (final d in _map(r, 'exceptions').keys) {
    final m = weeklyMeeting(s, d);
    if (m != null &&
        m.input.status == 'planned' &&
        m.input.startAtUtc!.isAfter(now)) {
      candidates.add(m);
    }
  }
  candidates.sort((a, b) => a.input.startAtUtc!.compareTo(b.input.startAtUtc!));
  return candidates.firstOrNull;
}

extension AgendaRange on AgendaSnapshot {
  List<AgendaItem> between(DateTime from, DateTime to) => [
    ...(singles ?? items).where(
      (a) =>
          a.input.startAtUtc == null ||
          a.input.startAtUtc!.isBefore(to) && a.input.endAtUtc!.isAfter(from),
    ),
    ...expandWeekly(series, from, to),
  ];
}
