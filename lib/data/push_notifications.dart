import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'agenda.dart';
import 'recurrence.dart';
import 'finance.dart' show validDate;

class NotificationTarget {
  const NotificationTarget(
    this.uid,
    this.agendaId,
    this.generation,
    this.sourceVersion, {
    this.occurrenceDate,
  });
  final String uid, agendaId;
  final String? occurrenceDate;
  final int generation, sourceVersion;
  String get id => '${agendaId}_$generation';
  Map<String, String> toJson() => {
    'uid': uid,
    'agendaId': agendaId,
    'generation': '$generation',
    'sourceVersion': '$sourceVersion',
    'notificationId': id,
    'occurrenceDate': ?occurrenceDate,
  };
  static NotificationTarget? parse(Map<String, dynamic> data) {
    final uid = data['uid'], a = data['agendaId'];
    final g = int.tryParse('${data['generation']}'),
        v = int.tryParse('${data['sourceVersion']}');
    if (uid is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(uid) ||
        a is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(a) ||
        g == null ||
        g < 1 ||
        g > 1000000000 ||
        v == null ||
        v < 1 ||
        data['notificationId'] != '${a}_$g' ||
        data['occurrenceDate'] != null &&
            (data['occurrenceDate'] is! String ||
                !validDate(data['occurrenceDate'] as String))) {
      return null;
    }
    return NotificationTarget(
      uid,
      a,
      g,
      v,
      occurrenceDate: data['occurrenceDate'] as String?,
    );
  }
}

int notificationNumber(String id) {
  var hash = 2166136261;
  for (final c in id.codeUnits) {
    hash = ((hash ^ c) * 16777619) & 0x7fffffff;
  }
  return hash;
}

