import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/user_settings.dart';
import '../../ui/components.dart';

Color avatarColor(String value) => switch (value) {
  'sage' => RumaColors.muted,
  'peach' => RumaColors.peach,
  'ink' => RumaColors.ink,
  _ => RumaColors.accent,
};

class PersonalSettingsPage extends StatefulWidget {
  const PersonalSettingsPage({
    super.key,
    required this.store,
    this.preferences = false,
  });
  final UserSettingsStore store;
  final bool preferences;
  @override
  State<PersonalSettingsPage> createState() => _PersonalSettingsPageState();
}

class _PersonalSettingsPageState extends State<PersonalSettingsPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController bio, study, duration;
  late String avatar;
  late bool personalize;
  late int from, to;
  @override
  void initState() {
    super.initState();
    final v = widget.store.value;
    bio = TextEditingController(text: v.bio);
    study = TextEditingController(text: v.study);
    duration = TextEditingController(text: '${v.duration}');
    avatar = v.avatar;
    personalize = v.personalize;
    from = v.from;
    to = v.to;
  }

  @override
  void dispose() {
    bio.dispose();
    study.dispose();
    duration.dispose();
    super.dispose();
  }

  String clock(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}.${(m % 60).toString().padLeft(2, '0')}';
  Future<void> pick(bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: ((start ? from : to) ~/ 60) % 24,
        minute: (start ? from : to) % 60,
      ),
    );
    if (t != null && mounted) {
      setState(() {
        if (start) {
          from = t.hour * 60 + t.minute;
        } else {
          to = t.hour * 60 + t.minute;
        }
      });
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final next = UserSettings(
      bio: bio.text,
      study: study.text,
      avatar: avatar,
      personalize: personalize,
      duration: int.tryParse(duration.text) ?? 30,
      from: from,
      to: to,
    );
    if (await widget.store.save(next) && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          widget.preferences ? 'Preferensi AI' : 'Kustomisasi profil',
        ),
      ),
      body: RumaPageBody(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.preferences) ...[
                SwitchListTile(
                  key: const ValueKey('personalize-toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gunakan preferensiku'),
                  subtitle: const Text('Pilihan di pesan tetap diutamakan.'),
                  value: personalize,
                  onChanged: widget.store.busy
                      ? null
                      : (v) => setState(() => personalize = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('preferred-duration'),
                  controller: duration,
                  enabled: !widget.store.busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durasi bawaan (menit)',
                  ),
                  validator: (s) {
                    final n = int.tryParse(s ?? '');
                    return n == null || n < 5 || n > 120
                        ? 'Pilih 5–120 menit.'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                RumaDurationChoices(
                  controller: duration,
                  enabled: !widget.store.busy,
                ),
                const SizedBox(height: 24),
                Text(
                  'Jam saran AI (WIB)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                RumaActionPair(
                  first: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: RumaColors.subtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: widget.store.busy ? null : () => pick(true),
                    child: Text('Mulai ${clock(from)} WIB'),
                  ),
                  second: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: RumaColors.subtle,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: widget.store.busy ? null : () => pick(false),
                    child: Text('Sampai ${clock(to)} WIB'),
                  ),
                ),
              ] else ...[
                TextFormField(
                  key: const ValueKey('profile-study'),
                  controller: study,
                  enabled: !widget.store.busy,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Kampus / program studi',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('profile-bio'),
                  controller: bio,
                  enabled: !widget.store.busy,
                  maxLength: 160,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 16),
                const Text('Warna avatar'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ['orange', 'sage', 'peach', 'ink'])
                      ChoiceChip(
                        label: Text(switch (c) {
                          'orange' => 'Oranye',
                          'sage' => 'Hijau',
                          'peach' => 'Peach',
                          _ => 'Gelap',
                        }),
                        avatar: CircleAvatar(
                          backgroundColor: avatarColor(c),
                          radius: 8,
                        ),
                        selected: c == avatar,
                        onSelected: widget.store.busy
                            ? null
                            : (_) => setState(() => avatar = c),
                      ),
                  ],
                ),
              ],
              if (widget.store.error.isNotEmpty) ...[
                const SizedBox(height: 12),
                ErrorNotice(widget.store.error),
                TextButton(
                  onPressed: widget.store.busy
                      ? null
                      : () async {
                          await widget.store.load();
                          if (context.mounted && widget.store.error.isEmpty) {
                            Navigator.pop(context);
                          }
                        },
                  child: const Text('Muat ulang dan kembali'),
                ),
              ],
              const SizedBox(height: 24),
              RumaButton(
                key: const ValueKey('personal-settings-save'),
                label: 'Simpan',
                busy: widget.store.busy,
                onPressed: widget.store.busy ? null : save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
