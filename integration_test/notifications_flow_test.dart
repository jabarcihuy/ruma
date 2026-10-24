import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';
import 'package:ruma/features/notifications/notification_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native reminder settings, atomic reschedule/cancel and guarded tap',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError('Local demo-ruma only');
      }
      final session = await initializeSession(), auth = FirebaseAuth.instance;
      await auth.signOut();
      await session.enterTemporarily();
      final db = initializeAgendaDatabase(),
          a = AgendaRepository(db, auth),
          r = ReminderRepository(db, auth);
      final push = RumaNotifications(db, auth)
        ..enabled = true
        ..allowed = true;
      final id = a.newId(),
          start = DateTime.now().toUtc().add(const Duration(hours: 2));
      final cases = <String>[];
      binding.reportData = {
        'project': 'demo-ruma',
        'productionWrites': 0,
        'modelCalls': 0,
        'fcmSends': 0,
        'cases': cases,
      };
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final c = HttpClient();
        try {
          final q = await c.getUrl(Uri.parse('http://127.0.0.1:8766/$name'));
          final response = await q.close();
          await response.drain<void>();
          expect(response.statusCode, 200);
        } finally {
          c.close(force: true);
        }
      }

      Future<void> waitDetail() async {
        for (
          var i = 0;
          i < 50 && find.byType(AgendaDetailPage).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.byType(AgendaDetailPage), findsOneWidget);
      }

      Future<void> tap(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      try {
        await push.local.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_ruma'),
          ),
        );
        await push.local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'ruma_agenda_v1',
                'Pengingat agenda',
                importance: Importance.high,
              ),
            );
        final permissionClient = HttpClient();
        try {
          final response = await (await permissionClient.getUrl(
            Uri.parse('http://127.0.0.1:8766/grant-notifications'),
          )).close();
          await response.drain<void>();
          expect(response.statusCode, 200);
        } finally {
          permissionClient.close(force: true);
        }
        final canShow = await push.local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled();
        expect(
          canShow,
          true,
          reason: 'Grant POST_NOTIFICATIONS only on synthetic AVD before this suite',
        );
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            input: AgendaInput(
              title: 'QA presentasi',
              startAtUtc: start,
              durationMinutes: 30,
            ),
          ),
        );
        var item = (await a.read()).items.single;
        await r.configure(item, true, 10);
        final first = (await r.read(id))!;
        expect(first['status'], 'queued');
        expect(first['generation'], 1);
        await r.configure(item, true, 10);
        expect((await r.read(id))!['generation'], 1);
        await tester.pumpWidget(
          RumaApp(session: session, firestore: db, notifications: push),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tab-4')));
        await tester.pumpAndSettle();
        await tap(find.text('Notifikasi'));
        expect(find.byType(NotificationsPage), findsOneWidget);
        await capture('01-notification-settings');
        Navigator.of(tester.element(find.byType(NotificationsPage))).pop();
        await tester.pumpAndSettle();
        push.open({
          'uid': r.uid,
          'agendaId': id,
          'generation': '1',
          'sourceVersion': '1',
          'notificationId': '${id}_1',
        });
        await waitDetail();
        await tap(find.text('Atur pengingat'));
        expect(find.byType(ReminderPage), findsOneWidget);
        await capture('02-reminder-settings');
        await tap(find.byKey(const ValueKey('reminder-save')));
        expect(find.byType(AgendaDetailPage), findsOneWidget);
        cases.add('configuration and no-op save; tap opens correct agenda');
        final moved = AgendaInput(
          title: item.input.title,
          startAtUtc: start.add(const Duration(hours: 1)),
          durationMinutes: 30,
        );
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            originalVersion: item.version,
            input: moved,
          ),
        );
        final updated = (await r.read(id))!;
        expect(updated['sourceVersion'], 2);
        expect(updated['generation'], 2);
        expect(updated['status'], 'queued');
        item = (await a.read()).items.single;
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            originalVersion: item.version,
            input: item.input.withStatus('completed'),
          ),
        );
        expect((await r.read(id))!['status'], 'cancelled');
        item = (await a.read()).items.single;
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            originalVersion: item.version,
            input: item.input.withStatus('planned'),
          ),
        );
        expect((await r.read(id))!['status'], 'queued');
        item = (await a.read()).items.single;
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            originalVersion: item.version,
            input: item.input,
            delete: true,
          ),
        );
        expect((await r.read(id))!['status'], 'cancelled');
        await a.save(
          AgendaMutation(
            operationId: a.newId(),
            id: id,
            originalVersion: item.version + 1,
            input: item.input,
            restore: true,
          ),
        );
        final restored = (await r.read(id))!;
        expect(restored['status'], 'queued');
        expect(restored['sourceVersion'], 6);
        cases.add('move/complete/reopen/delete/restore update job atomically');
        Navigator.of(tester.element(find.byType(AgendaDetailPage))).pop();
        await tester.pumpAndSettle();
        final target = {
          'uid': r.uid,
          'agendaId': id,
          'generation': '${restored['generation']}',
          'sourceVersion': '6',
          'notificationId': '${id}_${restored['generation']}',
        };
        await push.foreground(target);
        await push.foreground(target);
        final active = await push.local.getActiveNotifications();
        expect(
          active
              .where(
                (x) => x.id == notificationNumber(target['notificationId']!),
              )
              .length,
          1,
        );
        cases.add(
          'foreground local display replaces same stable ID without duplicate card',
        );
        push.open({
          'uid': r.uid,
          'agendaId': id,
          'generation': '1',
          'sourceVersion': '1',
          'notificationId': '${id}_1',
        });
        await tester.pumpAndSettle();
        await waitDetail();
        expect(
          find.text('Jadwal sudah diperbarui. Ini keadaan terbaru.'),
          findsOneWidget,
        );
        await capture('03-stale-notification-detail');
        Navigator.of(tester.element(find.byType(AgendaDetailPage))).pop();
        await tester.pumpAndSettle();
        push.open({...target, 'uid': 'other-account'});
        await tester.pumpAndSettle();
        expect(find.byType(AgendaDetailPage), findsNothing);
        cases.add(
          'stale payload opens latest state; another UID cannot open detail',
        );
        binding.reportData!['passed'] = true;
      } finally {
        await push.local.cancelAll();
        await tester.pumpWidget(const SizedBox());
        push.dispose();
        await auth.currentUser?.delete();
        session.dispose();
      }
    },
  );
}
