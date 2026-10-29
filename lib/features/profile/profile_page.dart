import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/auth_session.dart';
import '../../data/user_settings.dart';
import 'personal_settings_page.dart';
import '../../ui/components.dart';
import '../auth/auth_form.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.session,
    this.onNotifications,
    this.settings,
  });
  final AuthSession session;
  final UserSettingsStore? settings;
  final VoidCallback? onNotifications;

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: session.account?.name);
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => RumaDialog(
        title: const Text('Nama panggilanmu'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('profile-name'),
            controller: controller,
            autofocus: true,
            maxLength: 80,
            validator: validateName,
            decoration: const InputDecoration(labelText: 'Nama panggilan'),
          ),
        ),
        actions: [
          RumaButton(
            label: 'Batal',
            secondary: true,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Simpan',
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (name == null || !context.mounted) return;
    final ok = await session.updateName(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Nama panggilan diperbarui.'
                : session.error ?? 'Nama belum dapat disimpan.',
          ),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final temporary = session.account!.anonymous;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => RumaDialog(
        title: const Text('Keluar dari akun?'),
        content: Text(
          temporary
              ? 'Akun sementara tidak bisa dipulihkan setelah keluar. Tautkan email atau Google melalui Profil untuk mempertahankan akses.'
              : 'Data akun tetap tersimpan. Masuk kembali untuk mengaksesnya.',
        ),
        actions: [
          RumaButton(
            label: 'Batalkan',
            secondary: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Keluar',
            destructive: true,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ok = await session.signOut();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'Belum dapat keluar. Coba lagi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = session.account!;
    final name = account.greetingName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RumaHeading('Ruang untuk dirimu.', null, compact: true),
        const SizedBox(height: 12),
        RumaCard(
          color: RumaColors.sage,
          padding: 20,
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: avatarColor(
                  settings?.value.avatar ?? 'orange',
                ),
                foregroundColor: settings?.value.avatar == 'peach'
                    ? RumaColors.ink
                    : Colors.white,
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                account.anonymous
                    ? 'Akun sementara · tanpa daftar email'
                    : account.email ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (settings?.ready == true) ...[
                if (settings!.value.study.isNotEmpty)
                  Text(
                    settings!.value.study,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                if (settings!.value.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      settings!.value.bio,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
              RumaButton(
                label: session.busy ? 'Menyimpan…' : 'Ubah nama panggilan',
                busy: session.busy,
                onPressed: () => _editName(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (settings != null) ...[
          RumaCard(
            child: Column(
              children: [
                if (settings!.error.isNotEmpty) ErrorNotice(settings!.error),
                if (!settings!.ready)
                  TextButton(
                    onPressed: settings!.busy ? null : settings!.load,
                    child: Text(
                      settings!.busy ? 'Memuat profil…' : 'Muat ulang profil',
                    ),
                  ),
                for (final pref in [false, true])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pref ? 'Preferensi AI' : 'Kustomisasi profil'),
                    trailing: const RumaIcon('chevron-right'),
                    onTap: !settings!.ready || settings!.busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PersonalSettingsPage(
                                store: settings!,
                                preferences: pref,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (onNotifications != null) ...[
          RumaCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.notifications_none,
                color: RumaColors.accent,
              ),
              title: const Text('Notifikasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onNotifications,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (account.anonymous) ...[
          RumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Jaga akses ke ruangmu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tautkan email atau Google agar akun dan datamu dapat dipakai kembali di perangkat lain.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                RumaButton(
                  label: 'Tautkan email atau Google',
                  onPressed: session.busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AuthForm(session: session, signup: true),
                          ),
                        ),
                ),
                TextButton(
                  onPressed: session.busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AuthForm(session: session),
                          ),
                        ),
                  child: const Text('Masuk ke akun lain'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        RumaCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const RumaIcon('shield-check', color: RumaColors.accent),
            title: const Text('Privasi Ruma'),
            trailing: const RumaIcon('chevron-right', color: RumaColors.accent),
            onTap: () => showRumaPrivacy(context),
          ),
        ),
        const SizedBox(height: 12),
        RumaButton(
          key: const ValueKey('logout'),
          label: 'Keluar dari akun',
          secondary: true,
          onPressed: session.busy ? null : () => _logout(context),
        ),
      ],
    );
  }
}
