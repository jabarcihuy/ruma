import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/finance.dart';
import '../../data/savings.dart';
import '../../data/savings_store.dart';
import '../../ui/components.dart';
import 'savings_form.dart';

Future<void> openSavingsForm(
  BuildContext context,
  SavingsStore store, {
  SavingsGoal? goal,
  String? movement,
}) async {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          SavingsFormPage(store: store, goal: goal, movement: movement),
    ),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          store.error ??
              (movement == null
                  ? 'Tujuan tabungan tersimpan.'
                  : 'Catatan tabungan tersimpan.'),
        ),
      ),
    );
  }
}

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key, required this.store, this.navigationBuilder});
  final SavingsStore store;
  final Widget? Function()? navigationBuilder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final data = store.snapshot;
      final goals = [...?data?.goals]
        ..sort((a, b) {
          if (a.complete != b.complete) return a.complete ? 1 : -1;
          final name = a.input.name.toLowerCase().compareTo(
            b.input.name.toLowerCase(),
          );
          return name != 0 ? name : a.id.compareTo(b.id);
        });
      return Scaffold(
        appBar: savingsAppBar(context),
        bottomNavigationBar: navigationBuilder?.call(),
        body: RumaPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RumaHeading(
                'Sedikit demi sedikit.',
                data == null ? null : '${data.goals.length} tujuan tabungan',
                compact: true,
              ),
              const SizedBox(height: 16),
              if (store.loading)
                const Center(child: CircularProgressIndicator())
              else if (store.error != null || data == null)
                SavingsRetry(store: store)
              else ...[
                RumaCard(
                  color: RumaColors.sage,
                  radius: 24,
                  padding: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Total tabungan',
                        style: TextStyle(fontSize: 12, color: RumaColors.muted),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        rupiah(data.totalSavedRupiah),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tersedia untuk dipakai ${rupiah(data.availableRupiah)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (data.goals.isEmpty) ...[
                  const RumaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum ada tujuan.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text('Simpan untuk wishlist atau kebutuhanmu.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final goal in goals) ...[
                  SavingsGoalCard(
                    goal: goal,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SavingsDetailPage(
                          store: store,
                          goalId: goal.id,
                          navigationBuilder: navigationBuilder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                RumaButton(
                  key: const ValueKey('savings-add'),
                  label: 'Tambah tujuan',
                  onPressed: store.saving
                      ? null
                      : () => openSavingsForm(context, store),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class SavingsDetailPage extends StatefulWidget {
  const SavingsDetailPage({
    super.key,
    required this.store,
    required this.goalId,
    this.navigationBuilder,
  });
  final SavingsStore store;
  final String goalId;
  final Widget? Function()? navigationBuilder;
  @override
  State<SavingsDetailPage> createState() => _SavingsDetailPageState();
}

class _SavingsDetailPageState extends State<SavingsDetailPage> {
  int _shown = 20;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final goal = store.snapshot?.goals
          .where((g) => g.id == widget.goalId)
          .firstOrNull;
      final history =
          store.snapshot?.movements
              .where((m) => m.goalId == widget.goalId)
              .toList() ??
          [];
      return Scaffold(
        appBar: savingsAppBar(context),
        bottomNavigationBar: widget.navigationBuilder?.call(),
        body: RumaPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (store.loading)
                const Center(child: CircularProgressIndicator())
              else if (store.error != null || store.snapshot == null)
                SavingsRetry(store: store)
              else if (goal == null)
                const ErrorNotice(
                  'Tujuan tidak ditemukan. Kembali ke daftar tabungan.',
                )
              else ...[
                RumaHeading(
                  goal.input.name,
                  goal.input.targetDate == null
                      ? null
                      : 'Target · ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(goal.input.targetDate!))}',
                  compact: true,
                ),
                const SizedBox(height: 16),
                SavingsGoalCard(goal: goal, title: 'Progres tabungan'),
                const SizedBox(height: 12),
                RumaActionPair(
                  first: RumaButton(
                    key: const ValueKey('savings-deposit'),
                    label: 'Tambah tabungan',
                    onPressed: store.saving
                        ? null
                        : () => openSavingsForm(
                            context,
                            store,
                            goal: goal,
                            movement: 'deposit',
                          ),
                  ),
                  second: RumaButton(
                    key: const ValueKey('savings-withdrawal'),
                    label: 'Tarik',
                    secondary: true,
                    onPressed: store.saving || goal.balanceRupiah == 0
                        ? null
                        : () => openSavingsForm(
                            context,
                            store,
                            goal: goal,
                            movement: 'withdrawal',
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                RumaCard(
                  padding: 0,
                  radius: 24,
                  child: ListTile(
                    key: const ValueKey('savings-edit'),
                    leading: const RumaIcon('wallet', color: RumaColors.accent),
                    title: const Text('Edit tujuan'),
                    trailing: const RumaIcon(
                      'chevron-right',
                      color: RumaColors.accent,
                    ),
                    onTap: store.saving
                        ? null
                        : () => openSavingsForm(context, store, goal: goal),
                  ),
                ),
                const SizedBox(height: 12),
                RumaCard(
                  radius: 24,
                  padding: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Riwayat tabungan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text('Belum ada setoran atau penarikan.'),
                        ),
                      for (final m in history.take(_shown))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.input.type == 'deposit' ? 'Setoran' : 'Penarikan'} · ${m.input.localDate}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${m.input.type == 'deposit' ? '+' : '−'}${rupiah(m.input.amountRupiah)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (m.input.description.isNotEmpty)
                                Text(m.input.description),
                            ],
                          ),
                        ),
                      if (history.length > _shown)
                        TextButton(
                          onPressed: () => setState(() => _shown += 20),
                          child: const Text('Tampilkan lagi'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Perpindahan dana, bukan pengeluaran.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

AppBar savingsAppBar(BuildContext context) => AppBar(
  title: const Text('Tabungan'),
  leading: IconButton(
    tooltip: 'Kembali',
    onPressed: () => Navigator.pop(context),
    icon: const RumaIcon('arrow-left', color: RumaColors.accent),
  ),
);

class SavingsGoalCard extends StatelessWidget {
  const SavingsGoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.title,
  });
  final SavingsGoal goal;
  final VoidCallback? onTap;
  final String? title;
  @override
  Widget build(BuildContext context) => RumaCard(
    radius: 24,
    padding: 0,
    child: InkWell(
      key: ValueKey('savings-goal-${goal.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RumaColors.sage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Semantics(
                      label: SavingsGoalInput.iconLabels[goal.input.icon],
                      child: RumaIcon(goal.input.icon, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title ?? goal.input.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${rupiah(goal.balanceRupiah)} dari ${rupiah(goal.input.targetRupiah)}',
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Progres tabungan',
              value: '${(goal.progress * 100).round()}%',
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: RumaColors.accent,
                backgroundColor: RumaColors.subtle,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (goal.complete) ...[
                  const RumaIcon('check', size: 18),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    goal.complete
                        ? 'Target tercapai'
                        : '${(goal.progress * 100).round()}% terkumpul · kurang ${rupiah(goal.remainingRupiah)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: goal.complete ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SavingsRetry extends StatelessWidget {
  const SavingsRetry({super.key, required this.store});
  final SavingsStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ErrorNotice(store.error ?? 'Tabungan belum termuat.'),
      TextButton.icon(
        onPressed: () => store.load(),
        icon: const RumaIcon('refresh-cw'),
        label: const Text('Muat ulang'),
      ),
    ],
  );
}
