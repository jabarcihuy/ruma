import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class RumaAccount {
  const RumaAccount({
    required this.uid,
    this.name,
    this.email,
    required this.anonymous,
  });
  final String uid;
  final String? name, email;
  final bool anonymous;
  String get greetingName =>
      name?.trim().isNotEmpty == true ? name!.trim() : 'Teman Ruma';
  static RumaAccount? fromUser(User? user) => user == null
      ? null
      : RumaAccount(
          uid: user.uid,
          name: user.displayName,
          email: user.email,
          anonymous: user.isAnonymous,
        );
}

class AuthSession extends ChangeNotifier {
  AuthSession(this._auth) {
    _subscription = _auth.userChanges().listen(
      (user) {
        ready = true;
        if (!busy) account = RumaAccount.fromUser(user);
        notifyListeners();
      },
      onError: (Object _) {
        ready = true;
        error = 'Sesi belum dapat dimuat. Coba buka Ruma kembali.';
        notifyListeners();
      },
    );
  }
  final FirebaseAuth _auth;
  Future<void> Function()? beforeSignOut;
  late final StreamSubscription<User?> _subscription;
  RumaAccount? account;
  bool ready = false, busy = false;
  String? error, notice;

  Future<bool> _perform(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FirebaseAuthException catch (failure) {
      error = authErrorMessage(failure.code);
      return false;
    } catch (_) {
      error = 'Belum dapat terhubung. Periksa internet lalu coba lagi.';
      return false;
    } finally {
      account = RumaAccount.fromUser(_auth.currentUser);
      busy = false;
      ready = true;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) => _perform(() async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  Future<bool> enterTemporarily() => _perform(() async {
    await _auth.signInAnonymously();
  });
  Future<bool> signOut() => _perform(() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {}
    await _auth.signOut();
  });
  Future<bool> signUp(String name, String email, String password) => _perform(
    () async {
      final current = _auth.currentUser;
      final UserCredential credential;
      if (current?.isAnonymous == true) {
        credential = await current!.linkWithCredential(
          EmailAuthProvider.credential(email: email.trim(), password: password),
        );
      } else {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      }
      try {
        await credential.user!.updateDisplayName(name.trim());
      } on FirebaseAuthException {
        notice = 'Akun siap. Nama belum tersimpan; ubah lagi melalui Profil.';
      }
    },
  ).then((success) => success && error == null);

  Future<bool> updateName(String name) => _perform(() async {
    await _auth.currentUser!.updateDisplayName(name.trim());
  });
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

String authErrorMessage(String code) => switch (code) {
  'invalid-credential' ||
  'INVALID_LOGIN_CREDENTIALS' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-login-credentials' =>
    'Email atau kata sandi belum cocok. Periksa lalu coba lagi.',
  'email-already-in-use' || 'credential-already-in-use' => 'Email ini sudah digunakan. Coba email lain atau masuk ke akun tersebut. Akun sementara tetap tersedia.',
  'invalid-email' => 'Periksa kembali format emailmu.',
  'weak-password' || 'password-does-not-meet-requirements' => 'Kata sandi belum memenuhi kebijakan akun. Gunakan kata sandi yang lebih kuat.',
  'network-request-failed' => 'Tidak terhubung ke internet. Isianmu tetap ada; coba lagi setelah tersambung.',
  'too-many-requests' =>
    'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
  'user-disabled' => 'Akun belum dapat digunakan. Hubungi pengelola Ruma.',
  'operation-not-allowed' =>
    'Cara masuk ini sedang tidak tersedia. Coba lagi nanti.',
  'requires-recent-login' => 'Masuk kembali untuk melanjutkan perubahan ini.',
  _ => 'Belum berhasil. Isianmu tetap ada; silakan coba lagi.',
};
