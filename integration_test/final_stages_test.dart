import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/recurrence.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/data/user_settings.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/features/profile/profile_page.dart';
import 'package:ruma/features/profile/personal_settings_page.dart';
import 'package:ruma/features/agenda/agenda_form.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';

class LocalApi extends Fake implements AssistantService {
  late Map<String, dynamic> response;
  @override
  Future<Map<String, dynamic>> propose(String message, String id) async =>
      response;
  @override
  void dispose() {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'final stages real SDK profile, recurring scope, snooze and agent regression',
    (t) async {
      if (!RumaFirebaseOptions.useEmulator) throw StateError('demo-ruma only');
      final session = await initializeSession(),
          auth = FirebaseAuth.instance,
          db = initializeAgendaDatabase(),
          cases = <String>[],
          screens = <String>[];
      binding.reportData = {
        'project': 'demo-ruma',
        'modelCalls': 0,
        'fcmSends': 0,
        'productionWrites': 0,
        'cases': cases,
        'screens': screens,
      };
      Future<void> rpc(String name) async {
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

      Future<void> shot(String name) async {
        expect(t.takeException(), isNull);
        await rpc(name);
        screens.add(name);
      }

      Future<void> wait(bool Function() done) async {
        for (var i = 0; i < 200 && !done(); i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(done(), true);
        await t.pumpAndSettle();
      }

      Future<void> tap(String text) async {
        await t.ensureVisible(find.text(text));
        await t.pumpAndSettle();
        await t.tap(find.text(text));
        await t.pumpAndSettle();
      }

      UserSettingsStore? settings;
      RumaNotifications? push;
      AssistantStore? assistant;
      try {
        await auth.signOut();
        await auth.signInAnonymously();
        final uid = auth.currentUser!.uid;
        final ar = AgendaRepository(db, auth), fr = FinanceRepository(db, auth);
        settings = UserSettingsStore(db, auth);
        await settings.load();
        expect(settings.ready, true);
        expect(
          await settings.save(
            const UserSettings(
              bio: 'Data sintetis QA',
              study: 'Teknik Informatika',
              avatar: 'sage',
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
        expect(reload.value.study, 'Teknik Informatika');
        expect(reload.value.duration, 45);
        reload.dispose();
        cases.add('profile and preferences persist per UID');
        final now = DateTime.now().toUtc(),
            start = now.add(const Duration(hours: 2)),
            id = ar.newId();
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: id,
            input: AgendaInput(
              title: 'Kuliah QA',
              kind: 'class',
              startAtUtc: start,
              recurrence: weeklyPattern(start),
            ),
          ),
        );
        var snapshot = await ar.read(), raw = snapshot.series.single;
        final original = raw.input.recurrence!['originDate'] as String,
            first = weeklyMeeting(raw, original)!;
        await expectLater(
          ar.save(
            AgendaMutation(
              operationId: ar.newId(),
              id: ar.newId(),
              input: AgendaInput(
                title: 'Bentrok QA',
                startAtUtc: start.add(const Duration(minutes: 15)),
              ),
            ),
          ),
          throwsA(isA<AgendaFailure>()),
        );
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: first.id,
            originalVersion: first.version,
            input: agendaCopy(
              first.input,
              start: start.add(const Duration(hours: 1)),
            ),
          ),
        );
        raw = (await ar.read()).series.single;
        expect(weeklyMeeting(raw, original)!.id, first.id);
        expect(
          weeklyMeeting(
            raw,
            original,
          )!.input.startAtUtc!.millisecondsSinceEpoch,
          start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        );
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: first.id,
            originalVersion: raw.version,
            input: first.input,
          ),
        );
        raw = (await ar.read()).series.single;
        final nextDate = dateKey(
              DateTime.parse('${original}T00:00:00Z')
                  .add(const Duration(days: 7)),
            ),
            thirdDate = dateKey(
              DateTime.parse('${original}T00:00:00Z')
                  .add(const Duration(days: 14)),
            );
        final second = weeklyMeeting(raw, nextDate)!;
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: second.id,
            originalVersion: raw.version,
            input: agendaCopy(
              second.input,
              start: second.input.startAtUtc!.add(const Duration(hours: 1)),
            ),
            scope: 'future',
          ),
        );
        raw = (await ar.read()).series.single;
        expect(
          weeklyMeeting(
            raw,
            original,
          )!.input.startAtUtc!.millisecondsSinceEpoch,
          start.millisecondsSinceEpoch,
        );
        expect(
          weeklyMeeting(
            raw,
            thirdDate,
          )!.input.startAtUtc!.millisecondsSinceEpoch,
          start.add(const Duration(days: 14, hours: 1)).millisecondsSinceEpoch,
        );
        final third = weeklyMeeting(raw, thirdDate)!;
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: third.id,
            originalVersion: raw.version,
            input: third.input,
            scope: 'future',
            delete: true,
          ),
        );
        raw = (await ar.read()).series.single;
        expect(weeklyMeeting(raw, thirdDate), isNull);
        expect(weeklyMeeting(raw, original), isNotNull);
        cases.add(
          'weekly create, conflict, stable move/undo, future edit and future cancellation',
        );
        final current = weeklyMeeting(raw, original)!;
        await ReminderRepository(db, auth).configure(current, true, 10);
        push = RumaNotifications(db, auth);
        await push.preferences.setBool('ruma_notifications_enabled', false);
        await push.initialize();
        await rpc('grant-notifications');
        push.enabled = true;
        push.allowed = true;
        expect(await push.snoozeAgenda(current), true);
        expect((await push.local.pendingNotificationRequests()).length, 1);
        await ar.save(
          AgendaMutation(
            operationId: ar.newId(),
            id: current.id,
            originalVersion: raw.version,
            input: current.input.withStatus('cancelled'),
          ),
        );
        await push.reconcileSnoozes();
        expect(await push.local.pendingNotificationRequests(), isEmpty);
        cases.add(
          'Android schedules local snooze and cancels it after occurrence change',
        );
        final api = LocalApi(),
            repo = DraftRepository(db, auth),
            agenda = AgendaStore(ar),
            finance = FinanceStore(fr);
        assistant = AssistantStore(
          repo,
          api,
          agenda,
          finance,
          persistent: true,
          settings: settings,
        );
        await assistant.load();
        assistant.consent = true;
        final tomorrow = dateKey(agendaLocal(now).add(const Duration(days: 1)));
        const source = 'Besok baca jurnal. Tadi makan 18 ribu.';
        api.response = {
          'type': 'draft_proposal',
          'content': 'Draf',
          'items': [
            {
              'action': 'create_agenda',
              'title': 'Baca jurnal',
              'localDate': tomorrow,
              'durationMinutes': 20,
              'amountRupiah': null,
              'transactionType': null,
              'categoryId': null,
              'transactionStatus': null,
              'sourceQuote': 'Besok baca jurnal.',
            },
            {
              'action': 'create_transaction',
              'title': 'Makan',
              'localDate': financeToday(),
              'durationMinutes': null,
              'amountRupiah': 18000,
              'transactionType': 'expense',
              'categoryId': 'food',
              'transactionStatus': 'actual',
              'sourceQuote': 'Tadi makan 18 ribu.',
            },
          ],
        };
        assistant.input = source;
        await assistant.send(source);
        expect(assistant.error, isEmpty);
        expect(assistant.draft!.items.first.agenda!.durationMinutes, 45);
        expect(assistant.availableFrom, 600);
        await assistant.save();
        expect(assistant.error, isEmpty);
        expect((await fr.read(financeToday().substring(0, 7))).balance, -18000);
        final opCount = (await repo.user.collection('operations').get()).size;
        await assistant.save();
        expect((await repo.user.collection('operations').get()).size, opCount);
        assistant.dispose();
        assistant = AssistantStore(
          repo,
          api,
          agenda,
          finance,
          persistent: true,
          settings: settings,
        );
        await assistant.load();
        expect(assistant.draft!.applied, true);
        cases.add(
          'personal default, mixed draft approval, financial aggregate and restored receipt do not duplicate',
        );
        final recurring = (await ar.read()).series.single;
        final target = weeklyMeeting(recurring, nextDate)!;
        final targetDate = dateKey(agendaLocal(target.input.startAtUtc!));
        const changeSource = 'Ubah Kuliah QA jadi 30 menit';
        api.response = {
          'type': 'change_proposal',
          'content': 'Draf',
          'change': {
            'recordType': 'agenda',
            'action': 'update',
            'targetTitle': 'Kuliah QA',
            'targetDate': targetDate,
            'sourceQuote': changeSource,
            'patch': {
              'title': null,
              'durationMinutes': 30,
              'startLocal': null,
              'deadlineLocal': null,
              'status': null,
              'amountRupiah': null,
              'categoryId': null,
              'localDate': null,
            },
          },
        };
        // Consent is intentionally not restored across a new store/session.
        assistant.consent = true;
        await assistant.send(changeSource);
        expect(assistant.error, isEmpty);
        expect(assistant.recordDraft, isNotNull);
        await assistant.saveRecord();
        expect(assistant.error, isEmpty);
        expect(
          weeklyMeeting(
            (await ar.read()).series.single,
            nextDate,
          )!.input.durationMinutes,
          30,
        );
        await assistant.saveRecord(undo: true);
        expect(assistant.error, isEmpty);
        expect(
          weeklyMeeting(
            (await ar.read()).series.single,
            nextDate,
          )!.input.durationMinutes,
          60,
        );
        expect((await fr.read(financeToday().substring(0, 7))).balance, -18000);
        cases.add(
          'agent edits and undoes exact recurring occurrence without changing money',
        );

        await t.pumpWidget(RumaApp(session: session, firestore: db));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('tab-4')));
        await t.pumpAndSettle();
        final profile = t.widget<ProfilePage>(find.byType(ProfilePage));
        await wait(() => profile.settings!.ready);
        expect(find.text('Teknik Informatika'), findsOneWidget);
        await shot('01-profile');
        await tap('Kustomisasi profil');
        await shot('02-profile-form');
        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
        await tap('Preferensi AI');
        await shot('03-personal-preferences');
        await t.enterText(
          find.byKey(const ValueKey('preferred-duration')),
          '50',
        );
        await t.ensureVisible(
          find.byKey(const ValueKey('personal-settings-save')),
        );
        await t.tap(find.byKey(const ValueKey('personal-settings-save')));
        await wait(() => find.byType(PersonalSettingsPage).evaluate().isEmpty);
        expect(await settings.save(const UserSettings()), false);
        await settings.load();
        expect(settings.value.duration, 50);
        cases.add(
          'native forms update preferences and stale editor cannot overwrite newer revision',
        );
        final latest = (await ar.read()).series.single;
        await agenda.load();
        final nav = t.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => AgendaFormPage(store: agenda, existing: latest),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const ValueKey('agenda-weekly')));
        await t.pumpAndSettle();
        await shot('04-weekly-form');
        nav.pop();
        await t.pumpAndSettle();
        final upcoming = weeklyMeeting(latest, nextDate)!;
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => AgendaDetailPage(
              store: agenda,
              id: upcoming.id,
              notifications: push,
            ),
          ),
        );
        await t.pumpAndSettle();
        await tap('Atur seri mingguan');
        await t.ensureVisible(find.text('Batalkan mulai pertemuan ini'));
        await t.pumpAndSettle();
        await shot('05-weekly-scope');
        await tap('Ingatkan 5 menit lagi');
        await wait(
          () => find
              .text('Pengingat lokal dijadwalkan sekitar 5 menit lagi.')
              .evaluate()
              .isNotEmpty,
        );
        expect((await push.local.pendingNotificationRequests()).length, 1);
        cases.add(
          'weekly form, explicit scope and visible snooze action work natively',
        );
        nav.pop();
        await t.pumpAndSettle();
        await push.local.cancelAll();
        await push.preferences.remove('ruma_snoozes');
        assistant.dispose();
        assistant = null;
        agenda.dispose();
        finance.dispose();
        push.dispose();
        push = null;
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await auth.currentUser!.delete();
        await auth.signInAnonymously();
        await expectLater(
          db
              .collection('users')
              .doc(uid)
              .collection('settings')
              .doc('personal')
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()),
        );
        final other = UserSettingsStore(db, auth);
        await other.load();
        expect(other.ready, true);
        expect(other.value.bio, isEmpty);
        other.dispose();
        cases.add('second UID cannot read old profile or inherit preferences');
        binding.reportData!['passed'] = true;
      } finally {
        assistant?.dispose();
        settings?.dispose();
        if (push != null) {
          await push.local.cancelAll();
          await push.preferences.remove('ruma_snoozes');
          push.dispose();
        }
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        await auth.currentUser?.delete();
        await auth.signOut();
        session.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
