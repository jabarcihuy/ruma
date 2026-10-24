import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserSettings {
  const UserSettings({
    this.bio = '',
    this.study = '',
    this.avatar = 'orange',
    this.personalize = false,
    this.duration = 30,
    this.from = 480,
    this.to = 1260,
  });
  final String bio, study, avatar;
  final bool personalize;
  final int duration, from, to;
  Map<String, dynamic> toJson() => {
    'bio': bio.trim(),
    'study': study.trim(),
    'avatar': avatar,
    'personalize': personalize,
    'duration': duration,
    'from': from,
    'to': to,
  };
  String? validate() =>
      bio.length > 160 ||
          study.length > 80 ||
          !['orange', 'sage', 'peach', 'ink'].contains(avatar) ||
          duration < 5 ||
          duration > 120 ||
          from < 0 ||
          to > 1440 ||
          to - from < 5
      ? 'Periksa profil, durasi 5–120 menit, dan rentang jam.'
      : null;
  static UserSettings decode(Map<String, dynamic> m) {
    final s = UserSettings(
      bio: m['bio'] as String,
      study: m['study'] as String,
      avatar: m['avatar'] as String,
      personalize: m['personalize'] as bool,
      duration: m['duration'] as int,
      from: m['from'] as int,
      to: m['to'] as int,
    );
    if (s.validate() != null) throw const FormatException('settings');
    return s;
  }
}

class UserSettingsStore extends ChangeNotifier {
  UserSettingsStore(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  UserSettings value = const UserSettings();
  bool ready = false, busy = false, _closed = false;
  String error = '';
  int revision = 0;
  void check() {
    if (_closed || auth.currentUser?.uid != uid) {
      throw StateError('Sesi berubah.');
    }
  }

  void emit() {
    if (!_closed) notifyListeners();
  }

  Future<void> load() async {
    if (busy || _closed) return;
    busy = true;
    error = '';
    emit();
    try {
      check();
      final d = await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('personal')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      check();
      value = d.exists ? UserSettings.decode(d.data()!) : const UserSettings();
      revision = d.data()?['revision'] as int? ?? 0;
      ready = true;
    } catch (_) {
      error = 'Profil dan preferensi belum termuat. Coba muat ulang.';
    } finally {
      busy = false;
      emit();
    }
  }

  Future<bool> save(UserSettings next) async {
    if (!ready || busy || _closed) return false;
    final invalid = next.validate();
    if (invalid != null) {
      error = invalid;
      emit();
      return false;
    }
    busy = true;
    error = '';
    emit();
    try {
      check();
      final ref = db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('personal');
      await db.runTransaction(
        (tx) async {
          check();
          final d = await tx.get(ref);
          if ((d.data()?['revision'] ?? 0) != revision) {
            throw StateError('stale');
          }
          tx.set(ref, {
            ...next.toJson(),
            'schemaVersion': 1,
            'revision': revision + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
        timeout: const Duration(seconds: 15),
        maxAttempts: 3,
      );
      check();
      value = next;
      revision++;
      return true;
    } catch (_) {
      error = 'Hasil belum terkonfirmasi atau data berubah. Muat ulang sebelum mencoba lagi.';
      return false;
    } finally {
      busy = false;
      emit();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

// Explicit durations win. Personal profile fields are not added to provider context.
int preferredDuration(UserSettings? settings, String quote, int proposed) =>
    settings?.personalize == true &&
        !RegExp(
          r'\b(menit|mnt|jam|sejam|setengah|seperempat|minutes?|mins?|hours?|hrs?)\b|\b\d+\s*(menit|mnt|m|h)\b',
          caseSensitive: false,
        ).hasMatch(quote)
    ? settings!.duration
    : proposed;
