import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../../data/recurrence.dart';
import '../../data/reminders.dart';
import '../../data/push_notifications.dart';
import '../notifications/notification_pages.dart';
import '../../data/agenda_repository.dart';
import '../../ui/components.dart';
import 'agenda_form.dart';

class AgendaDetailPage extends StatefulWidget {
  const AgendaDetailPage({
    super.key,
    required this.store,
    required this.id,
    this.notifications,
    this.notificationVersion,
  });
  final AgendaStore store;
  final String id;
  final RumaNotifications? notifications;
  final int? notificationVersion;
  @override
  State<AgendaDetailPage> createState() => _AgendaDetailPageState();
}

class _AgendaDetailPageState extends State<AgendaDetailPage> {
  AgendaMutation? _pending;
  Future<void> _change(
    AgendaItem item, {
    bool delete = false,
    String scope = 'one',
  }) async {
    if (delete) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => RumaDialog(
          title: const Text('Hapus kegiatan ini?'),
          content: Text('“${item.input.title}” tidak akan tampil di agenda.'),
          actions: [
            RumaButton(
              label: 'Batalkan',
              secondary: true,
              onPressed: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 8),
            RumaButton(
              label: 'Hapus kegiatan',
              destructive: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final input = delete
        ? item.input
        : item.input.withStatus(
            item.input.status == 'completed' ? 'planned' : 'completed',
          );
    final candidate = AgendaMutation(
      operationId: _pending?.operationId ?? widget.store.repository.newId(),
      scope: scope,
      id: item.id,
      input: input,
      originalVersion: item.version,
      delete: delete,
    );
    _pending = _pending?.requestKey == candidate.requestKey
        ? candidate
        : AgendaMutation(
            operationId: widget.store.repository.newId(),
            scope: scope,
            id: item.id,
            input: input,
            originalVersion: item.version,
            delete: delete,
          );
    final ok = await widget.store.save(_pending!);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delete ? 'Kegiatan dihapus.' : 'Status kegiatan diperbarui.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final item = widget.store.meeting(widget.id);
      final entry = item;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Agenda'),
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
              if (entry == null) ...[
                const RumaHeading(
                  'Kegiatan tidak tersedia',
                  'Kegiatan mungkin sudah dihapus atau akun telah berubah.',
                ),
                const SizedBox(height: 16),
                RumaButton(
                  label: 'Kembali ke agenda',
                  onPressed: () => Navigator.pop(context),
                ),
              ] else ...[
                if (widget.notificationVersion != null &&
                    widget.notificationVersion != entry.version) ...[
                  const RumaCard(
                    color: RumaColors.sage,
                    child: Text(
                      'Jadwal sudah diperbarui. Ini keadaan terbaru.',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                RumaHeading(entry.input.title, null, compact: true),
                if (entry.importSource != null) ...[
                  const SizedBox(height: 12),
                  RumaCard(
                    color: RumaColors.sage,
                    child: Text(
                      entry.importSource!['provider'] == 'google'
                          ? 'Diimpor dari Google Calendar. Suntingan hanya berlaku di Ruma. Periksa pembaruan melalui Impor jadwal di Agenda.'
                          : 'Diimpor dari gambar jadwal. Periksa kembali rincian jika sumber berubah.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                RumaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        entry.input.status == 'completed'
                            ? 'Selesai'
                            : entry.input.status == 'cancelled'
                            ? 'Dibatalkan'
                            : entry.input.kind == 'class'
                            ? 'Kuliah'
                            : 'Tugas',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.input.startAtUtc == null
                            ? 'Belum dijadwalkan'
                            : dayLabel(
                                context,
                                agendaLocal(entry.input.startAtUtc!),
                              ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.input.startAtUtc == null ? '' : '${clockLabel(context, entry.input.startAtUtc!)} – ${clockLabel(context, entry.input.endAtUtc!)} WIB · '}${entry.input.durationMinutes} menit',
                      ),
                      if (entry.input.deadlineAtUtc != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Deadline: ${dayLabel(context, agendaLocal(entry.input.deadlineAtUtc!))} · ${clockLabel(context, entry.input.deadlineAtUtc!)} WIB',
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Prioritas: ${const {'low': 'Rendah', 'normal': 'Normal', 'high': 'Tinggi'}[entry.input.priority]}',
                      ),
                      if (entry.input.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(entry.input.description),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if ((widget.notifications ?? widget.store.notifications) !=
                    null) ...[
                  RumaCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.notifications_none,
                        color: RumaColors.accent,
                      ),
                      title: const Text('Atur pengingat'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => ReminderPage(
                            item: entry,
                            repository: ReminderRepository(
                              widget.store.repository.db,
                              widget.store.repository.auth,
                            ),
                            notifications:
                                (widget.notifications ??
                                widget.store.notifications)!,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.store.saving
                        ? null
                        : () async {
                            final push =
                                widget.notifications ??
                                widget.store.notifications!;
                            final ok = await push.snoozeAgenda(entry);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Pengingat lokal dijadwalkan sekitar 5 menit lagi.'
                                        : push.error,
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const RumaIcon('clock-3'),
                    label: const Text('Ingatkan 5 menit lagi'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (occurrenceKey(entry.id) != null) ...[
                  RumaCard(
                    child: ExpansionTile(
                      title: const Text('Atur seri mingguan'),
                      children: [
                        ListTile(
                          title: const Text('Ubah mulai pertemuan ini'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => AgendaFormPage(
                                store: widget.store,
                                existing: entry,
                                scope: 'future',
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          title: const Text('Ubah seluruh seri'),
                          onTap: () {
                            final raw = widget.store.series.firstWhere(
                              (s) => s.id == occurrenceKey(entry.id)!.$1,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AgendaFormPage(
                                  store: widget.store,
                                  existing: raw,
                                ),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('Batalkan mulai pertemuan ini'),
                          onTap: () =>
                              _change(entry, delete: true, scope: 'future'),
                        ),
                        ListTile(
                          title: const Text('Hapus seluruh seri'),
                          onTap: () {
                            final raw = widget.store.series.firstWhere(
                              (s) => s.id == occurrenceKey(entry.id)!.$1,
                            );
                            _change(raw, delete: true);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                RumaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const RumaIcon(
                      'sliders-horizontal',
                      color: RumaColors.accent,
                    ),
                    title: const Text('Edit kegiatan'),
                    trailing: const RumaIcon(
                      'chevron-right',
                      color: RumaColors.accent,
                    ),
                    onTap: widget.store.saving
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AgendaFormPage(
                                  store: widget.store,
                                  existing: entry,
                                ),
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(height: 12),
                RumaCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const RumaIcon(
                      'circle-alert',
                      color: RumaColors.accent,
                    ),
                    title: const Text('Hapus kegiatan'),
                    trailing: const RumaIcon(
                      'chevron-right',
                      color: RumaColors.accent,
                    ),
                    onTap: widget.store.saving
                        ? null
                        : () => _change(entry, delete: true),
                  ),
                ),
                const SizedBox(height: 12),
                RumaButton(
                  key: const ValueKey('agenda-complete'),
                  secondary: true,
                  label: entry.input.status == 'completed'
                      ? 'Tandai belum selesai'
                      : 'Tandai selesai',
                  busy: widget.store.saving,
                  onPressed: () => _change(entry),
                ),
                if (widget.store.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ErrorNotice(widget.store.error!),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
