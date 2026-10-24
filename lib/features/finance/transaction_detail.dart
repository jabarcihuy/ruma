import 'package:flutter/material.dart';

import '../../data/finance.dart';
import '../../data/finance_repository.dart';
import '../../ui/components.dart';
import '../../app/theme.dart';
import 'finance_forms.dart';

class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.store,
    required this.id,
  });
  final FinanceStore store;
  final String id;
  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  FinanceMutation? _pending;
  Future<void> _delete(MoneyTransaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => RumaDialog(
        title: const Text('Hapus transaksi ini?'),
        content: const Text(
          'Saldo dan laporan akan disesuaikan dengan catatan yang tersisa.',
        ),
        actions: [
          RumaButton(
            label: 'Batalkan',
            secondary: true,
            onPressed: () => Navigator.pop(c, false),
          ),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Hapus transaksi',
            destructive: true,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final candidate = FinanceMutation(
      operationId: _pending?.operationId ?? widget.store.repository.newId(),
      id: t.id,
      input: t.input,
      originalVersion: t.version,
      delete: true,
    );
    _pending = _pending?.requestKey == candidate.requestKey
        ? candidate
        : FinanceMutation(
            operationId: widget.store.repository.newId(),
            id: t.id,
            input: t.input,
            originalVersion: t.version,
            delete: true,
          );
    final ok = await widget.store.save(_pending!);
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transaksi dihapus.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final item = widget.store.snapshot?.items
          .where((t) => t.id == widget.id)
          .firstOrNull;
      return PopScope(
        canPop: !widget.store.saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Detail transaksi'),
            leading: IconButton(
              tooltip: 'Kembali',
              onPressed: widget.store.saving
                  ? null
                  : () => Navigator.pop(context),
              icon: const RumaIcon('arrow-left', color: RumaColors.accent),
            ),
          ),
          body: RumaPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item == null)
                  const ErrorNotice(
                    'Catatan tidak tersedia pada periode ini. Kembali ke riwayat untuk memuat ulang.',
                  )
                else ...[
                  RumaHeading(
                    categoryLabel(item.input.categoryId),
                    item.input.type == 'income'
                        ? 'Pemasukan tercatat'
                        : 'Pengeluaran tercatat',
                    compact: true,
                  ),
                  const SizedBox(height: 20),
                  RumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rupiah(item.input.amountRupiah),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(item.input.localDate),
                        if (item.input.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(item.input.description),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  RumaCard(
                    padding: 0,
                    child: ListTile(
                      key: const ValueKey('transaction-edit'),
                      leading: const RumaIcon(
                        'settings-2',
                        color: RumaColors.accent,
                      ),
                      title: const Text('Edit transaksi'),
                      trailing: const RumaIcon('chevron-right'),
                      onTap: widget.store.saving
                          ? null
                          : () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FinanceFormPage(
                                    store: widget.store,
                                    existing: item,
                                  ),
                                ),
                              );
                              if (ok == true && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  RumaCard(
                    padding: 0,
                    child: ListTile(
                      key: const ValueKey('transaction-delete'),
                      leading: const RumaIcon(
                        'circle-alert',
                        color: RumaColors.accent,
                      ),
                      title: const Text('Hapus transaksi'),
                      trailing: const RumaIcon(
                        'chevron-right',
                        color: RumaColors.accent,
                      ),
                      onTap: widget.store.saving ? null : () => _delete(item),
                    ),
                  ),
                  if (widget.store.saving)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                ],
                if (widget.store.error != null) ...[
                  const SizedBox(height: 12),
                  ErrorNotice(widget.store.error!),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
