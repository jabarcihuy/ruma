import 'dart:convert';

import 'agenda.dart';
import 'agent_tools.dart';
import 'assistant_draft.dart';
import 'finance.dart';

// A bounded personal workspace, not model context or a second ledger.
const assistantPayloadLimit = 160000;
Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);
String _text(dynamic v, int max) {
  if (v is! String || v.length > max) throw const FormatException();
  return v;
}

String _id(dynamic v) {
  final s = _text(v, 128);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(s)) {
    throw const FormatException();
  }
  return s;
}

int _number(dynamic v, [int min = 0, int max = 1000000000]) {
  if (v is! int || v < min || v > max) throw const FormatException();
  return v;
}

bool _flag(dynamic v) {
  if (v is! bool) throw const FormatException();
  return v;
}

AgendaInput? _agenda(dynamic value) {
  if (value == null) return null;
  final v = _map(value);
  DateTime? time(dynamic x) {
    if (x == null) return null;
    final s = _text(x, 40), d = DateTime.parse(s);
    if (!s.endsWith('Z') ||
        d.toUtc().toIso8601String() != s ||
        d.year < 2000 ||
        d.year > 2200) {
      throw const FormatException();
    }
    return d;
  }

  final a = AgendaInput(
    title: _text(v['title'], 120),
    description: _text(v['description'], 1000),
    kind: _text(v['kind'], 10),
    durationMinutes: _number(v['durationMinutes'], 5, 720),
    startAtUtc: time(v['startAtUtc']),
    deadlineAtUtc: time(v['deadlineAtUtc']),
    priority: _text(v['priority'], 10),
    status: _text(v['status'], 10),
  );
  if (a.validate() != null) throw const FormatException();
  return a;
}

TransactionInput? _money(dynamic value) {
  if (value == null) return null;
  final v = _map(value);
  final m = TransactionInput(
    type: _text(v['type'], 10),
    amountRupiah: _number(v['amountRupiah'], 1),
    categoryId: _text(v['categoryId'], 30),
    localDate: _text(v['localDate'], 10),
    description: _text(v['description'], 1000),
  );
  if (m.validate() != null) throw const FormatException();
  return m;
}

Map<String, dynamic>? draftSnapshot(AssistantDraft? d) => d == null
    ? null
    : {
        'id': d.id,
        'uid': d.uid,
        'operationId': d.operationId,
        'revision': d.revision,
        'agendaRevision': d.baseAgendaRevision,
        'financeRevision': d.baseFinanceRevision,
        'applied': d.applied,
        'attempted': d.attempted,
        'items': d.items
            .map(
              (e) => {
                ...e.toJson(),
                'quote': e.quote,
                'included': e.included,
                'suggestedTime': e.suggestedTime,
              },
            )
            .toList(),
      };
AssistantDraft? restoreDraft(dynamic value, String uid) {
  if (value == null) return null;
  final v = _map(value), raw = v['items'] as List;
  if (v['uid'] != uid || raw.isEmpty || raw.length > 6) {
    throw const FormatException();
  }
  final entries = raw.map((x) {
    final e = _map(x), a = _agenda(e['agenda']), m = _money(e['money']);
    final date = _text(e['localDate'], 10);
    if ((a == null) == (m == null) || !validDate(date)) {
      throw const FormatException();
    }
    return DraftEntry(
      id: _id(e['id']),
      quote: _text(e['quote'], 4000),
      localDate: date,
      agenda: a,
      money: m,
      included: _flag(e['included']),
      suggestedTime: _flag(e['suggestedTime']),
    );
  }).toList();
  if (entries.map((e) => e.id).toSet().length != entries.length ||
      entries.where((e) => e.agenda != null).length > 3 ||
      entries.where((e) => e.money != null).length > 3) {
    throw const FormatException();
  }
  return AssistantDraft(
      id: _id(v['id']),
      operationId: _id(v['operationId']),
      uid: uid,
      items: entries,
      baseAgendaRevision: _number(v['agendaRevision']),
      baseFinanceRevision: _number(v['financeRevision']),
    )
    ..revision = _number(v['revision'], 1)
    ..applied = _flag(v['applied'])
    ..attempted = _flag(v['attempted']);
}

