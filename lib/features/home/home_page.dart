import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/auth_session.dart';
import '../../data/agenda.dart';
import '../../data/agenda_repository.dart';
import '../../data/finance_repository.dart';
import '../../data/savings_store.dart';
import '../../data/finance.dart';
import '../../ui/components.dart';
import '../agenda/agenda_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.account,
    required this.onTab,
    this.agenda,
    this.finance,
    this.savings,
    this.now,
  });
  final RumaAccount account;
  final ValueChanged<int> onTab;
  final AgendaStore? agenda;
  final FinanceStore? finance;
  final SavingsStore? savings;
  // A fixed instant makes deadline/month-boundary checks reproducible.
  final DateTime? now;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _clock;
  late DateTime _now;
  String get _month => dateKey(agendaLocal(_now)).substring(0, 7);
  @override
  void initState() {
    super.initState();
    _now = widget.now?.toUtc() ?? DateTime.now().toUtc();
    WidgetsBinding.instance.addObserver(this);
    // Reuse the finance store; returning Home resets its period to this month.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureMonth());
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now().toUtc());
        _ensureMonth();
      });
    }
  }

  void _ensureMonth() {
    if (mounted && widget.finance != null && widget.finance!.month != _month) {
      unawaited(widget.finance!.load(_month));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.now == null) {
      setState(() => _now = DateTime.now().toUtc());
      _reload();
    }
  }

  void _reload() {
    unawaited(widget.agenda?.load());
    unawaited(widget.finance?.load(_month));
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _date(DateTime utc) {
    final d = agendaLocal(utc), today = agendaDay(agendaLocal(_now));
    final days = agendaDay(d).difference(today).inDays;
    final label = switch (days) {
      0 => 'Hari ini',
      1 => 'Besok',
      -1 => 'Kemarin',
      _ => MaterialLocalizations.of(context).formatMediumDate(d),
    };
    return '$label · ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
  }

  void _detail(AgendaItem item) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AgendaDetailPage(store: widget.agenda!, id: item.id),
    ),
  );

  Widget _time() {
    final s = widget.agenda;
    final planned =
        s?.items.where((a) => a.input.status == 'planned').toList() ?? [];
    final today = agendaDay(agendaLocal(_now));
    final next =
        planned.where((a) => a.input.endAtUtc?.isAfter(_now) == true).toList()
          ..sort((a, b) => a.input.startAtUtc!.compareTo(b.input.startAtUtc!));
    final due =
        planned
            .where(
              (a) => a.input.kind == 'task' && a.input.deadlineAtUtc != null,
            )
            .toList()
          ..sort(
            (a, b) => a.input.deadlineAtUtc!.compareTo(b.input.deadlineAtUtc!),
          );
    final upcoming = next.firstOrNull, deadline = due.firstOrNull;
    final ready = s?.loaded == true && s?.loading == false && s?.error == null;
    return _SummaryCard(
      title: 'Waktu hari ini',
      icon: 'calendar-days',
      color: RumaColors.peach,
      action: 'Lihat agenda',
      onTap: () => widget.onTab(1),
      child: !ready
          ? _status(
              s == null
                  ? 'Tambahkan kegiatan pertamamu.'
                  : s.error != null
                  ? 'Agenda belum termuat.'
                  : 'Memuat agenda…',
              retry: s?.error != null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _primary(
                  '${planned.where((a) => a.occursOn(today)).length} kegiatan',
                  '${planned.where((a) => a.input.startAtUtc == null).length} belum dijadwalkan',
                ),
                const SizedBox(height: 16),
                RumaActionPair(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  first: _Fact(
                    label:
                        upcoming != null &&
                            !upcoming.input.startAtUtc!.isAfter(_now)
                        ? 'Sedang berlangsung'
                        : 'Berikutnya',
                    value: upcoming?.input.title ?? 'Belum ada jadwal',
                    detail: upcoming == null
                        ? null
                        : _date(upcoming.input.startAtUtc!),
                    onTap: upcoming == null ? null : () => _detail(upcoming),
                  ),
                  second: _Fact(
                    label:
                        deadline != null &&
                            deadline.input.deadlineAtUtc!.isBefore(_now)
                        ? 'Deadline terlewat'
                        : 'Deadline terdekat',
                    value: deadline?.input.title ?? 'Tidak ada deadline',
                    detail: deadline == null
                        ? null
                        : _date(deadline.input.deadlineAtUtc!),
                    warning:
                        deadline?.input.deadlineAtUtc?.isBefore(_now) == true,
                    onTap: deadline == null ? null : () => _detail(deadline),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _money() {
    final s = widget.finance, data = s?.snapshot;
    final ready =
        s != null && !s.loading && s.error == null && data?.month.key == _month;
    final savings = widget.savings;
    final saved = savings?.snapshot;
    final savingsReady =
        savings != null &&
        !savings.loading &&
        savings.error == null &&
        saved != null &&
        saved.revision == data?.revision;
    return _SummaryCard(
      title: 'Uang bulan ini',
      icon: 'wallet',
      color: RumaColors.sage,
      action: 'Lihat keuangan',
      onTap: () => widget.onTab(3),
      child: !ready
          ? _status(
              s == null
                  ? 'Mulai catat pemasukan dan pengeluaran.'
                  : s.error != null
                  ? 'Keuangan belum termuat.'
                  : 'Memuat keuangan…',
              retry: s?.error != null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _primary(rupiah(data!.balance), 'Saldo tercatat'),
                const SizedBox(height: 16),
                RumaActionPair(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  first: _Fact(
                    label: 'Pengeluaran',
                    value: rupiah(data.month.expense),
                    detail: MaterialLocalizations.of(context)
                        .formatMonthYear(agendaLocal(_now)),
                  ),
                  second: _Fact(
                    label: 'Tabungan',
                    value: savingsReady
                        ? rupiah(saved.totalSavedRupiah)
                        : savings?.loading == true
                        ? 'Memuat…'
                        : 'Belum termuat',
                    detail: savingsReady
                        ? 'Tersedia ${rupiah(saved.availableRupiah)}'
                        : null,
                    warning: savingsReady && saved.availableRupiah < 0,
                  ),
                ),
                if (savings?.error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: savings!.load,
                      icon: const RumaIcon('refresh-cw'),
                      label: const Text('Muat ulang tabungan'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _primary(String value, String caption) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(caption, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _status(String text, {bool retry = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text),
      if (retry)
        TextButton.icon(
          onPressed: _reload,
          icon: const RumaIcon('refresh-cw'),
          label: const Text('Muat ulang'),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RumaHeading(
        'Waktu & uangmu.',
        'Halo, ${widget.account.greetingName}!',
        compact: true,
      ),
      const SizedBox(height: 12),
      RumaCard(
        color: RumaColors.ink,
        padding: 0,
        child: ListTile(
          key: const ValueKey('home-assistant'),
          leading: const RumaIcon('message-circle', color: RumaColors.accent),
          title: const Text(
            'Buka Asisten AI',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          trailing: const RumaIcon('chevron-right', color: RumaColors.accent),
          onTap: () => widget.onTab(2),
        ),
      ),
      const SizedBox(height: 12),
      ListenableBuilder(
        listenable: widget.agenda ?? const AlwaysStoppedAnimation(0),
        builder: (_, _) => _time(),
      ),
      const SizedBox(height: 12),
      ListenableBuilder(
        listenable: Listenable.merge([widget.finance, widget.savings]),
        builder: (_, _) => _money(),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.action,
    required this.onTap,
    required this.child,
  });
  final String title, icon, action;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => RumaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RumaIcon(icon, color: RumaColors.accentInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onTap, child: Text(action)),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.detail,
    this.warning = false,
    this.onTap,
  });
  final String label, value;
  final String? detail;
  final bool warning;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: warning ? RumaColors.accentInk : RumaColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: onTap == null ? null : 2,
            overflow: onTap == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
    return onTap == null
        ? content
        : Semantics(
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: content,
            ),
          );
  }
}
