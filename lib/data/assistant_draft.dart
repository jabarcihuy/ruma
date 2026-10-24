import 'dart:convert';

import 'agenda.dart';
import 'agent_tools.dart';
import 'finance.dart';

class DraftFailure implements Exception {
  const DraftFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DraftEntry {
  DraftEntry({
    required this.id,
    required this.quote,
    this.agenda,
    this.money,
    required this.localDate,
    this.included = true,
    this.suggestedTime = false,
  });
  final String id, quote;
  AgendaInput? agenda;
  TransactionInput? money;
  String localDate;
  bool included, suggestedTime;
  Map<String, dynamic> toJson() => {
    'id': id,
    'agenda': agenda?.toJson(),
    'money': money?.toJson(),
    'localDate': localDate,
  };
}

class AssistantDraft {
  AssistantDraft({
    required this.id,
    required this.operationId,
    required this.uid,
    required this.items,
    required this.baseAgendaRevision,
    required this.baseFinanceRevision,
  });
  final String id, uid;
  String operationId;
  final List<DraftEntry> items;
  final int baseAgendaRevision, baseFinanceRevision;
  int revision = 1;
  bool applied = false, attempted = false;
  Iterable<DraftEntry> get included => items.where((i) => i.included);
  String get requestKey => jsonEncode({
    'id': id,
    'revision': revision,
    'agendaRevision': baseAgendaRevision,
    'financeRevision': baseFinanceRevision,
    'items': included.map((i) => i.toJson()).toList(),
  });
  void changed(String nextOperationId) {
    if (applied || attempted) {
      throw const DraftFailure(
        'Selesaikan pengecekan simpan sebelumnya sebelum mengubah draf.',
      );
    }
    revision++;
    operationId = nextOperationId;
  }

  String? validate() {
    if (included.isEmpty) return 'Pilih minimal satu item untuk disimpan.';
    if (included.where((i) => i.agenda != null).length > 3 ||
        included.where((i) => i.money != null).length > 3) {
      return 'Maksimal tiga agenda dan tiga transaksi per draf.';
    }
    for (final item in included) {
      if ((item.agenda == null) == (item.money == null)) {
        return 'Jenis item draf tidak valid.';
      }
      final error = item.agenda?.validate() ?? item.money?.validate();
      if (error != null) return error;
      if (item.agenda != null && !validDate(item.localDate)) {
        return 'Tanggal kegiatan belum valid.';
      }
    }
    return null;
  }
}

List<DraftEntry> parseProposal(
  Object? value,
  String source,
  String Function() newId,
) {
  if (value is! List || value.isEmpty || value.length > 6) {
    throw const DraftFailure(
      'Draf AI belum valid. Tidak ada data yang disimpan.',
    );
  }
  final result = <DraftEntry>[];
  const keys = {
    'action',
    'title',
    'localDate',
    'durationMinutes',
    'amountRupiah',
    'transactionType',
    'categoryId',
    'transactionStatus',
    'sourceQuote',
  };
  for (final raw in value) {
    if (raw is! Map ||
        (raw.length != keys.length && raw.length > keys.length + 2) ||
        raw.keys.any(
          (k) => !keys.contains(k) && k != 'startLocal' && k != 'deadlineLocal',
        ) ||
        !raw.keys.toSet().containsAll(keys) ||
        raw['title'] is! String ||
        raw['sourceQuote'] is! String ||
        raw['localDate'] is! String) {
      throw const DraftFailure('Format draf AI tidak didukung.');
    }
    final title = (raw['title'] as String).trim(),
        quote = raw['sourceQuote'] as String,
        date = raw['localDate'] as String;
    if (title.isEmpty ||
        title.length > 120 ||
        quote.trim().isEmpty ||
        !source.contains(quote) ||
        !validDate(date)) {
      throw const DraftFailure(
        'Rujukan atau tanggal draf belum dapat diverifikasi.',
      );
    }
    if (raw['action'] == 'create_agenda') {
      if (raw['durationMinutes'] is! int ||
          [
            'amountRupiah',
            'transactionType',
            'categoryId',
            'transactionStatus',
          ].any((k) => raw[k] != null)) {
        throw const DraftFailure('Rincian kegiatan belum valid.');
      }
      final input = AgendaInput(
        title: title,
        startAtUtc: parseLocalTime(raw['startLocal']),
        deadlineAtUtc: parseLocalTime(raw['deadlineLocal']),
        durationMinutes: raw['durationMinutes'] as int,
      );
      if (input.validate() != null) throw DraftFailure(input.validate()!);
      if (input.startAtUtc != null &&
          dateKey(agendaLocal(input.startAtUtc!)) != date) {
        throw const DraftFailure('Tanggal dan jam kegiatan tidak cocok.');
      }
      result.add(
        DraftEntry(id: newId(), quote: quote, localDate: date, agenda: input),
      );
    } else if (raw['action'] == 'create_transaction') {
      if (raw['amountRupiah'] is! int ||
          raw['durationMinutes'] != null ||
          raw['startLocal'] != null ||
          raw['deadlineLocal'] != null ||
          raw['transactionStatus'] != 'actual' ||
          raw['transactionType'] is! String ||
          raw['categoryId'] is! String ||
          RegExp(
            r'\b(besok|lusa|akan|mau|rencana|nanti)\b',
            caseSensitive: false,
          ).hasMatch(quote)) {
        throw const DraftFailure(
          'Status uang belum jelas sudah terjadi. Perjelas pesan sebelum membuat transaksi.',
        );
      }
      final input = TransactionInput(
        type: raw['transactionType'] as String,
        amountRupiah: raw['amountRupiah'] as int,
        categoryId: raw['categoryId'] as String,
        localDate: date,
        description: title,
      );
      if (input.validate() != null) throw DraftFailure(input.validate()!);
      result.add(
        DraftEntry(id: newId(), quote: quote, localDate: date, money: input),
      );
    } else {
      throw const DraftFailure('Tindakan AI ini belum didukung.');
    }
  }
  if (result.where((i) => i.agenda != null).length > 3 ||
      result.where((i) => i.money != null).length > 3) {
    throw const DraftFailure(
      'Satu draf maksimal tiga agenda dan tiga transaksi.',
    );
  }
  return result;
}
