import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';

// No provider calls: typed synthetic draft tests persistence, receipts and Rules.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved cloud assistant memory with two disposable accounts', (
    tester,
  ) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('ASSISTANT_MEMORY_LIVE_TESTS')) {
      throw StateError('Explicit live test opt-in required');
    }
    await initializeSession();
    final auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase(),
        uids = <String>[],
        deleted = <String>[],
        cases = <String>[];
    binding.reportData = {
      'project': 'mobile-app-3479f',
      'suite': 'assistant_memory_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'modelCalls': 0,
      'fcmSends': 0,
      'cases': cases,
    };
    AssistantStore? s;
    AssistantStore make(DraftRepository repo) => AssistantStore(
      repo,
      AssistantService(auth),
      AgendaStore(AgendaRepository(db, auth)),
      FinanceStore(FinanceRepository(db, auth)),
      persistent: true,
    );
    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final uid = auth.currentUser!.uid;
      uids.add(uid);
      // ignore: avoid_print
      print('RUMA_MEMORY_SYNTHETIC_UID=$uid');
      final repo = DraftRepository(db, auth), rev = await repo.revisions();
      s = make(repo);
      await s.load();
      expect(s.ready, true);
      const source = 'Besok belajar QA. Tadi makan QA 18 ribu.';
      final date = dateKey(
        agendaLocal(DateTime.now().toUtc()).add(const Duration(days: 1)),
      );
      s.input = source;
      s.message = source;
      s.reply = 'Tinjau draf sintetis.';
      s.draft = AssistantDraft(
        id: repo.newId(),
        operationId: repo.newId(),
        uid: uid,
        baseAgendaRevision: rev['agenda']!,
        baseFinanceRevision: rev['finance']!,
        items: [
          DraftEntry(
            id: repo.newId(),
            quote: 'Besok belajar QA.',
            localDate: date,
            agenda: const AgendaInput(
              title: 'QA cloud workspace',
              durationMinutes: 30,
            ),
          ),
          DraftEntry(
            id: repo.newId(),
            quote: 'Tadi makan QA 18 ribu.',
            localDate: financeToday(),
            money: TransactionInput(
              type: 'expense',
              amountRupiah: 18000,
              categoryId: 'food',
              localDate: financeToday(),
              description: 'QA makan',
            ),
          ),
        ],
      );
      final key = s.draft!.requestKey, op = s.draft!.operationId;
      expect(await s.flush(), true);
      s.dispose();
      s = make(repo);
      await s.load();
      expect(s.draft!.requestKey, key);
      expect(s.draft!.operationId, op);
      expect(s.input, source);
      await s.save();
      expect(s.error, isEmpty);
      expect(s.storageError, isEmpty);
      s.draft!.applied = false;
      expect(await s.flush(), true);
      s.dispose();
      s = make(repo);
      await s.load();
      expect(s.draft!.applied, true);
      await s.save();
      expect((await repo.user.collection('operations').get()).size, 1);
      expect(
        (await s.finance.repository.read(financeToday().substring(0, 7)))
            .balance,
        -18000,
      );
      cases.add(
        'workspace restore and lost acknowledgement reconcile exactly one batch',
      );
      s.discard();
      expect(await s.flush(), true);
      s.dispose();
      s = make(repo);
      await s.load();
      expect(s.history.single['message'], source);
      expect(s.draft, isNull);
      cases.add('conversation history survives recreated store');
      s.dispose();
      s = null;
      await auth.currentUser!.delete();
      deleted.add(uid);
      await auth.signInAnonymously();
      final other = auth.currentUser!.uid;
      uids.add(other);
      // ignore: avoid_print
      print('RUMA_MEMORY_SYNTHETIC_UID=$other');
      await expectLater(
        db
            .collection('users')
            .doc(uid)
            .collection('assistant')
            .doc('session')
            .get(const GetOptions(source: Source.server)),
        throwsA(anything),
      );
      s = make(DraftRepository(db, auth));
      await s.load();
      expect(s.ready, true);
      expect(s.history, isEmpty);
      expect(s.draft, isNull);
      s.input = 'Workspace akun kedua';
      expect(await s.flush(), true);
      cases.add(
        'other account denied old workspace and receives own empty state',
      );
      binding.reportData!['passed'] = true;
    } finally {
      s?.dispose();
      final u = auth.currentUser;
      if (u != null && uids.contains(u.uid)) {
        await u.delete();
        deleted.add(u.uid);
      }
      await auth.signOut();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
