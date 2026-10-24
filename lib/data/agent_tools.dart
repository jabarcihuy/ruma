import 'agenda.dart';
import 'assistant_draft.dart';
import 'finance.dart';

// WIB only. The window is chosen by the user, not inferred from empty calendar cells.
AgendaInput? suggestSlot(
  AgendaInput input,
  String date,
  Iterable<AgendaInput> busy, {
  required DateTime now,
  int fromMinute = 480,
  int toMinute = 1260,
}) {
  if (!validDate(date) ||
      fromMinute < 0 ||
      toMinute > 1440 ||
      fromMinute >= toMinute ||
      input.startAtUtc != null) {
    return null;
  }
  final day = DateTime.parse(date);
  final end = agendaUtc(day, 0, toMinute);
  var cursor = agendaUtc(day, 0, fromMinute);
  if (cursor.isBefore(now)) {
    final minutes = now.difference(agendaUtc(day, 0, 0)).inMinutes + 1;
    cursor = agendaUtc(day, 0, ((minutes + 4) ~/ 5) * 5);
  }
  final blockers =
      busy.where((a) => a.status == 'planned' && a.startAtUtc != null).toList()
        ..sort((a, b) => a.startAtUtc!.compareTo(b.startAtUtc!));
  while (!cursor.add(Duration(minutes: input.durationMinutes)).isAfter(end)) {
    final candidate = copyAgenda(input, start: cursor);
    if (candidate.validate() != null) return null;
    final clashes = blockers.where((a) => a.overlaps(candidate)).toList();
    if (clashes.isEmpty) return candidate;
    cursor = clashes
        .map((a) => a.endAtUtc!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
  return null;
}

AgendaInput copyAgenda(
  AgendaInput a, {
  String? title,
  int? duration,
  DateTime? start,
  DateTime? deadline,
  String? status,
}) => AgendaInput(
  title: title ?? a.title,
  description: a.description,
  kind: a.kind,
  durationMinutes: duration ?? a.durationMinutes,
  startAtUtc: start ?? a.startAtUtc,
  deadlineAtUtc: deadline ?? a.deadlineAtUtc,
  priority: a.priority,
  status: status ?? a.status,
);

DateTime? parseLocalTime(Object? raw) {
  if (raw == null) return null;
  if (raw is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d$').hasMatch(raw) ||
      !validDate(raw.substring(0, 10))) {
    throw const DraftFailure('Tanggal atau jam AI tidak valid.');
  }
  final d = DateTime.parse(raw);
  return agendaUtc(d, d.hour, d.minute);
}

String normalizeTitle(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

// Only one old record per draft: existing CRUD receipts remain atomic and retryable.
class RecordDraft {
  RecordDraft({
    required this.operationId,
    required this.delete,
    required this.id,
    required this.version,
    this.beforeAgenda,
    this.beforeMoney,
    this.agenda,
    this.money,
  });
  final String id;
  String operationId;
  final int version;
  final bool delete;
  final AgendaInput? beforeAgenda;
  final TransactionInput? beforeMoney;
  AgendaInput? agenda;
  TransactionInput? money;
  bool applied = false,
      attempted = false,
      undone = false,
      undoAttempted = false;
  String? undoOperationId;
  String? validate() => agenda?.validate() ?? money?.validate();
}

RecordDraft resolveRecord(
  Map<String, dynamic> args,
  List<AgendaItem> agendas,
  List<MoneyTransaction> transactions,
  String operationId,
) {
  final title = normalizeTitle(args['targetTitle'] as String);
  final date = args['targetDate'] as String?;
  final isAgenda = args['recordType'] == 'agenda';
  final a = agendas
      .where(
        (x) =>
            normalizeTitle(x.input.title) == title &&
            (date == null ||
                x.input.startAtUtc != null &&
                    dateKey(agendaLocal(x.input.startAtUtc!)) == date),
      )
      .toList();
  final t = transactions
      .where(
        (x) =>
            normalizeTitle(x.input.description) == title &&
            (date == null || x.input.localDate == date),
      )
      .toList();
  final count = isAgenda ? a.length : t.length;
  if (count != 1) {
    throw DraftFailure(
      count == 0
          ? 'Tidak ditemukan satu catatan dengan nama dan tanggal itu. Gunakan nama persis dari Agenda atau Riwayat.'
          : 'Ada beberapa catatan bernama sama. Sebutkan tanggalnya juga; belum ada perubahan.',
    );
  }
  final p = Map<String, dynamic>.from(args['patch'] as Map);
  final deleting = args['action'] == 'delete';
  if (isAgenda) {
    if (['amountRupiah', 'categoryId', 'localDate'].any((k) => p[k] != null)) {
      throw const DraftFailure('Perubahan uang tidak berlaku untuk agenda.');
    }
    final old = a.single;
    final next = copyAgenda(
      old.input,
      title: p['title'] as String?,
      duration: p['durationMinutes'] as int?,
      start: parseLocalTime(p['startLocal']),
      deadline: parseLocalTime(p['deadlineLocal']),
      status: p['status'] as String?,
    );
    if (next.validate() != null) throw DraftFailure(next.validate()!);
    return RecordDraft(
      operationId: operationId,
      id: old.id,
      version: old.version,
      delete: deleting,
      beforeAgenda: old.input,
      agenda: next,
    );
  }
  if ([
    'durationMinutes',
    'startLocal',
    'deadlineLocal',
    'status',
  ].any((k) => p[k] != null)) {
    throw const DraftFailure('Perubahan waktu tidak berlaku untuk transaksi.');
  }
  final old = t.single, b = old.input;
  final next = TransactionInput(
    type: b.type,
    amountRupiah: p['amountRupiah'] as int? ?? b.amountRupiah,
    categoryId: p['categoryId'] as String? ?? b.categoryId,
    localDate: p['localDate'] as String? ?? b.localDate,
    description: p['title'] as String? ?? b.description,
  );
  if (next.validate() != null) throw DraftFailure(next.validate()!);
  return RecordDraft(
    operationId: operationId,
    id: old.id,
    version: old.version,
    delete: deleting,
    beforeMoney: b,
    money: next,
  );
}

String agendaAnswer(AgendaSnapshot snapshot, String date) {
  final items =
      snapshot.items.where((a) => a.occursOn(DateTime.parse(date))).toList()
        ..sort((a, b) => a.input.startAtUtc!.compareTo(b.input.startAtUtc!));
  String time(DateTime d) {
    final x = agendaLocal(d);
    return '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';
  }

  final pending = snapshot.items
      .where((a) => a.input.startAtUtc == null && a.input.status == 'planned')
      .length;
  return 'Agenda $date (WIB): ${items.length} kegiatan.\n'
      '${items.take(20).map((a) => '${time(a.input.startAtUtc!)}–${time(a.input.endAtUtc!)} · ${a.input.title} · ${a.input.status == 'completed'
          ? 'selesai'
          : a.input.status == 'cancelled'
          ? 'dibatalkan'
          : 'terjadwal'}').join('\n')}'
      '${items.length > 20 ? '\nMenampilkan 20 pertama. Lihat Agenda untuk sisanya.' : ''}'
      '${pending > 0 ? '\n$pending tugas belum dijadwalkan (tidak termasuk daftar jam di atas).' : ''}';
}

String moneyAnswer(
  FinanceSnapshot s, {
  bool history = false,
  String? category,
}) {
  final m = s.month;
  if (history) {
    final rows = s.items
        .where((x) => category == null || x.input.categoryId == category)
        .toList();
    return 'Riwayat ${m.key}${category == null ? '' : ' · ${categoryLabel(category)}'}: ${rows.length} transaksi.\n'
        '${rows.take(20).map((x) => '${x.input.localDate} · ${x.input.description.isEmpty ? categoryLabel(x.input.categoryId) : x.input.description} · ${x.input.type == 'income' ? '+' : '-'}${rupiah(x.input.amountRupiah)}').join('\n')}'
        '${rows.length > 20 ? '\nMenampilkan 20 terbaru. Lihat Riwayat untuk sisanya.' : ''}';
  }
  return 'Laporan ${m.key}\nPemasukan ${rupiah(m.income)}\nPengeluaran ${rupiah(m.expense)}\n'
      '${expenseCategories.keys.map((k) => '${categoryLabel(k)}: ${rupiah(m.categoryExpense[k] ?? 0)}').join('\n')}\n'
      '${m.budget == null ? 'Anggaran belum diatur.' : 'Anggaran ${rupiah(m.budget!)} · sisa ${rupiah(m.remaining!)}'}\n'
      'Saldo tercatat seluruh periode ${rupiah(s.balance)}. Hanya mencakup catatan yang kamu masukkan.';
}

void validateReadQuery(Map<String, dynamic> q) {
  if (q.length != 3 ||
      !q.keys.toSet().containsAll(['kind', 'date', 'categoryId']) ||
      !['agenda', 'summary', 'history'].contains(q['kind']) ||
      q['date'] is! String ||
      !(q['kind'] == 'agenda'
          ? validDate(q['date'] as String)
          : validMonth(q['date'] as String)) ||
      q['categoryId'] != null &&
          !{
            ...expenseCategories,
            ...incomeCategories,
          }.containsKey(q['categoryId']) ||
      q['kind'] != 'history' && q['categoryId'] != null) {
    throw const DraftFailure('Permintaan baca AI belum valid.');
  }
}

void validateChange(Map<String, dynamic> a) {
  const keys = [
    'recordType',
    'action',
    'targetTitle',
    'targetDate',
    'sourceQuote',
    'patch',
  ];
  const patchKeys = [
    'title',
    'durationMinutes',
    'startLocal',
    'deadlineLocal',
    'status',
    'amountRupiah',
    'categoryId',
    'localDate',
  ];
  if (a.length != keys.length ||
      !a.keys.toSet().containsAll(keys) ||
      !['agenda', 'transaction'].contains(a['recordType']) ||
      !['update', 'delete'].contains(a['action']) ||
      a['targetTitle'] is! String ||
      (a['targetTitle'] as String).trim().isEmpty ||
      (a['targetTitle'] as String).length > 1000 ||
      a['sourceQuote'] is! String ||
      (a['sourceQuote'] as String).trim().isEmpty ||
      !(a['sourceQuote'] as String).toLowerCase().contains(
        (a['targetTitle'] as String).toLowerCase(),
      ) ||
      (a['targetDate'] == null
          ? a['recordType'] != 'agenda'
          : a['targetDate'] is! String ||
                !validDate(a['targetDate'] as String)) ||
      a['patch'] is! Map) {
    throw const DraftFailure('Usulan perubahan AI belum valid.');
  }
  final p = a['patch'] as Map;
  if (p.length != patchKeys.length ||
      !p.keys.toSet().containsAll(patchKeys) ||
      (a['action'] == 'delete'
          ? p.values.any((v) => v != null)
          : p.values.every((v) => v == null))) {
    throw const DraftFailure('Rincian perubahan AI belum valid.');
  }
  for (final k in ['startLocal', 'deadlineLocal']) {
    parseLocalTime(p[k]);
  }
  if (p['title'] != null &&
          (p['title'] is! String ||
              (p['title'] as String).trim().isEmpty ||
              (p['title'] as String).length > 120) ||
      p['durationMinutes'] != null &&
          (p['durationMinutes'] is! int ||
              (p['durationMinutes'] as int) < 5 ||
              (p['durationMinutes'] as int) > 720) ||
      p['amountRupiah'] != null &&
          (p['amountRupiah'] is! int ||
              (p['amountRupiah'] as int) < 1 ||
              (p['amountRupiah'] as int) > 1000000000) ||
      p['status'] != null &&
          !['planned', 'completed', 'cancelled'].contains(p['status']) ||
      p['categoryId'] != null &&
          !{
            ...expenseCategories,
            ...incomeCategories,
          }.containsKey(p['categoryId']) ||
      p['localDate'] != null &&
          (p['localDate'] is! String ||
              !validDate(p['localDate'] as String) ||
              (p['localDate'] as String).compareTo(financeToday()) > 0)) {
    throw const DraftFailure('Nilai perubahan AI belum valid.');
  }
}
