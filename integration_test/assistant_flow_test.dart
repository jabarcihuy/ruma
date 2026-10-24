import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('local native SDK approved batch and shared review form', (
    tester,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) {
      throw StateError('demo-ruma emulator only');
    }
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    final session = await initializeSession(), auth = FirebaseAuth.instance;
    await auth.signOut();
    await session.enterTemporarily();
    final db = initializeAgendaDatabase(), repo = DraftRepository(db, auth);
    AssistantDraft makeDraft(int ar, int fr, {bool scheduled = false}) =>
        AssistantDraft(
          id: repo.newId(),
          operationId: repo.newId(),
          uid: repo.uid,
          baseAgendaRevision: ar,
          baseFinanceRevision: fr,
          items: [
            for (var i = 0; i < 3; i++)
              DraftEntry(
                id: repo.newId(),
                quote: 'Synthetic agenda',
                localDate: financeToday(),
                agenda: AgendaInput(
                  title: 'QA agenda $i',
                  durationMinutes: 30,
                  startAtUtc: scheduled
                      ? DateTime.utc(
                          2026,
                          10,
                          25,
                          3,
                        ).add(Duration(minutes: 45 * i))
                      : null,
                ),
              ),
            for (var i = 0; i < 3; i++)
              DraftEntry(
                id: repo.newId(),
                quote: 'Synthetic money',
                localDate: ['2026-08-01', '2026-09-01', financeToday()][i],
                money: TransactionInput(
                  type: i == 0 ? 'income' : 'expense',
                  amountRupiah: 10000 * (i + 1),
                  categoryId: i == 0
                      ? 'allowance'
                      : i == 1
                      ? 'food'
                      : 'transport',
                  localDate: ['2026-08-01', '2026-09-01', financeToday()][i],
                  description: 'QA money $i',
                ),
              ),
          ],
        );
    final report = <String, dynamic>{
      'project': 'demo-ruma',
      'productionWrites': 0,
      'modelCalls': 0,
    };
    binding.reportData = report;
    try {
      final draft = makeDraft(0, 0, scheduled: true);
      await repo.apply(draft);
      await repo.apply(draft);
      final finance = await FinanceRepository(
        db,
        auth,
      ).read(financeToday().substring(0, 7));
      expect(finance.balance, -40000);
      expect(finance.revision, 1);
      expect((await AgendaRepository(db, auth).read()).items.length, 3);
      final op = await repo.user.collection('operations').get();
      expect(op.docs.length, 1);
      // Stale approval and overlaps abort without partial data.
      await expectLater(
        repo.apply(makeDraft(0, 0)),
        throwsA(isA<DraftFailure>()),
      );
      await expectLater(
        repo.apply(makeDraft(1, 1, scheduled: true)),
        throwsA(isA<DraftFailure>()),
      );
      await db.disableNetwork();
      final offline = makeDraft(1, 1);
      await expectLater(repo.apply(offline), throwsA(anything));
      await db.enableNetwork();
      expect(await repo.receipt(offline), false);
      // A normal user can edit an AI-created transaction without losing its provenance.
      final fRepo = FinanceRepository(db, auth), item = finance.items.single;
      await fRepo.save(
        FinanceMutation(
          operationId: fRepo.newId(),
          id: item.id,
          originalVersion: item.version,
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 35000,
            categoryId: 'transport',
            localDate: financeToday(),
            description: 'QA edited',
          ),
        ),
      );
      expect(
        (await repo.user.collection('transactions').doc(item.id).get())
            .data()!['source'],
        'ai',
      );
      report['nativeSdkPassed'] = true;
      // ignore: avoid_print
      print('RUMA_ASSISTANT_NATIVE_SDK_PASSED');
      await tester.pumpWidget(RumaApp(session: session, firestore: db));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      final page = tester.widget<AssistantPage>(find.byType(AssistantPage)),
          s = page.store;
      await binding.takeScreenshot('01-assistant');
      final rev = await repo.revisions();
      s.message = 'Sintetis: 3 agenda dan 3 transaksi untuk ditinjau.';
      s.draft = makeDraft(rev['agenda']!, rev['finance']!);
      s.change(() {});
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-review');
      Future<void> tap(Finder f) async {
        await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      final e = s.draft!.items.first;
      await tap(find.byKey(ValueKey('draft-edit-${e.id}')));
      await tester.enterText(
        find.byKey(const ValueKey('agenda-title')),
        'QA edited draft',
      );
      await tap(find.byKey(const ValueKey('agenda-save')));
      expect(e.agenda!.title, 'QA edited draft');
      await tap(find.byKey(ValueKey('draft-toggle-${e.id}')));
      expect(e.included, false);
      await tap(find.byKey(const ValueKey('draft-save')));
      expect(s.draft!.applied, true);
      expect(s.error, isEmpty);
      await binding.takeScreenshot('03-applied');
      expect(s.agenda.items.length, 5);
      expect(s.finance.snapshot!.balance, -85000);
      report['passed'] = true;
      report['cases'] = [
        '3+3 atomic',
        'retry',
        'stale',
        'overlap',
        'offline',
        'manual edit retains source',
        'shared form draft only',
        'exclude',
        'save reviewed draft',
      ];
    } finally {
      await db.enableNetwork();
      await auth.currentUser?.delete();
      session.dispose();
    }
  });
}
