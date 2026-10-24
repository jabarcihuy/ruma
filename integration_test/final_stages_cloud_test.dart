import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/recurrence.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/data/user_settings.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/draft_repository.dart';

// Run only after approval: <=2 synthetic accounts, 1 provider call, 1 FCM attempt.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved final stages cloud smoke', (t) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('FINAL_STAGES_LIVE_TESTS')) {
      throw StateError('Explicit approval opt-in required');
    }
    final session = await initializeSession(),
        auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase(),
        uids = <String>[],
        deleted = <String>[],
        cases = <String>[];
    final report = <String, dynamic>{
      'project': 'mobile-app-3479f',
      'suite': 'final_stages_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'modelCalls': 0,
      'jobsCreated': 0,
      'fcmAttemptBudget': 1,
      'cases': cases,
    };
    binding.reportData = report;
    RumaNotifications? push;
    AssistantStore? assistant;
    UserSettingsStore? settings;
    AgendaItem? source;
    ReminderRepository? reminders;
    Future<void> host(String name) async {
      final c = HttpClient();
      try {
        final r = await (await c.getUrl(
          Uri.parse('http://127.0.0.1:8766/$name'),
        )).close();
        await r.drain<void>();
        expect(r.statusCode, 200);
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
      print('RUMA_FINAL_SYNTHETIC_UID=$uid');
      settings = UserSettingsStore(db, auth);
      await settings.load();
      expect(
        await settings.save(
          const UserSettings(
            study: 'QA sintetis',
            bio: 'Fixture final stages',
            personalize: true,
            duration: 45,
            from: 600,
            to: 720,
          ),
        ),
        true,
      );
      final reload = UserSettingsStore(db, auth);
      await reload.load();
      expect(reload.value.duration, 45);
      reload.dispose();
      cases.add('production profile and preferences persist');
      push = RumaNotifications(db, auth);
      await push.initialize();
      await host('grant-notifications');
      expect(await push.setEnabled(true), true, reason: push.error);
      await t.pumpWidget(
        RumaApp(session: session, firestore: db, notifications: push),
      );
      await t.pumpAndSettle();
      final ar = AgendaRepository(db, auth),
          fr = FinanceRepository(db, auth),
          id = ar.newId(),
          start = DateTime.now().toUtc().add(const Duration(minutes: 30));
      await ar.save(
        AgendaMutation(
          operationId: ar.newId(),
          id: id,
          input: AgendaInput(
            title: 'QA seri mingguan',
            kind: 'class',
            durationMinutes: 5,
            startAtUtc: start,
            recurrence: weeklyPattern(start),
          ),
        ),
      );
      final raw = (await ar.read()).series.single,
          origin = raw.input.recurrence!['originDate'] as String;
      source = weeklyMeeting(raw, origin)!;
      reminders = ReminderRepository(db, auth);
      await reminders.configure(source, true, 60);
      report['jobsCreated'] = 1;
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      DateTime? attemptAt;
      bool arrived = false;
      while (DateTime.now().isBefore(deadline)) {
        final j = await reminders.read(id);
        final inbox = await db
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc('${id}_1')
            .get(const GetOptions(source: Source.server));
        if (inbox.exists) {
          expect(inbox['occurrenceDate'], origin);
          expect(j!['generation'], 2);
          expect(j['occurrenceDate'], isNot(origin));
          arrived = true;
          break;
        }
        final attempts = j?['attempts'] as int? ?? 0;
        if (attempts >= 1) {
          attemptAt ??= DateTime.now();
          if (j?['status'] == 'queued' ||
              DateTime.now().difference(attemptAt).inSeconds > 30) {
            throw StateError('single_fcm_attempt_budget_reached');
          }
        }
        if (['failed', 'expired', 'cancelled'].contains(j?['status'])) {
          throw StateError('dispatch_not_sent');
        }
        await t.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      expect(
        arrived,
        true,
        reason: 'One approved recurring FCM must finish before timeout',
      );
      for (var i = 0; i < 20; i++) {
        if ((await push.local.getActiveNotifications()).any(
          (n) => n.id == notificationNumber('${id}_1'),
        )) {
          break;
        }
        await t.pump(const Duration(milliseconds: 200));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(
        (await push.local.getActiveNotifications()).any(
          (n) => n.id == notificationNumber('${id}_1'),
        ),
        true,
      );
      await host('01-recurring-fcm');
      report['fcmSendsObserved'] = 1;
      cases.add('real FCM foreground and next recurring cursor verified');
      expect(
        await push.snooze(
          NotificationTarget(uid, id, 1, raw.version, occurrenceDate: origin),
        ),
        true,
      );
      expect((await push.local.pendingNotificationRequests()).length, 1);
      await ar.save(
        AgendaMutation(
          operationId: ar.newId(),
          id: source.id,
          originalVersion: raw.version,
          input: source.input.withStatus('completed'),
        ),
      );
      await push.reconcileSnoozes();
      expect(await push.local.pendingNotificationRequests(), isEmpty);
      cases.add('production occurrence edit invalidates local snooze');
      final repo = DraftRepository(db, auth),
          agenda = AgendaStore(ar),
          finance = FinanceStore(fr);
      assistant = AssistantStore(
        repo,
        AssistantService(auth),
        agenda,
        finance,
        persistent: true,
        settings: settings,
      );
      await assistant.load();
      assistant.consent = true;
      const text = 'Besok baca jurnal. Tadi makan 18 ribu.';
      assistant.input = text;
      report['modelCalls'] = 1;
      await assistant.send(text);
      expect(assistant.error, isEmpty, reason: assistant.error);
      expect(assistant.draft, isNotNull);
      expect(
        assistant.draft!.items
            .where((e) => e.agenda != null)
            .single
            .agenda!
            .durationMinutes,
        45,
      );
      await assistant.save();
      expect(assistant.error, isEmpty);
      expect((await fr.read(financeToday().substring(0, 7))).balance, -18000);
      final count = (await repo.user.collection('operations').get()).size;
      await assistant.save();
      expect((await repo.user.collection('operations').get()).size, count);
      cases.add(
        'one real AI call respects preferences and approved mixed commit is not duplicated',
      );
      assistant.dispose();
      assistant = null;
      agenda.dispose();
      finance.dispose();
      final latest = (await ar.read()).series.single;
      await reminders.configure(weeklyMeeting(latest, origin)!, false, 60);
      source = null;
      await push.unregister();
      push.dispose();
      push = null;
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await auth.currentUser!.delete();
      deleted.add(uid);
      await auth.signInAnonymously();
      final other = auth.currentUser!.uid;
      uids.add(other);
      // ignore: avoid_print
      print('RUMA_FINAL_SYNTHETIC_UID=$other');
      await expectLater(
        db
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('personal')
            .get(const GetOptions(source: Source.server)),
        throwsA(isA<FirebaseException>()),
      );
      final fresh = UserSettingsStore(db, auth);
      await fresh.load();
      expect(fresh.value.study, isEmpty);
      fresh.dispose();
      cases.add('cross-account profile and preferences remain isolated');
      report['passed'] = true;
    } finally {
      if (source != null && reminders != null) {
        try {
          final r = await AgendaRepository(db, auth).read();
          final s = r.series
              .where((a) => a.id == occurrenceKey(source!.id)?.$1)
              .firstOrNull;
          if (s != null) {
            await reminders.configure(
              weeklyMeeting(s, s.input.recurrence!['originDate'])!,
              false,
              60,
            );
          }
        } catch (_) {}
      }
      assistant?.dispose();
      settings?.dispose();
      if (push != null) {
        await push.unregister();
        push.dispose();
      }
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      final u = auth.currentUser;
      if (u != null && uids.contains(u.uid)) {
        await u.delete();
        deleted.add(u.uid);
      }
      await auth.signOut();
      session.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
