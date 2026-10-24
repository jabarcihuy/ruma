import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';

// Explicitly approved synthetic AVD only; two jobs, one device, no model calls.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real FCM foreground and background tap', (tester) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('NOTIFICATIONS_LIVE_TESTS')) {
      throw StateError('Explicit production test opt-in required');
    }
    final session = await initializeSession();
    final auth = FirebaseAuth.instance, db = initializeAgendaDatabase();
    final uids = <String>[], deleted = <String>[], cases = <String>[];
    final report = <String, dynamic>{
      'project': 'mobile-app-3479f',
      'suite': 'notifications_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'cases': cases,
      'modelCalls': 0,
      'jobsCreated': 0,
    };
    binding.reportData = report;
    RumaNotifications? push;
    Future<void> host(String path) async {
      final c = HttpClient();
      try {
        final res = await (await c.getUrl(
          Uri.parse('http://127.0.0.1:8766/$path'),
        )).close();
        await res.drain<void>();
        expect(res.statusCode, 200);
      } finally {
        c.close(force: true);
      }
    }

    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      uids.add(uid);
      // ignore: avoid_print
      print('RUMA_NOTIFICATION_SYNTHETIC_UID=$uid');
      push = RumaNotifications(db, auth);
      await push.initialize();
      await host('grant-notifications');
      expect(await push.setEnabled(true), true, reason: push.error);
      final devices = await db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .get();
      expect(devices.size, 1);
      expect(devices.docs.single['enabled'], true);
      cases.add('production device registration');
      await tester.pumpWidget(
        RumaApp(session: session, firestore: db, notifications: push),
      );
      await tester.pumpAndSettle();
      final a = AgendaRepository(db, auth), r = ReminderRepository(db, auth);
      Future<String> create(String title) async {
        final id = a.newId();
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            input: AgendaInput(
              title: title,
              startAtUtc: DateTime.now().toUtc().add(
                Duration(minutes: 30 + (report['jobsCreated'] as int) * 10),
              ),
              durationMinutes: 5,
            ),
          ),
        );
        final item = (await a.read()).items.singleWhere((x) => x.id == id);
        await r.configure(item, true, 60);
        report['jobsCreated'] = (report['jobsCreated'] as int) + 1;
        return id;
      }

      Future<void> waitSent(String id) async {
        final deadline = DateTime.now().add(const Duration(minutes: 12));
        while (DateTime.now().isBefore(deadline)) {
          final job = await r.read(id);
          if (job?['status'] == 'sent') return;
          final all = await db
              .collection('users')
              .doc(uid)
              .collection('reminders')
              .get();
          if (all.docs.fold<int>(
                0,
                (n, d) => n + (d.data()['attempts'] as int),
              ) >=
              3) {
            throw StateError('approved_fcm_attempt_budget_reached');
          }
          if (['failed', 'expired'].contains(job?['status'])) {
            throw StateError('dispatch_${job?['status']}_${job?['lastError']}');
          }
          await tester.pump(const Duration(seconds: 2));
          await Future<void>.delayed(const Duration(seconds: 3));
        }
        throw StateError('dispatch_timeout');
      }

      if (!const bool.fromEnvironment('FCM_BACKGROUND_ONLY')) {
        final first = await create('QA FCM foreground');
        await waitSent(first);
        for (var i = 0; i < 30; i++) {
          final active = await push.local.getActiveNotifications();
          if (active.any((n) => n.id == notificationNumber('${first}_1'))) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(
          (await push.local.getActiveNotifications()).any(
            (n) => n.id == notificationNumber('${first}_1'),
          ),
          true,
        );
        await host('01-real-fcm-foreground');
        cases.add('real FCM foreground callback displays Android notification');
        await push.local.cancelAll();
      }
      final second = await create('QA FCM background');
      await host('background-and-tap/$second');
      await waitSent(second);
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.byType(AgendaDetailPage).evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(find.byType(AgendaDetailPage), findsOneWidget);
      expect(find.text('QA FCM background'), findsWidgets);
      await host('03-real-fcm-tap-detail');
      cases.add('real FCM background notification tapped to matching agenda');
      final inbox = await db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      expect(
        inbox.size,
        const bool.fromEnvironment('FCM_BACKGROUND_ONLY') ? 1 : 2,
      );
      report['inboxCount'] = inbox.size;
      final jobs = await db
          .collection('users')
          .doc(uid)
          .collection('reminders')
          .get();
      report['jobAttempts'] = jobs.docs.fold<int>(
        0,
        (n, d) => n + (d.data()['attempts'] as int),
      );
      report['passed'] = true;
    } finally {
      if (auth.currentUser != null && uids.contains(auth.currentUser!.uid)) {
        final a = AgendaRepository(db, auth), r = ReminderRepository(db, auth);
        final before = await db
            .collection('users')
            .doc(auth.currentUser!.uid)
            .collection('reminders')
            .get();
        report['dispatchBeforeCleanup'] = before.docs
            .map(
              (d) => {
                'agendaId': d.id,
                'attempts': d.data()['attempts'],
                'status': d.data()['status'],
                'results': d.data()['deviceResults'],
              },
            )
            .toList();
        for (final item in (await a.read()).items) {
          if (await r.read(item.id) != null) await r.configure(item, false, 10);
        }
      }
      if (push != null) {
        await push.setEnabled(false);
        push.dispose();
      }
      final u = auth.currentUser;
      if (u != null && uids.contains(u.uid)) {
        await u.delete();
        deleted.add(u.uid);
      }
      await auth.signOut();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
