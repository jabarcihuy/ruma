import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../data/auth_session.dart';
import '../../ui/components.dart';
import 'auth_form.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.session});
  final AuthSession session;
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? _error;
  Future<void> _start() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => RumaDialog(
        title: const Text('Mulai tanpa daftar email?'),
        content: const Text(
          'Ruma membuat akun sementara di cloud. Pertama kali perlu internet. Akun ini tidak dapat dipulihkan jika sesi atau instalasi hilang. Tautkan email atau Google nanti melalui Profil untuk mempertahankan akses.',
        ),
        actions: [
          RumaButton(
            label: 'Batal',
            secondary: true,
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 8),
          RumaButton(
            label: 'Lanjut tanpa daftar',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (consent != true) return;
    final ok = await widget.session.enterTemporarily();
    if (mounted && !ok) setState(() => _error = widget.session.error);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 24,
        title: Text('ruma', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 40),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const RumaHeading(
                          'Ruang untuk waktu\ndan uangmu.',
                          null,
                        ),
                        const SizedBox(height: 12),
                        _WelcomeIllustration(width: constraints.maxWidth - 48),
                        const SizedBox(height: 14),
                        Text(
                          'Atur jadwal dan catat uang lewat Asisten AI.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ErrorNotice(_error!),
                          ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        RumaButton(
                          label: widget.session.busy
                              ? 'Menyiapkan ruangmu…'
                              : 'Mulai tanpa akun',
                          busy: widget.session.busy,
                          onPressed: _start,
                        ),
                        const SizedBox(height: 8),
                        RumaButton(
                          label: 'Masuk atau buat akun',
                          secondary: true,
                          onPressed: widget.session.busy
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AuthForm(session: widget.session),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) {
    if (width >= 300 && MediaQuery.textScalerOf(context).scale(13) <= 18) {
      return Semantics(
        image: true,
        label: 'Ilustrasi contoh jadwal kuliah dan ringkasan uang',
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: RumaColors.peach,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Center(
                child: SvgPicture.asset(
                  'design/assets/ruma/illustrations/illustration-calendar.svg',
                  width: 200,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                left: 16,
                top: 24,
                width: 208,
                child: RumaCard(
                  padding: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '08.00 · Kuliah',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Metode Penelitian',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uang · Bulan ini',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sisa Rp320.000',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      image: true,
      label: 'Ilustrasi contoh jadwal kuliah dan ringkasan uang',
      child: RumaCard(
        color: RumaColors.peach,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RumaCard(
              padding: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '08.00 · Kuliah',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Metode Penelitian',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SvgPicture.asset(
              'design/assets/ruma/illustrations/illustration-calendar.svg',
              width: 200,
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              'Uang · Bulan ini',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Sisa Rp320.000',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
