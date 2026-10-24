import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../../data/agenda_repository.dart';
import '../../ui/components.dart';
import 'agenda_form.dart';
import 'agenda_detail.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.store});
  final AgendaStore store;
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  DateTime _day = agendaDay(agendaLocal(DateTime.now().toUtc()));
  Future<void> _add() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tambahkan apa?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              RumaButton(
                label: 'Tugas / kegiatan',
                onPressed: () => Navigator.pop(context, 'task'),
              ),
              const SizedBox(height: 8),
              RumaButton(
                label: 'Jadwal kuliah',
                secondary: true,
                onPressed: () => Navigator.pop(context, 'class'),
              ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgendaFormPage(store: widget.store, kind: kind),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kegiatan tersimpan.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final week = _day.subtract(Duration(days: _day.weekday - 1));
      final entries = store.forDay(_day).where((a) => a.occursOn(_day)).toList()
        ..sort((a, b) => a.input.startAtUtc!.compareTo(b.input.startAtUtc!));
      final unscheduled =
          store.items
              .where(
                (a) =>
                    a.input.startAtUtc == null && a.input.status == 'planned',
              )
              .toList()
            ..sort(
              (a, b) => (a.input.deadlineAtUtc ?? DateTime.utc(9999)).compareTo(
                b.input.deadlineAtUtc ?? DateTime.utc(9999),
              ),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RumaHeading('Agendamu minggu ini', null, compact: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const ValueKey('agenda-add'),
                  icon: const RumaIcon('plus', color: RumaColors.accent),
                  label: const Text('Tambah'),
                  style: TextButton.styleFrom(
                    backgroundColor: RumaColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: store.saving || store.loading ? null : _add,
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang agenda',
                onPressed: store.loading || store.saving ? null : store.load,
                icon: const RumaIcon('refresh-cw'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: 'Minggu sebelumnya',
                onPressed: () => setState(
                  () => _day = _day.subtract(const Duration(days: 7)),
                ),
                icon: const RotatedBox(
                  quarterTurns: 2,
                  child: RumaIcon('chevron-right'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() => _day = agendaDay(picked));
                    }
                  },
                  child: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(week)} – ${MaterialLocalizations.of(context).formatMediumDate(week.add(const Duration(days: 6)))}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Minggu berikutnya',
                onPressed: () =>
                    setState(() => _day = _day.add(const Duration(days: 7))),
                icon: const RumaIcon('chevron-right'),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (i) {
                  final date = week.add(Duration(days: i));
                  final selected = agendaDay(date) == _day;
                  return Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 8),
                    child: Semantics(
                      selected: selected,
                      child: Material(
                        color: selected
                            ? RumaColors.accent
                            : RumaColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: ValueKey('agenda-day-$i'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _day = date),
                          child: Container(
                            width: ((box.maxWidth - 48) / 7).clamp(
                              MediaQuery.textScalerOf(context).scale(12) * 4,
                              double.infinity,
                            ),
                            constraints: const BoxConstraints(minHeight: 64),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  const [
                                    'Sen',
                                    'Sel',
                                    'Rab',
                                    'Kam',
                                    'Jum',
                                    'Sab',
                                    'Min',
                                  ][i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selected
                                        ? Colors.white
                                        : RumaColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : RumaColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            dayLabel(context, _day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (store.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Memuat agenda',
                ),
              ),
            ),
          if (store.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ErrorNotice(store.error!),
            ),
          if (!store.loading && store.loaded && entries.isEmpty)
            RumaCard(
              color: RumaColors.sage,
              child: Column(
                children: [
                  SvgPicture.asset(
                    'design/assets/ruma/illustrations/illustration-calendar.svg',
                    width: 120,
                    height: 84,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Harimu masih lapang',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Belum ada kegiatan terjadwal pada hari ini.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(12) * 4.7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clockLabel(context, entry.input.startAtUtc!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: RumaColors.accent,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          clockLabel(context, entry.input.endAtUtc!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _card(context, entry)),
                ],
              ),
            ),
          if (unscheduled.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Belum dijadwalkan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final entry in unscheduled)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(context, entry),
              ),
          ],
          if (store.items.any(
            (a) => a.input.startAtUtc == null && a.input.status != 'planned',
          )) ...[
            const SizedBox(height: 16),
            Text(
              'Selesai & dibatalkan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final entry
                in store
                    .forDay(_day)
                    .where(
                      (a) =>
                          a.input.startAtUtc == null &&
                          a.input.status != 'planned',
                    ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(context, entry),
              ),
          ],
        ],
      );
    },
  );
  Widget _card(BuildContext context, AgendaItem entry) => Material(
    color: entry.input.status == 'completed'
        ? RumaColors.line
        : entry.input.kind == 'class'
        ? RumaColors.sage
        : RumaColors.peach,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      key: ValueKey('agenda-item-${entry.id}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgendaDetailPage(store: widget.store, id: entry.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.input.status == 'completed'
                        ? 'SELESAI'
                        : entry.input.status == 'cancelled'
                        ? 'DIBATALKAN'
                        : entry.input.kind == 'class'
                        ? 'KULIAH'
                        : 'TUGAS',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                RumaIcon(
                  entry.input.kind == 'class' ? 'book-open' : 'clock-3',
                  size: 20,
                  color: RumaColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.input.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.input.durationMinutes} menit${entry.input.deadlineAtUtc == null ? '' : ' · tenggat ${MaterialLocalizations.of(context).formatMediumDate(agendaLocal(entry.input.deadlineAtUtc!))}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
