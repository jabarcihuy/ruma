import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('explicitly approved production AI draft and atomic commit', (
    tester,
  ) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('ASSISTANT_LIVE_TESTS')) {
      throw StateError(
        'Requires production and explicit ASSISTANT_LIVE_TESTS=true',
      );
    }
    final session = await initializeSession(),
        auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase();
    final uids = <String>[], deleted = <String>[];
    final report = <String, dynamic>{
      'project': RumaFirebaseOptions.android.projectId,
      'suite': 'assistant_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'modelCalls': 0,
    };
    binding.reportData = report;
    AssistantService? service;
    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final owner = auth.currentUser!.uid;
      uids.add(owner);
      // UID-only fixture recovery marker; never print tokens or model/user messages.
      // ignore: avoid_print
      print('RUMA_ASSISTANT_SYNTHETIC_UID=$owner');
      final repo = DraftRepository(db, auth);
      service = AssistantService(auth);
      const message = 'Besok baca jurnal 30 menit. Tadi makan 18 ribu.';
      report['modelCalls'] = 1;
      // ignore: avoid_print
      print('RUMA_ASSISTANT_ONE_MODEL_CALL_START');
      final response = await service
          .propose(message, repo.newId())
          .timeout(const Duration(seconds: 65));
      expect(response['type'], 'draft_proposal');
      final items = parseProposal(response['items'], message, repo.newId);
      expect(items.where((e) => e.agenda != null).length, 1);
      expect(items.where((e) => e.money != null).length, 1);
      final rev = await repo.revisions(),
          d = AssistantDraft(
            id: repo.newId(),
            operationId: repo.newId(),
            uid: owner,
            items: items,
            baseAgendaRevision: rev['agenda']!,
            baseFinanceRevision: rev['finance']!,
          );
      expect((await repo.user.collection('operations').get()).docs, isEmpty);
      await repo.apply(d);
      await repo.apply(d);
      expect((await repo.user.collection('operations').get()).docs.length, 1);
      expect((await AgendaRepository(db, auth).read()).items.length, 1);
      final finance = await FinanceRepository(
        db,
        auth,
      ).read(financeToday().substring(0, 7));
      expect(finance.balance, -18000);
      expect(finance.items.length, 1);
      await auth.currentUser!.delete();
      deleted.add(owner);
      await expectLater(
        repo.user
            .collection('state')
            .doc('core')
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await auth.signInAnonymously();
      final other = auth.currentUser!.uid;
      uids.add(other);
      await expectLater(
        repo.user
            .collection('operations')
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await expectLater(repo.apply(d), throwsA(isA<DraftFailure>()));
      await auth.currentUser!.delete();
      deleted.add(other);
      report['passed'] = true;
      report['cases'] = [
        'one real model call',
        'no writes before approval',
        'combined commit',
        'stable retry',
        'exact balance',
        'unauthenticated denial',
        'other UID denial',
      ];
    } finally {
      service?.dispose();
      final user = auth.currentUser;
      if (user != null && uids.contains(user.uid)) {
        final id = user.uid;
        await user.delete();
        if (!deleted.contains(id)) {
          deleted.add(id);
        }
      }
      session.dispose();
    }
  });
}
