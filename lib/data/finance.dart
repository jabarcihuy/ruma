import 'dart:convert';

import 'agenda.dart';

const expenseCategories = {
  'food': 'Makan',
  'transport': 'Transport',
  'housing': 'Kebutuhan kos',
  'other': 'Lainnya',
};
const incomeCategories = {
  'allowance': 'Uang saku',
  'work': 'Kerja',
  'other_income': 'Pemasukan lain',
};
String categoryLabel(String id) =>
    expenseCategories[id] ?? incomeCategories[id] ?? id;
String financeToday() => dateKey(agendaLocal(DateTime.now().toUtc()));
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
bool validDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final d = DateTime.tryParse(value);
  return d != null && dateKey(d) == value && d.year >= 2000 && d.year <= 2100;
}

bool validMonth(String value) =>
    RegExp(r'^(20\d{2}|2100)-(0[1-9]|1[0-2])$').hasMatch(value);
// Accept Indonesian whole rupiah only. Never turn "1,5" into Rp15.
int? parseRupiah(String value) {
  final text = value.trim().replaceFirst(
    RegExp(r'^Rp\s*', caseSensitive: false),
    '',
  );
  if (!RegExp(r'^(\d+|\d{1,3}(\.\d{3})+)$').hasMatch(text)) return null;
  return int.tryParse(text.replaceAll('.', ''));
}

String rupiah(int value) {
  final text = value.abs().toString();
  return '${value < 0 ? '-' : ''}Rp${text.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

class FinanceFailure implements Exception {
  const FinanceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.amountRupiah,
    required this.categoryId,
    required this.localDate,
    this.description = '',
  });
  final String type, categoryId, localDate, description;
  final int amountRupiah;
  String get monthKey => localDate.substring(0, 7);
  String? validate({String? today}) {
    if (amountRupiah < 1 || amountRupiah > 1000000000) {
      return 'Isi nominal Rp1 sampai Rp1.000.000.000.';
    }
    if (!(type == 'income'
            ? incomeCategories
            : type == 'expense'
            ? expenseCategories
            : {})
        .containsKey(categoryId)) {
      return 'Pilih kategori sesuai jenis transaksi.';
    }
    if (!validDate(localDate) ||
        localDate.compareTo(today ?? financeToday()) > 0) {
      return 'Pilih tanggal yang valid, paling lambat hari ini (WIB).';
    }
    if (description.length > 1000) return 'Catatan maksimal 1.000 karakter.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'amountRupiah': amountRupiah,
    'categoryId': categoryId,
    'localDate': localDate,
    'description': description,
  };
  int get income => type == 'income' ? amountRupiah : 0;
  int get expense => type == 'expense' ? amountRupiah : 0;
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.version,
    required this.input,
  });
  final String id;
  final int version;
  final TransactionInput input;
}

class MonthFinance {
  const MonthFinance({
    required this.key,
    this.version = 0,
    this.income = 0,
    this.expense = 0,
    this.categoryExpense = const {},
    this.budget,
    this.categoryBudget = const {},
  });
  final String key;
  final int version, income, expense;
  final Map<String, int> categoryExpense;
  final int? budget;
  final Map<String, int?> categoryBudget;
  int? get remaining => budget == null ? null : budget! - expense;
  double get progress => budget == null
      ? 0
      : budget == 0
      ? (expense > 0 ? 1 : 0)
      : (expense / budget!).clamp(0, 1).toDouble();
}

class BudgetInput {
  BudgetInput({
    required this.monthKey,
    required this.total,
    Map<String, int?> categories = const {},
  }) : categories = {for (final k in expenseCategories.keys) k: categories[k]};
  final String monthKey;
  final int? total;
  final Map<String, int?> categories;
  String? validate() {
    if (!validMonth(monthKey)) return 'Periode anggaran tidak valid.';
    if (total != null && (total! < 0 || total! > 1000000000)) {
      return 'Batas anggaran Rp0 sampai Rp1.000.000.000.';
    }
    if (categories.values.any((v) => v != null && (v < 0 || v > 1000000000))) {
      return 'Batas kategori tidak valid.';
    }
    if (total == null
        ? categories.values.any((v) => v != null)
        : categories.values.fold<int>(0, (a, b) => a + (b ?? 0)) > total!) {
      return 'Jumlah batas kategori tidak boleh melebihi total anggaran.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'monthKey': monthKey,
    'total': total,
    'categories': categories,
  };
}

class FinanceMutation {
  const FinanceMutation({
    required this.operationId,
    required this.id,
    this.input,
    this.budget,
    this.originalVersion,
    this.delete = false,
    this.restore = false,
  });
  final String operationId, id;
  final TransactionInput? input;
  final BudgetInput? budget;
  final int? originalVersion;
  final bool delete, restore;
  String get kind => budget != null
      ? 'budget_set'
      : delete
      ? 'transaction_delete'
      : originalVersion == null
      ? 'transaction_create'
      : 'transaction_update';
  String get requestKey => jsonEncode({
    'id': id,
    'version': originalVersion,
    'delete': delete,
    if (restore) 'restore': true,
    'input': input?.toJson(),
    'budget': budget?.toJson(),
  });
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.month,
    required this.items,
    required this.balance,
    required this.revision,
  });
  final MonthFinance month;
  final List<MoneyTransaction> items;
  final int balance, revision;
}
