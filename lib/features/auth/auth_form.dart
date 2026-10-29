import 'package:flutter/material.dart';

import '../../data/auth_session.dart';
import '../../ui/components.dart';
import '../../app/theme.dart';

String? validateEmail(String? value) =>
    value == null ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? 'Masukkan email yang valid.'
    : null;
String? validateName(String? value) =>
    value == null || value.trim().isEmpty ? 'Isi nama panggilanmu.' : null;
String? validatePassword(String? value, {required bool signup}) {
  if (value == null || value.isEmpty) return 'Isi kata sandimu.';
  if (signup && value.length < 6) return 'Gunakan sedikitnya 6 karakter.';
  return null;
}

Future<bool> _confirmGoogleAccount(BuildContext context) async {
  var agreed = false;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => RumaDialog(
            title: const Text('Lanjut dengan Google?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ruma memakai akun Google untuk masuk dan menjaga akses ke data Ruma. Izin Google Calendar tetap diminta terpisah saat kamu mengimpor jadwal.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => showRumaPrivacy(context),
                    child: const Text('Baca ketentuan & privasi Ruma'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: agreed,
                  title: const Text(
                    'Saya menyetujui ketentuan dan privasi Ruma.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => agreed = value ?? false),
                ),
              ],
            ),
            actions: [
              RumaButton(
                label: 'Batal',
                secondary: true,
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              RumaButton(
                label: 'Setuju & lanjut',
                onPressed: agreed
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class AuthForm extends StatefulWidget {
  const AuthForm({super.key, required this.session, this.signup = false});
  final AuthSession session;
  final bool signup;
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  bool _showPassword = false, _agreed = false, _agreementError = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() {
      _agreementError = widget.signup && !_agreed;
      _error = null;
    });
    if (!valid || _agreementError) return;
    FocusScope.of(context).unfocus();
    final success = widget.signup
        ? await widget.session.signUp(_name.text, _email.text, _password.text)
        : await widget.session.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(
        () => _error = widget.session.error ?? 'Belum berhasil. Coba lagi.',
      );
    }
  }

  Future<void> _continueWithGoogle() async {
    if (widget.signup && !_agreed) {
      setState(() => _agreementError = true);
      return;
    }
    if (!widget.signup && !await _confirmGoogleAccount(context)) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final linkTemporaryAccount =
        widget.signup && widget.session.account?.anonymous == true;
    final success = linkTemporaryAccount
        ? await widget.session.linkGoogleAccount()
        : await widget.session.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(
        () => _error =
            widget.session.error ??
            widget.session.notice ??
            'Login Google dibatalkan.',
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    required String id,
    TextInputType? keyboard,
    bool password = false,
    Iterable<String>? autofill,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey(id),
            controller: controller,
            validator: validator,
            enabled: !widget.session.busy,
            keyboardType: keyboard,
            obscureText: password && !_showPassword,
            autocorrect: false,
            enableSuggestions: !password,
            autofillHints: autofill,
            textInputAction: password
                ? TextInputAction.done
                : TextInputAction.next,
            maxLength: id == 'name' ? 80 : null,
            onFieldSubmitted: password ? (_) => _submit() : null,
            decoration: InputDecoration(
              counterText: '',
              hintText: password
                  ? 'Kata sandimu'
                  : id == 'email'
                  ? 'nama@kampus.ac.id'
                  : 'Nama panggilanmu',
              suffixIcon: password
                  ? IconButton(
                      tooltip: _showPassword
                          ? 'Sembunyikan kata sandi'
                          : 'Tampilkan kata sandi',
                      onPressed: widget.session.busy
                          ? null
                          : () =>
                                setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => PopScope(
      canPop: !widget.session.busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Akun Ruma'),
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: widget.session.busy
                ? null
                : () => Navigator.pop(context),
            icon: const RumaIcon('arrow-left', color: RumaColors.accent),
          ),
        ),
        body: RumaPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RumaHeading(
                        widget.signup
                            ? widget.session.account?.anonymous == true
                                  ? 'Jaga akses ke akun Ruma'
                                  : 'Buat akun Ruma'
                            : 'Selamat datang lagi',
                        null,
                        compact: true,
                      ),
                      const SizedBox(height: 16),
                      if (widget.signup)
                        _field(
                          'Nama panggilan',
                          _name,
                          validateName,
                          id: 'name',
                          autofill: const [AutofillHints.nickname],
                        ),
                      _field(
                        'Email',
                        _email,
                        validateEmail,
                        id: 'email',
                        keyboard: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                      ),
                      _field(
                        'Kata sandi',
                        _password,
                        (value) =>
                            validatePassword(value, signup: widget.signup),
                        id: 'password',
                        password: true,
                        autofill: [
                          widget.signup
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                      ),
                      if (widget.signup) ...[
                        Text(
                          'Minimal 6 karakter.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        RumaCard(
                          color: RumaColors.soft,
                          padding: 8,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => showRumaPrivacy(context),
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: RumaColors.ink,
                                  ),
                                  child: const Text(
                                    'Baca ketentuan & privasi Ruma',
                                  ),
                                ),
                              ),
                              Checkbox(
                                key: const ValueKey('privacy-agreement'),
                                semanticLabel: 'Saya telah membaca dan menyetujui ketentuan dan privasi Ruma',
                                value: _agreed,
                                onChanged: widget.session.busy
                                    ? null
                                    : (value) => setState(() {
                                        _agreed = value ?? false;
                                        _agreementError = false;
                                      }),
                              ),
                            ],
                          ),
                        ),
                        if (_agreementError)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Baca dan setujui ketentuan & privasi terlebih dahulu.',
                              style: TextStyle(color: RumaColors.danger),
                            ),
                          ),
                      ] else
                        Text(
                          'Belum punya akun?',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (widget.session.account?.anonymous == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            widget.signup
                                ? 'Tautkan email atau Google untuk mempertahankan akun dan datamu.'
                                : 'Masuk ke akun lain tidak memindahkan data sementara. Tautkan email atau Google melalui Profil untuk mempertahankan akun ini.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ErrorNotice(_error!),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RumaButton(
                key: const ValueKey('auth-submit'),
                label: widget.session.busy
                    ? 'Sebentar…'
                    : widget.signup
                    ? 'Buat akun'
                    : 'Masuk',
                busy: widget.session.busy,
                onPressed: _submit,
              ),
              if (widget.signup) ...[
                const SizedBox(height: 8),
                RumaButton(
                  label: 'Daftar dengan Google',
                  secondary: true,
                  onPressed: widget.session.busy ? null : _continueWithGoogle,
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('atau', textAlign: TextAlign.center),
                ),
                RumaButton(
                  label: 'Masuk dengan Google',
                  secondary: true,
                  onPressed: widget.session.busy ? null : _continueWithGoogle,
                ),
                const SizedBox(height: 8),
                RumaButton(
                  label: 'Buat akun',
                  secondary: true,
                  onPressed: widget.session.busy
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AuthForm(session: widget.session, signup: true),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
