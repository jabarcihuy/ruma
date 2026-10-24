import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/user_settings.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/draft_repository.dart';

// Remaining approved budget only: one account, one model call, zero push jobs.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('final stages remaining cloud budget', (t) async {
    const previous = String.fromEnvironment('PREVIOUS_FIXTURE_UID');
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('FINAL_STAGES_LIVE_TESTS') ||
        !RegExp(r'^[A-Za-z0-9_-]{20,128}$').hasMatch(previous)) {
      throw StateError('approved exact fixture required');
    }
    final session = await initializeSession(),
        auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase();
    final uids = <String>[previous],
        deleted = <String>[previous],
        cases = <String>[];
    final report = <String, dynamic>{
      'project': 'mobile-app-3479f',
      'suite': 'final_stages_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'modelCalls': 0,
      'additionalFcmSends': 0,
      'cases': cases,
    };
    binding.reportData = report;
    UserSettingsStore? settings;
    AssistantStore? assistant;
    AgendaStore? agenda;
    FinanceStore? finance;
    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      uids.add(uid);
      // ignore: avoid_print
      print('RUMA_FINAL_SYNTHETIC_UID=$uid');
      settings = UserSettingsStore(db, auth);
      await settings.load();
      expect(settings.ready, true);
      expect(settings.value.study, isEmpty);
      await expectLater(
        db
            .collection('users')
            .doc(previous)
            .collection('settings')
            .doc('personal')
            .get(const GetOptions(source: Source.server)),
        throwsA(isA<FirebaseException>()),
      );
      cases.add('second account defaults and old profile access denied');
      expect(
        await settings.save(
          const UserSettings(
            study: 'QA completion',
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
      cases.add('production profile preferences persist');
      agenda = AgendaStore(AgendaRepository(db, auth));
      finance = FinanceStore(FinanceRepository(db, auth));
      final repo = DraftRepository(db, auth);
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
      expect(assistant.error, isEmpty, reason: assistant.error);
      expect(
        (await finance.repository.read(financeToday().substring(0, 7))).balance,
        -18000,
      );
      final count = (await repo.user.collection('operations').get()).size;
      await assistant.save();
      expect((await repo.user.collection('operations').get()).size, count);
      cases.add(
        'one real AI call applies duration preference and mixed receipt prevents duplicate',
      );
      report['passed'] = true;
    } finally {
      assistant?.dispose();
      settings?.dispose();
      agenda?.dispose();
      finance?.dispose();
      final user = auth.currentUser;
      if (user != null && uids.contains(user.uid)) {
        await user.delete();
        deleted.add(user.uid);
      }
      await auth.signOut();
      session.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
