import 'dart:convert';

import 'recurrence.dart';

// The first agenda slice uses WIB. UTC values never depend on the phone zone.
DateTime agendaLocal(DateTime utc) => utc.toUtc().add(const Duration(hours: 7));
DateTime agendaUtc(DateTime date, int hour, int minute) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  hour,
  minute,
).subtract(const Duration(hours: 7));
DateTime agendaDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class AgendaFailure implements Exception {
  const AgendaFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AgendaInput {
  const AgendaInput({
    required this.title,
    this.description = '',
    this.kind = 'task',
    this.durationMinutes = 60,
    this.startAtUtc,
    this.deadlineAtUtc,
    this.priority = 'normal',
    this.status = 'planned',
    this.recurrence,
  });
  final String title, description, kind, priority, status;
  final int durationMinutes;
  final Map<String, dynamic>? recurrence;
  final DateTime? startAtUtc, deadlineAtUtc;
  DateTime? get endAtUtc => startAtUtc?.add(Duration(minutes: durationMinutes));
  String? validate() {
    if (title.trim().isEmpty || title.trim().length > 120) {
      return 'Isi nama kegiatan, maksimal 120 karakter.';
    }
    if (description.length > 1000) return 'Catatan maksimal 1.000 karakter.';
    if (!['class', 'task'].contains(kind)) {
      return 'Pilih jenis kegiatan yang tersedia.';
    }
    if (durationMinutes < 5 || durationMinutes > 720) {
      return 'Durasi antara 5 dan 720 menit.';
    }
    if (kind == 'class' && startAtUtc == null) {
      return 'Atur tanggal dan jam kuliah.';
    }
    if (endAtUtc != null &&
        deadlineAtUtc != null &&
        endAtUtc!.isAfter(deadlineAtUtc!)) {
      return 'Kegiatan harus selesai sebelum deadline.';
    }
    if (!['low', 'normal', 'high'].contains(priority) ||
        !['planned', 'completed', 'cancelled'].contains(status)) {
      return 'Pilihan kegiatan tidak valid.';
    }
    if (recurrence != null) return validateWeekly(this);
    return null;
  }

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description,
    'kind': kind,
    'durationMinutes': durationMinutes,
    'startAtUtc': startAtUtc?.toUtc().toIso8601String(),
    'deadlineAtUtc': deadlineAtUtc?.toUtc().toIso8601String(),
    'priority': priority,
    'status': status,
    if (recurrence != null) 'recurrence': recurrence,
  };
  AgendaInput withStatus(String value) => AgendaInput(
    title: title,
    description: description,
    kind: kind,
    durationMinutes: durationMinutes,
    startAtUtc: startAtUtc,
    deadlineAtUtc: deadlineAtUtc,
    priority: priority,
    status: value,
    recurrence: recurrence,
  );
  bool overlaps(AgendaInput other) =>
      status == 'planned' &&
      other.status == 'planned' &&
      startAtUtc != null &&
      other.startAtUtc != null &&
      startAtUtc!.isBefore(other.endAtUtc!) &&
      endAtUtc!.isAfter(other.startAtUtc!);
}

class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.version,
    required this.input,
  });
  final String id;
  final int version;
  final AgendaInput input;
  bool occursOn(DateTime day) {
    if (input.startAtUtc == null) return false;
    final from = agendaUtc(day, 0, 0), to = from.add(const Duration(days: 1));
    return input.startAtUtc!.isBefore(to) && input.endAtUtc!.isAfter(from);
  }
}

class AgendaSnapshot {
  const AgendaSnapshot(
    this.items,
    this.revision, {
    this.series = const [],
    this.singles,
  });
  final List<AgendaItem> series;
  final List<AgendaItem>? singles;
  final List<AgendaItem> items;
  final int revision;
}

class AgendaMutation {
  const AgendaMutation({
    required this.operationId,
    required this.id,
    required this.input,
    this.originalVersion,
    this.delete = false,
    this.restore = false,
    this.scope = 'one',
  });
  final String operationId, id, scope;
  final AgendaInput input;
  final int? originalVersion;
  final bool delete, restore;
  String get kind => delete
      ? 'agenda_delete'
      : originalVersion == null
      ? 'agenda_create'
      : 'agenda_update';
  String get requestKey => jsonEncode({
    'id': id,
    if (scope != 'one') 'scope': scope,
    'version': originalVersion,
    'delete': delete,
    if (restore) 'restore': true,
    'input': input.toJson(),
  });
}