class RumaNotifications extends ChangeNotifier with WidgetsBindingObserver {
  RumaNotifications(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final messaging = FirebaseMessaging.instance;
  final local = FlutterLocalNotificationsPlugin();
  final preferences = SharedPreferencesAsync();
  final subscriptions = <StreamSubscription<dynamic>>[];
  String installation = '', error = '';
  bool enabled = false,
      allowed = false,
      busy = false,
      _closed = false,
      _suspended = false;
  NotificationTarget? pending;
  String? _activeUid;
  Future<void> _serial = Future.value();
  Future<void> _snoozeSerial = Future.value();
  void changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() async {
    await messaging.setAutoInitEnabled(false);
    installation =
        await preferences.getString('ruma_notification_installation') ??
        db.collection('devices').doc().id;
    await preferences.setString('ruma_notification_installation', installation);
    enabled = await preferences.getBool('ruma_notifications_enabled') ?? false;
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_ruma'),
      ),
      onDidReceiveNotificationResponse: (response) {
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(response.payload ?? '{}') as Map,
          );
          if (response.actionId == 'snooze') {
            final t = NotificationTarget.parse(data);
            if (t != null) unawaited(snooze(t));
          } else {
            open(data);
          }
        } catch (_) {}
      },
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'ruma_agenda_v1',
            'Pengingat agenda',
            description: 'Kegiatan dan deadline Ruma',
            importance: Importance.high,
          ),
        );
    subscriptions.add(auth.authStateChanges().listen((_) => queueSync()));
    subscriptions.add(
      // HTTP v1 uses registration tokens; migrate this adapter when the server adopts FID targets.
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(
        (_) => queueSync(),
        onError: (Object _) {
          error = 'Token notifikasi belum diperbarui.';
          changed();
        },
      ),
    );
    subscriptions.add(
      FirebaseMessaging.onMessage.listen(
        (message) => unawaited(foreground(message.data)),
      ),
    );
    subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => open(message.data),
      ),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) open(initial.data);
    final launch = await local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      try {
        open(
          Map<String, dynamic>.from(
            jsonDecode(launch!.notificationResponse!.payload!) as Map,
          ),
        );
      } catch (_) {}
    }
    WidgetsBinding.instance.addObserver(this);
    await queueSync();
    if (launch?.notificationResponse?.actionId == 'snooze') {
      try {
        final t = NotificationTarget.parse(
          Map<String, dynamic>.from(
            jsonDecode(launch!.notificationResponse!.payload!),
          ),
        );
        if (t != null) await snooze(t);
      } catch (_) {}
    }
  }

  Future<void> queueSync() {
    _serial = _serial.then((_) => sync()).catchError((Object _) {
      error = 'Pendaftaran notifikasi belum tersambung. Coba lagi.';
      changed();
    });
    return _serial;
  }

  Future<void> sync() async {
    if (_closed) return;
    final uid = auth.currentUser?.uid;
    if (_activeUid != uid) {
      await _snoozeSerial;
      await local.cancelAll();
      _activeUid = uid;
      _suspended = false;
    }
    final settings = await messaging.getNotificationSettings();
    allowed = settings.authorizationStatus == AuthorizationStatus.authorized;
    if (uid != null && enabled && !allowed) {
      await local.cancelAll();
      await db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(installation)
          .delete()
          .timeout(const Duration(seconds: 8));
    }
    if (uid == null || !enabled || !allowed || _suspended) {
      changed();
      return;
    }
    await messaging.setAutoInitEnabled(true);
    // HTTP v1 sender requires a registration token, not a FID.
    // ignore: deprecated_member_use
    final token = await messaging.getToken().timeout(
      const Duration(seconds: 15),
    );
    if (_closed ||
        auth.currentUser?.uid != uid ||
        !enabled ||
        _suspended ||
        token == null) {
      return;
    }
    await db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(installation)
        .set({
          'token': token,
          'enabled': true,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    if (_suspended || !enabled || auth.currentUser?.uid != uid) {
      try {
        await db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(installation)
            .delete();
      } catch (_) {}
      return;
    }
    await reconcileSnoozes();
    error = '';
    changed();
  }

  Future<bool> setEnabled(bool value) async {
    if (busy) return false;
    busy = true;
    error = '';
    changed();
    try {
      if (value) {
        final settings = await messaging.requestPermission();
        allowed =
            settings.authorizationStatus == AuthorizationStatus.authorized;
        if (!allowed) {
          error = 'Izin belum diberikan. Aktifkan lewat Pengaturan Android.';
          return false;
        }
      }
      enabled = value;
      if (value) _suspended = false;
      await preferences.setBool('ruma_notifications_enabled', value);
      if (value) {
        await queueSync();
      } else {
        await unregister();
      }
      return error.isEmpty;
    } catch (_) {
      error = 'Notifikasi belum dapat diperbarui. Coba lagi.';
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> unregister() async {
    _suspended = true;
    try {
      await _serial.timeout(const Duration(seconds: 3));
    } catch (_) {}
    final uid = auth.currentUser?.uid;
    await _snoozeSerial;
    await local.cancelAll();
    await preferences.remove('ruma_snoozes');
    pending = null;
    if (uid != null && installation.isNotEmpty) {
      try {
        await db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(installation)
            .delete()
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        error = 'Perangkat belum dilepas dari server. Detail akun lama tetap dilindungi.';
      }
    }
    await messaging.setAutoInitEnabled(false);
    try {
      // Clear the same legacy registration token used by HTTP v1.
      // ignore: deprecated_member_use
      await messaging.deleteToken().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  void open(Map<String, dynamic> data) {
    final target = NotificationTarget.parse(data);
    if (target == null) return;
    pending = target;
    changed();
  }

  NotificationTarget? takePending() {
    final target = pending;
    pending = null;
    return target;
  }

  Future<void> foreground(Map<String, dynamic> data) async {
    final target = NotificationTarget.parse(data), uid = auth.currentUser?.uid;
    if (target == null || target.uid != uid || !enabled || !allowed) return;
    try {
      if (await _anchor(target) == null) return;
      await local.show(
        id: notificationNumber(target.id),
        title: 'Pengingat Ruma',
        body: 'Ada agenda yang perlu kamu cek',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'ruma_agenda_v1',
            'Pengingat agenda',
            importance: Importance.high,
            priority: Priority.high,
            tag: target.id,
            actions: const [
              AndroidNotificationAction(
                'snooze',
                'Ingatkan 5 menit lagi',
                showsUserInterface: true,
              ),
            ],
          ),
        ),
        payload: jsonEncode(target.toJson()),
      );
    } catch (_) {
      error = 'Notifikasi diterima; detail dapat dibuka dari Agenda.';
      changed();
    }
  }

  Future<(DateTime, int)?> _anchor(NotificationTarget t, {int? guard}) async {
    final uid = auth.currentUser?.uid;
    if (uid != t.uid || !enabled || !allowed || _suspended || _closed) {
      return null;
    }
    final user = db.collection('users').doc(uid);
    final source = await user
        .collection('agenda')
        .doc(t.agendaId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    final job = await user
        .collection('reminders')
        .doc(t.agendaId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    final a = source.data(), j = job.data();
    if (auth.currentUser?.uid != uid ||
        _suspended ||
        !enabled ||
        a == null ||
        a['deletedAt'] != null ||
        a['status'] != 'planned' ||
        a['version'] != t.sourceVersion ||
        j?['enabled'] != true ||
        guard != null && j?['generation'] != guard) {
      return null;
    }
    DateTime? anchor;
    if (a['recurrence']?['type'] == 'weekly') {
      if (t.occurrenceDate == null ||
          t.generation > (j!['generation'] as int)) {
        return null;
      }
      final input = AgendaInput(
        title: a['title'],
        kind: a['kind'],
        durationMinutes: a['durationMinutes'],
        startAtUtc: (a['startAtUtc'] as Timestamp).toDate().toUtc(),
        status: a['status'],
        recurrence: Map<String, dynamic>.from(a['recurrence']),
      );
      final m = weeklyMeeting(
        AgendaItem(id: t.agendaId, version: t.sourceVersion, input: input),
        t.occurrenceDate!,
      );
      if (m?.input.status != 'planned') return null;
      anchor = m!.input.startAtUtc;
    } else {
      if (j?['generation'] != t.generation) return null;
      anchor = ((a['startAtUtc'] ?? a['deadlineAtUtc']) as Timestamp?)
          ?.toDate()
          .toUtc();
    }
    if (anchor == null || !anchor.isAfter(DateTime.now().toUtc())) return null;
    return (anchor, j!['generation'] as int);
  }

  Future<bool> snoozeAgenda(AgendaItem item) async {
    final k = occurrenceKey(item.id),
        id = k?.$1 ?? item.id,
        uid = auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final j = await db
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .doc(id)
          .get(const GetOptions(source: Source.server));
      if (j.data()?['enabled'] != true) throw StateError('reminder_off');
      return await snooze(
        NotificationTarget(
          uid,
          id,
          j.data()!['generation'] as int,
          item.version,
          occurrenceDate: k?.$2,
        ),
      );
    } catch (_) {
      error = 'Aktifkan pengingat kegiatan dahulu, lalu coba lagi.';
      changed();
      return false;
    }
  }

  Future<List<dynamic>> _snoozes() async =>
      jsonDecode(await preferences.getString('ruma_snoozes') ?? '[]')
          as List<dynamic>;
  Future<void> _schedule(NotificationTarget t, DateTime due) =>
      local.zonedSchedule(
        id: notificationNumber('snooze_${t.uid}_${t.id}'),
        scheduledDate: tz.TZDateTime.from(due, tz.UTC),
        title: 'Pengingat Ruma',
        body: 'Ada agenda yang perlu kamu cek',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'ruma_agenda_v1',
            'Pengingat agenda',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode(t.toJson()),
      );
  Future<bool> snooze(NotificationTarget t) async {
    var ok = false;
    _snoozeSerial = _snoozeSerial
        .then((_) async {
          try {
            final valid = await _anchor(t),
                due = DateTime.now().toUtc().add(const Duration(minutes: 5));
            if (valid == null || !due.isBefore(valid.$1)) {
              throw StateError('stale');
            }
            final queue = await _snoozes();
            queue.removeWhere(
              (v) =>
                  v['target']['uid'] == t.uid &&
                  v['target']['notificationId'] == t.id,
            );
            if (queue.length >= 20) throw StateError('limit');
            if (auth.currentUser?.uid != t.uid || _suspended || !enabled) {
              return;
            }
            queue.add({
              'target': t.toJson(),
              'due': due.toIso8601String(),
              'guard': valid.$2,
            });
            await preferences.setString('ruma_snoozes', jsonEncode(queue));
            await _schedule(t, due);
            error = '';
            ok = true;
          } catch (_) {
            error = 'Pengingat 5 menit belum dijadwalkan. Periksa izin, koneksi, atau waktu kegiatan.';
          }
          changed();
        })
        .catchError((Object _) {
          error = 'Pengingat lokal belum tersambung.';
          changed();
        });
    await _snoozeSerial;
    return ok;
  }

  Future<void> reconcileSnoozes() {
    _snoozeSerial = _snoozeSerial
        .then((_) async {
          try {
            final queue = await _snoozes(), keep = <dynamic>[];
            for (final v in queue.take(20)) {
              final t = NotificationTarget.parse(
                    Map<String, dynamic>.from(v['target']),
                  ),
                  due = DateTime.tryParse(v['due'] as String);
              if (t == null) continue;
              final valid =
                  t.uid == auth.currentUser?.uid &&
                      enabled &&
                      allowed &&
                      !_suspended &&
                      due != null &&
                      due.isAfter(DateTime.now().toUtc())
                  ? await _anchor(t, guard: v['guard'] as int)
                  : null;
              if (valid == null) {
                await local.cancel(
                  id: notificationNumber('snooze_${t.uid}_${t.id}'),
                );
              } else {
                await _schedule(t, due!);
                keep.add(v);
              }
            }
            await preferences.setString('ruma_snoozes', jsonEncode(keep));
          } catch (_) {
            await local.cancelAll();
            await preferences.remove('ruma_snoozes');
          }
        })
        .catchError((Object _) {
          error = 'Pengingat lokal belum tersambung. Coba buka ulang aplikasi.';
          changed();
        });
    return _snoozeSerial;
  }

  Future<void> openSettings() =>
      const MethodChannel('id.ruma.app/settings')
          .invokeMethod<void>('notifications');
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(queueSync());
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
