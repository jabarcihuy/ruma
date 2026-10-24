import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/agenda.dart';
import '../agenda/agenda_form.dart';
import '../../data/push_notifications.dart';
import '../../data/reminders.dart';
import '../../ui/components.dart';

class ReminderPage extends StatefulWidget {
  const ReminderPage({
    super.key,
    required this.item,
    required this.repository,
    required this.notifications,
  });
  final AgendaItem item;
  final ReminderRepository repository;
  final RumaNotifications notifications;
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  bool loading = true, busy = false, enabled = false, ready = false;
  int lead = 10;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await widget.repository.read(widget.item.id);
      if (!mounted) return;
      enabled = d?['enabled'] == true;
      lead = d?['leadMinutes'] as int? ?? 10;
      ready = true;
    } catch (_) {
      error = 'Pengingat belum termuat. Buka ulang untuk mencoba lagi.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (busy || loading || !ready) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (enabled &&
          (!widget.notifications.enabled || !widget.notifications.allowed)) {
        if (!await widget.notifications.setEnabled(true)) {
          throw AgendaFailure(widget.notifications.error);
        }
      }
      await widget.repository.configure(widget.item, enabled, lead);
      await widget.notifications.reconcileSnoozes();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AgendaFailure
              ? e.message
              : 'Belum tersimpan. Periksa internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchor = reminderAnchor(widget.item.input);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat')),
      body: RumaPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RumaHeading(widget.item.input.title, null, compact: true),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              RumaCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ingatkan kegiatan ini'),
                      value: enabled,
                      onChanged: busy || !ready
                          ? null
                          : (v) => setState(() => enabled = v),
                    ),
                    if (anchor != null)
                      Text(
                        'Acuan ${widget.item.input.startAtUtc == null ? 'deadline' : 'mulai'}: ${dayLabel(context, agendaLocal(anchor))} · ${clockLabel(context, anchor)} WIB',
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: lead,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        labelText: 'Waktu pengingat',
                      ),
                      items: [
                        for (final v in reminderLeads)
                          DropdownMenuItem(
                            value: v,
                            child: Text(
                              v == 0 ? 'Saat waktunya' : '$v menit sebelumnya',
                            ),
                          ),
                      ],
                      onChanged: busy ? null : (v) => setState(() => lead = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                anchor == null
                    ? 'Atur waktu mulai atau deadline terlebih dahulu.'
                    : 'Dikirim melalui internet. Kedatangan dapat terlambat jika perangkat tidak tersambung.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorNotice(error!),
              ],
              const SizedBox(height: 24),
              RumaButton(
                key: const ValueKey('reminder-save'),
                label: 'Simpan pengingat',
                busy: busy,
                onPressed: save,
              ),
              TextButton(
                onPressed: widget.notifications.openSettings,
                child: const Text('Pengaturan notifikasi Android'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.notifications,
    required this.repository,
  });
  final RumaNotifications notifications;
  final ReminderRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifikasi')),
    body: RumaPageBody(
      child: ListenableBuilder(
        listenable: notifications,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RumaHeading('Pengingat untuk agendamu', null, compact: true),
            const SizedBox(height: 16),
            RumaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const ValueKey('notifications-toggle'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifikasi di perangkat ini'),
                    subtitle: Text(
                      notifications.enabled && notifications.allowed
                          ? 'Aktif'
                          : 'Nonaktif',
                    ),
                    value: notifications.enabled && notifications.allowed,
                    onChanged: notifications.busy
                        ? null
                        : notifications.setEnabled,
                  ),
                  const Text('Atur pengingat lewat detail kegiatan.'),
                  TextButton(
                    onPressed: notifications.openSettings,
                    child: const Text('Buka pengaturan Android'),
                  ),
                ],
              ),
            ),
            if (notifications.error.isNotEmpty) ...[
              const SizedBox(height: 12),
              ErrorNotice(notifications.error),
            ],
            const SizedBox(height: 24),
            Text('Terbaru', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: repository.user
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const ErrorNotice(
                    'Daftar notifikasi belum termuat. Coba buka kembali.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const RumaCard(
                    child: Text('Belum ada pengingat yang dikirim.'),
                  );
                }
                return Column(
                  children: [
                    for (final d in docs) ...[
                      RumaCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.notifications_none,
                            color: RumaColors.accent,
                          ),
                          title: const Text('Pengingat Ruma'),
                          subtitle: const Text('Lihat agenda'),
                          trailing: Icon(
                            d.data()['readAt'] == null
                                ? Icons.circle
                                : Icons.chevron_right,
                            size: d.data()['readAt'] == null ? 8 : 22,
                          ),
                          onTap: () {
                            final data = d.data();
                            notifications.open({
                              'uid': repository.uid,
                              'agendaId': data['agendaId'],
                              'generation': '${data['generation']}',
                              'sourceVersion': '${data['sourceVersion']}',
                              'notificationId': d.id,
                              if (data['occurrenceDate'] != null)
                                'occurrenceDate': data['occurrenceDate'],
                            });
                            d.reference
                                .update({
                                  'readAt': FieldValue.serverTimestamp(),
                                })
                                .catchError((Object _) {});
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
