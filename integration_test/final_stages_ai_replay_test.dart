import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/features/assistant/assistant_page.dart';

import 'dart:convert';
import 'dart:io';

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

// Only localhost replay; never calls the Worker or provider.
class ReplayService extends AssistantService {
  ReplayService(super.auth);
  @override
  Future<Map<String, dynamic>> propose(String message, String requestId) async {
    if (message != 'Besok baca jurnal. Tadi makan 18 ribu.') {
      throw StateError('fixture mismatch');
    }
    final c = HttpClient();
    try {
      final r = await (await c.getUrl(
        Uri.parse('http://127.0.0.1:8766/worker-replay'),
      )).close();
      if (r.statusCode != 200) throw StateError('replay unavailable');
      final m =
          jsonDecode(await utf8.decoder.bind(r).join()) as Map<String, dynamic>;
      return parseAssistantResponse({...m, 'requestId': requestId}, requestId);
    } finally {
      c.close(force: true);
    }
  }
}

// Approved second additional account; zero model/FCM requests.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'captured response clarification persists safely on production SDK',
    (t) async {
      if (RumaFirebaseOptions.useEmulator ||
          !const bool.fromEnvironment('FINAL_STAGES_REPLAY_TESTS')) {
        throw StateError('Fresh diagnostic approval required');
      }
      final session = await initializeSession(),
          auth = FirebaseAuth.instance,
          db = initializeAgendaDatabase();
      final uids = <String>[], deleted = <String>[], cases = <String>[];
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
          ReplayService(auth),
          agenda,
          finance,
          persistent: true,
          settings: settings,
        );
        await assistant.load();
        assistant.consent = true;
        const text = 'Besok baca jurnal. Tadi makan 18 ribu.';
        assistant.input = text;
        report['modelCalls'] = 0;
        report['usesCapturedResponseReplay'] = true;
        await assistant.send(text);
        expect(assistant.error, isEmpty, reason: assistant.error);
        expect(assistant.draft, isNull);
        expect(
          assistant.reply,
          'Draf belum lengkap. Perjelas kegiatan atau transaksinya.',
        );
        await assistant.save();
        expect((await repo.user.collection('operations').get()).size, 0);
        expect((await agenda.repository.read()).items, isEmpty);
        expect(
          (await finance.repository.read(financeToday().substring(0, 7)))
              .balance,
          0,
        );
        cases.add(
          'incomplete real model output becomes clarification without agenda, money or receipt mutation',
        );
        assistant.dispose();
        assistant = AssistantStore(
          repo,
          ReplayService(auth),
          agenda,
          finance,
          persistent: true,
          settings: settings,
        );
        await assistant.load();
        expect(assistant.draft, isNull);
        expect(
          assistant.reply,
          'Draf belum lengkap. Perjelas kegiatan atau transaksinya.',
        );
        expect(assistant.consent, false);
        cases.add(
          'clarification restores after reload without automatic model request or commit',
        );
        await t.pumpWidget(
          MaterialApp(
            theme: rumaTheme(),
            locale: const Locale('id'),
            supportedLocales: const [Locale('id')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: AssistantPage(store: assistant, onTab: (_) {}),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.text(assistant.reply));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final c = HttpClient();
        try {
          final r = await (await c.getUrl(
            Uri.parse('http://127.0.0.1:8766/08-ai-clarification'),
          )).close();
          await r.drain<void>();
          expect(r.statusCode, 200);
        } finally {
          c.close(force: true);
        }
        cases.add('native clarification UI has no actionable partial draft');
        report['passed'] = true;
      } finally {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
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
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
