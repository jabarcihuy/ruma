import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/agent_tools.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';

class LocalAssistant extends AssistantService {
  LocalAssistant(super.auth);
  int calls = 0;
  @override
  Future<Map<String, dynamic>> propose(String message, String requestId, {List<Map<String, String>>? messages, List<Map<String, dynamic>> activeProposal = const [], String? conversationId}) async {
    calls++;
    final date = dateKey(
      agendaLocal(DateTime.now().toUtc()).add(const Duration(days: 1)),
    );
    return {
      'type': 'draft_proposal',
      'content': 'Periksa draf; belum ada catatan yang disimpan.',
      'items': [
        {
          'action': 'create_agenda',
          'title': calls == 1
              ? 'QA belajar tersimpan'
              : 'QA draf setelah restart',
          'localDate': date,
          'durationMinutes': 30,
          'amountRupiah': null,
          'transactionType': null,
          'categoryId': null,
          'transactionStatus': null,
          'sourceQuote': 'Besok belajar QA 30 menit.',
        },
        {
          'action': 'create_transaction',
          'title': 'Makan QA',
          'localDate': dateKey(agendaLocal(DateTime.now().toUtc())),
          'durationMinutes': null,
          'amountRupiah': 18000,
          'transactionType': 'expense',
          'categoryId': 'food',
          'transactionStatus': 'actual',
          'sourceQuote': 'Tadi makan QA 18 ribu.',
        },
      ],
    };
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'durable assistant workspace, receipts, isolation and cold restart fixture',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError('Local demo-ruma only');
      }
      final session = await initializeSession(),
          auth = FirebaseAuth.instance,
          db = initializeAgendaDatabase();
      await auth.signOut();
      await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      const email = 'assistant-memory@ruma.invalid',
          password = 'SyntheticMemory123!';
      await auth.currentUser!.linkWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      final repo = DraftRepository(db, auth),
          a = AgendaStore(AgendaRepository(db, auth)),
          f = FinanceStore(FinanceRepository(db, auth));
      final api = LocalAssistant(auth), cases = <String>[];
      AssistantStore store() =>
          AssistantStore(repo, api, a, f, persistent: true);
      final report = <String, dynamic>{
        'project': 'demo-ruma',
        'productionWrites': 0,
        'modelCalls': 0,
        'fixtureUids': [uid],
        'cases': cases,
      };
      binding.reportData = report;
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final c = HttpClient();
        try {
          final res = await (await c.getUrl(
            Uri.parse('http://127.0.0.1:8766/$name'),
          )).close();
          await res.drain<void>();
          expect(res.statusCode, 200);
        } finally {
          c.close(force: true);
        }
      }

      var s = store();
      await s.load();
      expect(s.ready, true);
      s.consent = true;
      const text = 'Besok belajar QA 30 menit. Tadi makan QA 18 ribu.';
      await s.send(text);
      expect(s.error, isEmpty);
      expect(s.storageError, isEmpty);
      s.change(() => s.draft!.items.last.included = false);
      s.input = 'Teks yang belum dikirim';
      await s.flush();
      final key = s.draft!.requestKey, op = s.draft!.operationId;
      s.dispose();
      s = store();
      await s.load();
      expect(s.input, 'Teks yang belum dikirim');
      expect(s.draft!.requestKey, key);
      expect(s.draft!.operationId, op);
      expect(s.draft!.items.last.included, false);
      expect(api.calls, 1);
      cases.add('draft, selection, typed input and operation IDs restored');
      s.change(() => s.draft!.items.last.included = true);
      await s.flush();
      await repo.apply(s.draft!);
      s.draft!.applied = false;
      await s.flush();
      s.dispose();
      s = store();
      await s.load();
      expect(s.draft!.applied, true);
      await s.save();
      expect((await repo.user.collection('operations').get()).size, 1);
      expect(
        (await f.repository.read(
          dateKey(agendaLocal(DateTime.now().toUtc())).substring(0, 7),
        )).balance,
        -18000,
      );
      cases.add(
        'lost commit ack reconciled from exact receipt; retry adds no records',
      );
      s.discard();
      await s.flush();
      s.dispose();
      s = store();
      await s.load();
      expect(s.history.single['message'], text);
      final item = (await a.repository.read()).items.single;
      s.recordDraft = RecordDraft(
        operationId: repo.newId(),
        delete: false,
        id: item.id,
        version: item.version,
        beforeAgenda: item.input,
        agenda: copyAgenda(item.input, title: 'QA perubahan'),
      );
      await s.flush();
      s.dispose();
      s = store();
      await s.load();
      await s.saveRecord();
      expect(s.error, isEmpty);
      expect(s.recordDraft!.applied, true);
      await s.saveRecord(undo: true);
      expect(s.error, isEmpty);
      s.recordDraft!.undone = false;
      await s.flush();
      s.dispose();
      s = store();
      await s.load();
      expect(s.recordDraft!.undone, true);
      expect(
        (await a.repository.read()).items.single.input.title,
        item.input.title,
      );
      expect((await repo.user.collection('operations').get()).size, 3);
      cases.add(
        'existing-record and undo receipts recover without replaying mutation',
      );
      s.discardRecord();
      await s.flush();
      final stale = store();
      await stale.load();
      s.input = 'Workspace terbaru';
      await s.flush();
      stale.input = 'Workspace lama';
      expect(await stale.flush(), false);
      expect(stale.storageBlocked, true);
      stale.dispose();
      cases.add('stale workspace rejected without overwriting new revision');
      s.dispose();
      final (revision, valid) = await repo.readAssistant();
      await repo.writeAssistant('{', revision);
      s = store();
      await s.load();
      expect(s.ready, false);
      expect(s.storageError, isNotEmpty);
      expect((await repo.readAssistant()).$2, '{');
      s.dispose();
      final (brokenRevision, _) = await repo.readAssistant();
      await repo.writeAssistant(valid!, brokenRevision);
      cases.add(
        'corrupt workspace cannot be interpreted or silently overwritten',
      );
      await auth.signOut();
      await auth.signInAnonymously();
      final other = auth.currentUser!.uid;
      (report['fixtureUids'] as List).add(other);
      await expectLater(repo.readAssistant(), throwsA(anything));
      final own = DraftRepository(db, auth),
          otherStore = AssistantStore(
            own,
            LocalAssistant(auth),
            AgendaStore(AgendaRepository(db, auth)),
            FinanceStore(FinanceRepository(db, auth)),
            persistent: true,
          );
      await otherStore.load();
      expect(otherStore.ready, true);
      expect(otherStore.history, isEmpty);
      expect(otherStore.draft, isNull);
      await auth.currentUser!.delete();
      otherStore.dispose();
      await auth.signInWithEmailAndPassword(email: email, password: password);
      cases.add('account switching does not expose the previous workspace');
      s = store();
      await s.load();
      s.consent = true;
      await s.send(text);
      expect(s.draft, isNotNull);
      s.input = 'Lanjutkan tinjauan setelah restart';
      await s.flush();
      report['coldDraftId'] = s.draft!.id;
      report['coldOperationId'] = s.draft!.operationId;
      report['coldRequestKey'] = s.draft!.requestKey;
      report['expectedOperations'] = 3;
      report['expectedBalance'] = -18000;
      await tester.pumpWidget(RumaApp(session: session, firestore: db));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 150 && find.text('QA draf setelah restart').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(find.text('QA draf setelah restart'), findsWidgets);
      await capture('01-native-restored-review');
      report['passed'] = true;
      report['retainLocalFixtureForColdRestart'] = true;
      s.dispose();
      a.dispose();
      f.dispose();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
