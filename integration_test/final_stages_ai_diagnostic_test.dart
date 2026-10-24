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
import 'package:ruma/data/assistant_draft.dart';

// Test transport preserves the application request shape; only a sanitized error
// code/status is retained, never tokens, request text or provider response bodies.
class DiagnosticService extends AssistantService {
  DiagnosticService(super.auth, this.report);
  final Map<String, dynamic> report;
  @override
  Future<Map<String, dynamic>> propose(String message, String requestId) async {
    check();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final token = await auth.currentUser!.getIdToken().timeout(
        const Duration(seconds: 15),
      );
      check();
      final request = await client.postUrl(Uri.parse(assistantEndpoint));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode({
          'requestId': requestId,
          'conversationId': requestId,
          'turnId': requestId,
          'timezone': 'Asia/Jakarta',
          'clientNow': DateTime.now().toUtc().toIso8601String(),
          'messages': [
            {'role': 'user', 'content': message},
          ],
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 50),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > 131072) {
          throw const DraftFailure('Response exceeds bound');
        }
        bytes.addAll(chunk);
      }
      check();
      report['httpStatus'] = response.statusCode;
      final raw = jsonDecode(utf8.decode(bytes));
      if (response.statusCode != 200) {
        const allowed = [
          'unauthenticated',
          'invalid_request',
          'rate_limited',
          'provider_rate_limited',
          'provider_timeout',
          'provider_unavailable',
          'invalid_model_output',
          'tool_limit',
          'backend_not_configured',
          'backend_unavailable',
          'quota_conflict',
          'request_cancelled',
        ];
        final code = raw is Map && allowed.contains(raw['error'])
            ? raw['error']
            : 'unknown';
        report['errorCode'] = code;
        throw DraftFailure('HTTP ${response.statusCode}: $code');
      }
      return parseAssistantResponse(raw, requestId);
    } finally {
      client.close(force: true);
    }
  }
}

// Do not run without fresh approval for one additional account and AI request.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved single AI diagnostic', (t) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('FINAL_STAGES_AI_DIAGNOSTIC')) {
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
        DiagnosticService(auth, report),
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
