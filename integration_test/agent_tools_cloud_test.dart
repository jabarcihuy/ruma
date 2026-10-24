import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';

// Prepared only: opt-in after publication approval. Exactly four model requests;
// no provider retry, user records, credentials in logs, or real personal content.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved cloud tools and exact restoration with synthetic data', (
    tester,
  ) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('AGENT_TOOLS_LIVE_TESTS')) {
      throw StateError(
        'Explicit AGENT_TOOLS_LIVE_TESTS=true and production required',
      );
    }
    final session = await initializeSession(),
        auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase();
    final uids = <String>[], deleted = <String>[];
    final report = <String, dynamic>{
      'project': RumaFirebaseOptions.android.projectId,
      'suite': 'agent_tools_cloud_test',
      'fixtureUids': uids,
      'authFixturesDeleted': deleted,
      'modelCalls': 0,
    };
    binding.reportData = report;
    AssistantStore? s;
    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final owner = auth.currentUser!.uid;
      uids.add(owner);
      // ignore: avoid_print
      print('RUMA_AGENT_TOOLS_SYNTHETIC_UID=$owner');
      final repo = DraftRepository(db, auth),
          a = AgendaRepository(db, auth),
          f = FinanceRepository(db, auth);
      s = AssistantStore(
        repo,
        AssistantService(auth),
        AgendaStore(a),
        FinanceStore(f),
      )..consent = true;
      Future<void> send(String text) async {
        if ((report['modelCalls'] as int) >= 4) {
          throw StateError('model_call_limit');
        }
        report['modelCalls'] = (report['modelCalls'] as int) + 1;
        await s!.send(text);
        expect(s!.error, isEmpty);
      }

      await send(
        'Besok baca jurnal QA 30 menit dan revisi tugas QA 60 menit. Tadi makan QA 18 ribu.',
      );
      final d = s.draft!;
      expect(d.items.where((x) => x.agenda != null).length, 2);
      expect(d.items.where((x) => x.money != null).length, 1);
      expect(
        d.items.where((x) => x.agenda != null).every((x) => x.suggestedTime),
        true,
      );
      expect((await repo.user.collection('operations').get()).docs, isEmpty);
      await s.save();
      expect(s.error, isEmpty);
      expect(d.applied, true);
      await s.save();
      expect((await repo.user.collection('operations').get()).size, 1);
      final month = financeToday().substring(0, 7);
      expect((await f.read(month)).balance, -18000);
      s.discard();
      await send('Tampilkan laporan keuangan bulan $month.');
      expect(s.draft, isNull);
      expect(s.recordDraft, isNull);
      expect(s.reply, contains('Rp18.000'));
      expect((await repo.user.collection('operations').get()).size, 1);
      final target = (await a.read()).items.first;
      final date = dateKey(agendaLocal(target.input.startAtUtc!));
      await send('Ubah ${target.input.title} pada $date menjadi 20 menit.');
      expect(s.recordDraft?.id, target.id);
      expect(s.recordDraft?.agenda?.durationMinutes, 20);
      await s.saveRecord();
      expect(s.error, isEmpty);
      await s.saveRecord(undo: true);
      expect(s.error, isEmpty);
      expect(s.recordDraft?.undone, true);
      expect(
        (await a.read()).items
            .singleWhere((x) => x.id == target.id)
            .input
            .durationMinutes,
        target.input.durationMinutes,
      );
      s.discardRecord();
      final money = (await f.read(month)).items.single;
      await send(
        'Hapus transaksi ${money.input.description} pada ${money.input.localDate}.',
      );
      expect(s.recordDraft?.id, money.id);
      expect(s.recordDraft?.delete, true);
      await s.saveRecord();
      expect(s.error, isEmpty);
      expect((await f.read(month)).balance, 0);
      await s.saveRecord(undo: true);
      expect(s.error, isEmpty);
      expect((await f.read(month)).balance, -18000);
      await s.saveRecord(undo: true);
      expect((await f.read(month)).items.length, 1);
      await auth.currentUser!.delete();
      deleted.add(owner);
      await auth.signInAnonymously();
      uids.add(auth.currentUser!.uid);
      await expectLater(
        repo.user.collection('transactions').get(),
        throwsA(isA<FirebaseException>()),
      );
      final other = auth.currentUser!.uid;
      await auth.currentUser!.delete();
      deleted.add(other);
      report['passed'] = true;
      report['cases'] = [
        'four bounded real model calls',
        'reviewed combined slots and save',
        'read no writes',
        'existing agenda edit and undo',
        'expense delete and exact restore',
        'retry no duplicates',
        'UID isolation',
      ];
    } finally {
      s?.dispose();
      s?.agenda.dispose();
      s?.finance.dispose();
      final user = auth.currentUser;
      if (user != null && uids.contains(user.uid)) {
        final uid = user.uid;
        await user.delete();
        if (!deleted.contains(uid)) deleted.add(uid);
      }
      session.dispose();
    }
  });
}