Map<String, dynamic>? recordSnapshot(RecordDraft? d) => d == null
    ? null
    : {
        'id': d.id,
        'operationId': d.operationId,
        'version': d.version,
        'delete': d.delete,
        'beforeAgenda': d.beforeAgenda?.toJson(),
        'beforeMoney': d.beforeMoney?.toJson(),
        'agenda': d.agenda?.toJson(),
        'money': d.money?.toJson(),
        'applied': d.applied,
        'attempted': d.attempted,
        'undone': d.undone,
        'undoAttempted': d.undoAttempted,
        'undoOperationId': d.undoOperationId,
      };
RecordDraft? restoreRecord(dynamic value) {
  if (value == null) return null;
  final v = _map(value),
      a = _agenda(v['agenda']),
      m = _money(v['money']),
      beforeA = _agenda(v['beforeAgenda']),
      beforeM = _money(v['beforeMoney']);
  if ((a == null) == (m == null) ||
      (a == null) != (beforeA == null) ||
      (m == null) != (beforeM == null)) {
    throw const FormatException();
  }
  final d =
      RecordDraft(
          id: _id(v['id']),
          operationId: _id(v['operationId']),
          version: _number(v['version'], 1),
          delete: _flag(v['delete']),
          agenda: a,
          money: m,
          beforeAgenda: beforeA,
          beforeMoney: beforeM,
        )
        ..applied = _flag(v['applied'])
        ..attempted = _flag(v['attempted'])
        ..undone = _flag(v['undone'])
        ..undoAttempted = _flag(v['undoAttempted'])
        ..undoOperationId = v['undoOperationId'] == null
            ? null
            : _id(v['undoOperationId']);
  if ((d.undone || d.undoAttempted) &&
      (!d.applied || d.undoOperationId == null)) {
    throw const FormatException();
  }
  return d;
}

class AssistantSnapshot {
  AssistantSnapshot({
    this.input = '',
    this.message = '',
    this.reply = '',
    this.at = '',
    this.history = const [],
    this.draft,
    this.record,
    this.from = 480,
    this.to = 1260,
  });
  final String input, message, reply, at;
  final List<Map<String, String>> history;
  final AssistantDraft? draft;
  final RecordDraft? record;
  final int from, to;
  String encode(String uid) {
    if (input.length > 4000 || message.length > 4000 || reply.length > 25000) {
      throw const DraftFailure(
        'Pesan atau jawaban terlalu panjang untuk disimpan.',
      );
    }
    final rows = history
        .skip(history.length > 10 ? history.length - 10 : 0)
        .toList();
    String pack() => jsonEncode({
      'schemaVersion': 1,
      'uid': uid,
      'input': input,
      'message': message,
      'reply': reply,
      'at': at,
      'history': rows,
      'draft': draftSnapshot(draft),
      'record': recordSnapshot(record),
      'from': from,
      'to': to,
    });
    var data = pack();
    while (data.length > assistantPayloadLimit && rows.isNotEmpty) {
      rows.removeAt(0);
      data = pack();
    }
    if (data.length > assistantPayloadLimit) {
      throw const DraftFailure('Riwayat terlalu besar untuk disimpan.');
    }
    return data;
  }

  static AssistantSnapshot decode(String data, String uid) {
    try {
      if (data.length > assistantPayloadLimit) throw const FormatException();
      final v = _map(jsonDecode(data)), raw = v['history'] as List;
      if (v['schemaVersion'] != 1 ||
          v['uid'] != uid ||
          raw.length > 10 ||
          v['draft'] != null && v['record'] != null) {
        throw const FormatException();
      }
      final from = _number(v['from'], 0, 1439), to = _number(v['to'], 1, 1440);
      if (from >= to) throw const FormatException();
      return AssistantSnapshot(
        input: _text(v['input'], 4000),
        message: _text(v['message'], 4000),
        reply: _text(v['reply'], 25000),
        at: _text(v['at'], 40),
        history: raw.map((x) {
          final r = _map(x);
          return {
            'message': _text(r['message'], 4000),
            'reply': _text(r['reply'], 25000),
            'at': _text(r['at'], 40),
          };
        }).toList(),
        draft: restoreDraft(v['draft'], uid),
        record: restoreRecord(v['record']),
        from: from,
        to: to,
      );
    } catch (_) {
      throw const DraftFailure(
        'Riwayat Asisten tidak dapat dibaca dengan aman. Data tidak ditimpa.',
      );
    }
  }
}
