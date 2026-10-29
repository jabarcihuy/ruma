import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../data/finance.dart';
import '../../data/finance_repository.dart';
import '../../data/savings_store.dart';
import '../savings/savings_page.dart';
import '../../ui/components.dart';
import 'finance_forms.dart';
import 'transaction_detail.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({
    super.key,
    required this.store,
    required this.onAssistant,
    this.savings,
    this.navigationBuilder,
  });
  final FinanceStore store;
  final VoidCallback onAssistant;
  final SavingsStore? savings;
  final Widget? Function()? navigationBuilder;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  Future<void> _form({String type = 'expense'}) async {
    final previousMonth = widget.store.month;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FinanceFormPage(store: widget.store, type: type),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.error ??
                (previousMonth == widget.store.month
                    ? 'Tersimpan di keuangan.'
                    : 'Tersimpan di ${monthLabel(context, widget.store.month)}.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final data = store.snapshot;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RumaHeading('Uangmu, lebih tertata.', null, compact: true),
          const SizedBox(height: 12),
          MonthSelector(store: store),
          const SizedBox(height: 12),
          if (store.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (store.error != null) ...[
            ErrorNotice(store.error!),
            TextButton.icon(
              onPressed: () => store.load(),
              icon: const RumaIcon('refresh-cw'),
              label: const Text('Muat ulang'),
            ),
          ] else if (data != null) ...[
            SavingsFinanceSummary(
              store: widget.savings,
              recordedBalance: data.balance,
              revision: data.revision,
            ),
            const SizedBox(height: 12),
            RumaCard(
              radius: 24,
              padding: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    children: [
                      const Text('Pemasukan'),
                      Text(
                        rupiah(data.month.income),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    children: [
                      const Text('Pengeluaran'),
                      Text(rupiah(data.month.expense)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RumaActionPair(
              first: RumaButton(
                key: const ValueKey('finance-expense'),
                label: 'Pengeluaran',
                onPressed: () => _form(),
              ),
              second: RumaButton(
                key: const ValueKey('finance-income'),
                label: 'Pemasukan',
                secondary: true,
                onPressed: () => _form(type: 'income'),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.savings != null) ...[
              RumaCard(
                padding: 0,
                radius: 24,
                child: ListTile(
                  key: const ValueKey('finance-savings'),
                  leading: const RumaIcon(
                    'shield-check',
                    color: RumaColors.accent,
                  ),
                  title: const Text('Tabungan'),
                  trailing: const RumaIcon(
                    'chevron-right',
                    color: RumaColors.accent,
                  ),
                  onTap: () {
                    widget.savings!.load();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SavingsPage(
                          store: widget.savings!,
                          navigationBuilder: widget.navigationBuilder,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            RumaCard(
              padding: 0,
              radius: 24,
              child: ListTile(
                key: const ValueKey('finance-report'),
                leading: const RumaIcon('wallet', color: RumaColors.accent),
                title: const Text('Laporan pengeluaran'),
                trailing: const RumaIcon(
                  'chevron-right',
                  color: RumaColors.accent,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FinanceRecordsPage(store: store, report: true),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            RumaCard(
              padding: 0,
              radius: 24,
              child: ListTile(
                key: const ValueKey('finance-history'),
                leading: const RumaIcon('book-open', color: RumaColors.accent),
                title: const Text('Riwayat transaksi'),
                trailing: const RumaIcon(
                  'chevron-right',
                  color: RumaColors.accent,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FinanceRecordsPage(store: store),
                  ),
                ),
              ),
            ),
            if (data.items.isEmpty) ...[
              const SizedBox(height: 20),
              SvgPicture.asset(
                'design/assets/ruma/illustrations/illustration-wallet.svg',
                width: 200,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              const Text(
                'Belum ada transaksi bulan ini.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      );
    },
  );
}

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.store});
  final FinanceStore store;
  void move(int by) {
    final d = DateTime.parse('${store.month}-01');
    final next = DateTime(d.year, d.month + by);
    final key = dateKey(next).substring(0, 7);
    if (validMonth(key)) store.load(key);
  }

  @override
  Widget build(BuildContext context) => RumaCard(
    padding: 4,
    radius: 16,
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('finance-previous'),
          tooltip: 'Bulan sebelumnya',
          onPressed: store.saving ? null : () => move(-1),
          icon: const RotatedBox(
            quarterTurns: 2,
            child: RumaIcon('chevron-right'),
          ),
        ),
        Expanded(
          child: Text(
            monthLabel(context, store.month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('finance-next'),
          tooltip: 'Bulan berikutnya',
          onPressed: store.saving ? null : () => move(1),
          icon: const RumaIcon('chevron-right'),
        ),
      ],
    ),
  );
}

class MoneyCard extends StatelessWidget {
  const MoneyCard({
    super.key,
    required this.label,
    required this.value,
    this.dark = false,
  });
  final String label;
  final int value;
  final bool dark;
  @override
  Widget build(BuildContext context) => RumaCard(
    color: dark ? RumaColors.ink : RumaColors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: dark
                ? 0
                : MediaQuery.textScalerOf(context).scale(12) * 3,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: dark ? Colors.white : RumaColors.muted),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rupiah(value),
          style:
              (dark
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.titleMedium)!
                  .copyWith(color: dark ? Colors.white : RumaColors.ink),
        ),
      ],
    ),
  );
}

class MoneyTotals extends StatelessWidget {
  const MoneyTotals({super.key, required this.month});
  final MonthFinance month;
  @override
  Widget build(BuildContext context) {
    final a = MoneyCard(label: 'Pemasukan periode', value: month.income),
        b = MoneyCard(label: 'Pengeluaran periode', value: month.expense);
    return LayoutBuilder(
      builder: (context, box) {
        final style = Theme.of(context).textTheme.titleMedium!;
        final widest = [month.income, month.expense]
            .map((value) {
              final painter = TextPainter(
                text: TextSpan(text: rupiah(value), style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            })
            .reduce((a, b) => a > b ? a : b);
        return box.maxWidth < 340 ||
                widest * 2 + 76 > box.maxWidth ||
                MediaQuery.textScalerOf(context).scale(13) > 18
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b),
                ],
              );
      },
    );
  }
}

class BudgetProgress extends StatelessWidget {
  const BudgetProgress({super.key, required this.month});
  final MonthFinance month;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        month.budget == null
            ? 'Anggaran belum ditentukan'
            : 'ANGGARAN · ${rupiah(month.budget!)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (month.remaining != null) ...[
        Text(
          month.remaining! < 0
              ? 'Melebihi batas ${rupiah(-month.remaining!)}'
              : '${rupiah(month.remaining!)} tersisa',
          style: TextStyle(
            color: month.remaining! < 0 ? RumaColors.danger : RumaColors.accent,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: month.progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: RumaColors.subtle,
          color: RumaColors.accent,
        ),
      ],
    ],
  );
}

class FinanceRecordsPage extends StatefulWidget {
  const FinanceRecordsPage({
    super.key,
    required this.store,
    this.report = false,
  });
  final FinanceStore store;
  final bool report;
  @override
  State<FinanceRecordsPage> createState() => _FinanceRecordsPageState();
}

class _FinanceRecordsPageState extends State<FinanceRecordsPage> {
  String _type = 'all', _category = 'all', _query = '';
  int _shown = 20;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final snapshot = store.snapshot;
      final m = snapshot?.month;
      final items = (snapshot?.items ?? <MoneyTransaction>[])
          .where(
            (t) =>
                (_type == 'all' || t.input.type == _type) &&
                (_category == 'all' || t.input.categoryId == _category) &&
                ('${categoryLabel(t.input.categoryId)} ${t.input.description}'
                    .toLowerCase()
                    .contains(_query.toLowerCase())),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.report ? 'Laporan bulanan' : 'Riwayat transaksi'),
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
            icon: const RumaIcon('arrow-left', color: RumaColors.accent),
          ),
        ),
        body: RumaPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RumaHeading(
                widget.report
                    ? 'Lihat pola uangmu.'
                    : 'Setiap rupiah tercatat.',
                null,
                compact: true,
              ),
              const SizedBox(height: 16),
              MonthSelector(store: store),
              const SizedBox(height: 16),
              if (store.loading)
                const Center(child: CircularProgressIndicator())
              else if (store.error != null) ...[
                ErrorNotice(store.error!),
                TextButton(
                  onPressed: () => store.load(),
                  child: const Text('Muat ulang'),
                ),
              ] else if (m != null) ...[
                if (widget.report) ...[
                  MoneyCard(
                    label: 'ARUS KAS PERIODE INI',
                    value: m.income - m.expense,
                    dark: true,
                  ),
                  const SizedBox(height: 12),

                  MoneyTotals(month: m),
                  const SizedBox(height: 20),
                  Text(
                    'Pengeluaran per kategori',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (m.expense == 0)
                    const RumaCard(
                      child: Text('Belum ada pengeluaran bulan ini.'),
                    ),
                  for (final e in expenseCategories.entries.where(
                    (e) => (m.categoryExpense[e.key] ?? 0) > 0,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RumaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(e.value),
                            const SizedBox(height: 6),
                            Text(
                              rupiah(m.categoryExpense[e.key] ?? 0),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m.expense == 0
                                  ? 'Belum ada pengeluaran'
                                  : '${((m.categoryExpense[e.key] ?? 0) * 100 / m.expense).round()}% dari total',
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: m.expense == 0
                                  ? 0
                                  : (m.categoryExpense[e.key] ?? 0) / m.expense,
                              minHeight: 6,
                              color: RumaColors.accent,
                              backgroundColor: RumaColors.subtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  TextField(
                    key: const ValueKey('finance-search'),
                    decoration: const InputDecoration(
                      labelText: 'Cari kategori atau catatan',
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(14),
                        child: RumaIcon('search', size: 20),
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      _query = v;
                      _shown = 20;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Jenis'),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua jenis'),
                      ),
                      DropdownMenuItem(
                        value: 'income',
                        child: Text('Pemasukan'),
                      ),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('Pengeluaran'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _type = v ?? 'all';
                      _shown = 20;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua kategori'),
                      ),
                      for (final e in {
                        ...expenseCategories,
                        ...incomeCategories,
                      }.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() {
                      _category = v ?? 'all';
                      _shown = 20;
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Text(
                      'Tidak ada transaksi yang cocok pada bulan ini.',
                    ),
                  for (final t in items.take(_shown))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RumaCard(
                        padding: 0,
                        child: ListTile(
                          key: ValueKey('transaction-${t.id}'),
                          leading: RumaIcon(
                            t.input.type == 'income'
                                ? 'wallet'
                                : switch (t.input.categoryId) {
                                    'food' => 'utensils',
                                    'transport' => 'bus-front',
                                    'housing' => 'house',
                                    _ => 'wallet',
                                  },
                            color: RumaColors.accent,
                          ),
                          title: Text(categoryLabel(t.input.categoryId)),
                          subtitle: Text(
                            '${t.input.localDate}\n${t.input.type == 'income' ? '+' : '−'}${rupiah(t.input.amountRupiah)}',
                          ),
                          isThreeLine: true,
                          trailing: const RumaIcon('chevron-right'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailPage(store: store, id: t.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (items.length > _shown)
                    RumaButton(
                      label: 'Tampilkan lagi',
                      secondary: true,
                      onPressed: () => setState(() => _shown += 20),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

class SavingsFinanceSummary extends StatelessWidget {
  const SavingsFinanceSummary({
    super.key,
    this.store,
    required this.recordedBalance,
    required this.revision,
  });
  final SavingsStore? store;
  final int recordedBalance, revision;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store ?? const AlwaysStoppedAnimation(0),
    builder: (context, _) {
      final data = store?.snapshot;
      return RumaCard(
        color: RumaColors.sage,
        radius: 24,
        padding: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saldo tercatat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              rupiah(recordedBalance),
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 30, height: 44 / 30),
            ),
            const SizedBox(height: 10),
            if (data != null &&
                store?.loading == false &&
                store?.error == null &&
                data.revision == revision)
              Text(
                'Tersedia ${rupiah(data.availableRupiah)} · Tabungan ${rupiah(data.totalSavedRupiah)}',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Text(
                store?.loading == true
                    ? 'Memuat tabungan…'
                    : 'Tabungan belum termuat.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (store?.error != null)
                TextButton(
                  onPressed: () => store!.load(),
                  child: const Text('Muat ulang'),
                ),
            ],
          ],
        ),
      );
    },
  );
}
