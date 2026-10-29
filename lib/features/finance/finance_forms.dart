import 'package:flutter/material.dart';

import '../../data/finance.dart';
import '../../data/finance_repository.dart';
import '../../app/theme.dart';
import '../../ui/components.dart';

String monthLabel(BuildContext context, String key) =>
    MaterialLocalizations.of(context)
        .formatMonthYear(DateTime.parse('$key-01'));

class FinanceFormPage extends StatefulWidget {
  const FinanceFormPage({
    super.key,
    required this.store,
    this.existing,
    this.onDraftChanged,
    this.type = 'expense',
    this.budget = false,
  });
  final FinanceStore store;
  final MoneyTransaction? existing;
  final String type;
  final bool budget;
  final ValueChanged<TransactionInput>? onDraftChanged;
  @override
  State<FinanceFormPage> createState() => _FinanceFormPageState();
}

class _FinanceFormPageState extends State<FinanceFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount, _description;
  final _categories = <String, TextEditingController>{};
  late final String _id, _month;
  int? _version;
  late String _type, _category, _date;
  bool _dirty = false, _leaving = false;
  String? _error;
  FinanceMutation? _pending;
  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    final month = widget.store.snapshot?.month;
    _month = widget.store.month;
    _id = widget.budget ? _month : item?.id ?? widget.store.repository.newId();
    _version = widget.budget
        ? (month?.version == 0 ? null : month?.version)
        : item?.version;
    _type = item?.input.type ?? widget.type;
    _category =
        item?.input.categoryId ?? (_type == 'income' ? 'allowance' : 'food');
    _date = item?.input.localDate ?? financeToday();
    _amount = TextEditingController(
      text: widget.budget
          ? month?.budget?.toString() ?? ''
          : item?.input.amountRupiah.toString() ?? '',
    );
    _description = TextEditingController(text: item?.input.description ?? '');
    for (final k in expenseCategories.keys) {
      _categories[k] = TextEditingController(
        text: month?.categoryBudget[k]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    for (final c in _categories.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {
      _dirty = true;
      _error = null;
    });
  }

  Future<void> _back() async {
    if (widget.store.saving) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => RumaDialog(
          title: const Text('Tinggalkan isian ini?'),
          content: const Text('Perubahan belum disimpan.'),
          actions: [
            RumaButton(
              label: 'Lanjut mengedit',
              secondary: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            const SizedBox(height: 8),
            RumaButton(
              label: 'Buang perubahan',
              destructive: true,
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final budget = widget.budget
        ? BudgetInput(
            monthKey: _month,
            total: _amount.text.trim().isEmpty
                ? null
                : parseRupiah(_amount.text),
            categories: {
              for (final e in _categories.entries)
                e.key: e.value.text.trim().isEmpty
                    ? null
                    : parseRupiah(e.value.text),
            },
          )
        : null;
    final input = widget.budget
        ? null
        : TransactionInput(
            type: _type,
            amountRupiah: parseRupiah(_amount.text)!,
            categoryId: _category,
            localDate: _date,
            description: _description.text,
          );
    final error = budget?.validate() ?? input?.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (widget.onDraftChanged != null) {
      widget.onDraftChanged!(input!);
      setState(() => _leaving = true);
      Navigator.pop(context, true);
      return;
    }
    var m = FinanceMutation(
      operationId: _pending?.operationId ?? widget.store.repository.newId(),
      id: _id,
      budget: budget,
      input: input,
      originalVersion: _version,
    );
    if (_pending != null && m.requestKey != _pending!.requestKey) {
      m = FinanceMutation(
        operationId: widget.store.repository.newId(),
        id: _id,
        budget: budget,
        input: input,
        originalVersion: _version,
      );
    }
    _pending = m;
    final ok = await widget.store.save(m);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = widget.store.error);
      return;
    }
    setState(() => _leaving = true);
    Navigator.pop(context, true);
  }

  Widget _moneyField(
    String label,
    TextEditingController controller,
    String key, {
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: optional ? 'Belum ditentukan' : 'Contoh: 22.000',
      ),
      keyboardType: TextInputType.number,
      validator: (v) {
        if (optional && (v ?? '').trim().isEmpty) return null;
        final n = parseRupiah(v ?? '');
        return n == null || n < (widget.budget ? 0 : 1) || n > 1000000000
            ? 'Isi rupiah bulat yang valid, maksimal 1 miliar.'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final busy = widget.store.saving;
      return PopScope(
        canPop: _leaving || (!_dirty && !busy),
        onPopInvokedWithResult: (p, _) {
          if (!p) _back();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Keuangan'),
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: busy ? null : _back,
              icon: const RumaIcon('arrow-left', color: RumaColors.accent),
            ),
          ),
          body: RumaPageBody(
            child: AbsorbPointer(
              absorbing: busy,
              child: Form(
                key: _form,
                onChanged: _changed,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RumaHeading(
                      widget.budget
                          ? 'Atur batas bulanan.'
                          : widget.existing != null
                          ? 'Edit transaksi.'
                          : _type == 'income'
                          ? 'Catat pemasukan.'
                          : 'Catat pengeluaran.',
                      widget.budget
                          ? 'Batas belanja bulanan.'
                          : 'Untuk transaksi yang sudah terjadi.',
                      compact: true,
                    ),
                    const SizedBox(height: 20),
                    if (widget.budget) ...[
                      RumaCard(child: Text(monthLabel(context, _month))),
                      const SizedBox(height: 16),
                      _moneyField(
                        'Total anggaran belanja (Rp)',
                        _amount,
                        'budget-total',
                        optional: true,
                      ),
                      for (final e in expenseCategories.entries)
                        _moneyField(
                          'Anggaran ${e.value} (Rp)',
                          _categories[e.key]!,
                          'budget-${e.key}',
                          optional: true,
                        ),
                      const Text(
                        'Batas boleh dikosongkan. Kosongkan semua untuk melepas anggaran.',
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey('transaction-type-$_type'),
                        initialValue: _type,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Jenis transaksi',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Pengeluaran'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Pemasukan'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _type = v;
                              _category = v == 'income' ? 'allowance' : 'food';
                            });
                            _changed();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _moneyField(
                        'Nominal (Rp) *',
                        _amount,
                        'transaction-amount',
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('transaction-category-$_type'),
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Kategori *',
                        ),
                        items:
                            (_type == 'income'
                                    ? incomeCategories
                                    : expenseCategories)
                                .entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _category = v);
                            _changed();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      RumaCard(
                        padding: 0,
                        child: ListTile(
                          key: const ValueKey('transaction-date'),
                          title: const Text('Tanggal transaksi'),
                          subtitle: Text(
                            '${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(_date))} · WIB',
                          ),
                          trailing: const RumaIcon('calendar-days'),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.parse(_date),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.parse(financeToday()),
                            );
                            if (picked != null && mounted) {
                              setState(() => _date = dateKey(picked));
                              _changed();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      RumaCard(
                        padding: 0,
                        child: ExpansionTile(
                          title: const Text('Opsi lainnya'),
                          childrenPadding: const EdgeInsets.all(16),
                          children: [
                            TextFormField(
                              key: const ValueKey('transaction-description'),
                              controller: _description,
                              maxLines: 3,
                              maxLength: 1000,
                              decoration: const InputDecoration(
                                labelText: 'Catatan (opsional)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorNotice(_error!),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: RumaButton(
                        key: const ValueKey('finance-save'),
                        label: widget.onDraftChanged != null
                            ? 'Gunakan dalam draf'
                            : widget.budget
                            ? 'Simpan anggaran'
                            : 'Simpan transaksi',
                        busy: busy,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
