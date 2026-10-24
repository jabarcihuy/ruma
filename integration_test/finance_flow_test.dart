import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/features/finance/finance_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('manual finance UI + native SDK and agenda interoperability', (
    tester,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) {
      throw StateError('Local demo-ruma only');
    }
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    final session = await initializeSession();
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await session.enterTemporarily();
    final owner = auth.currentUser!.uid;
    final db = initializeAgendaDatabase();
    final repo = FinanceRepository(db, auth);
    await tester.pumpWidget(RumaApp(session: session, firestore: db));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    Future<void> settle() async => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 60),
    );
    Future<void> tap(Finder f) async {
      await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
      await settle();
      await tester.tap(f);
      await settle();
    }

    Future<void> keyed(String key) async {
      await tap(find.byKey(ValueKey(key)));
      if (key == 'finance-save') {
        await tester.pump(const Duration(seconds: 5));
        await settle();
      }
    }

    Future<void> textTap(String s) async => tap(find.text(s).last);
    Future<void> enter(String key, String value) async {
      await tester.enterText(find.byKey(ValueKey(key)), value);
      await tester.pump();
    }

    Future<void> shot(String name) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await settle();
      await binding.takeScreenshot(name);
    }

    FinanceStore? store;
    try {
      await keyed('tab-3');
      await settle();
      store = tester.widget<FinancePage>(find.byType(FinancePage)).store;
      expect(store.error, isNull);
      expect(store.snapshot!.balance, 0);
      await shot('01-finance-empty');
      await keyed('finance-income');
      await enter('transaction-amount', '2000000');
      await keyed('finance-save');
      expect(store.snapshot!.balance, 2000000);
      await keyed('finance-expense');
      await enter('transaction-amount', '18000');
      await shot('02-transaction-form');
      await keyed('finance-save');
      expect(store.snapshot!.balance, 1982000);
      expect(store.snapshot!.month.expense, 18000);
      final expense = store.snapshot!.items.singleWhere(
        (t) => t.input.type == 'expense',
      );
      // Legacy budget data remains readable; its UI is replaced by savings.
      await store.save(
        FinanceMutation(
          operationId: repo.newId(),
          id: store.month,
          originalVersion: store.snapshot!.month.version,
          budget: BudgetInput(
            monthKey: store.month,
            total: 100000,
            categories: {'food': 50000},
          ),
        ),
      );
      await settle();
      expect(store.snapshot!.month.budget, 100000);
      expect(store.snapshot!.balance, 1982000);
      await shot('03-finance-dashboard');
      await keyed('finance-history');
      await keyed('transaction-${expense.id}');
      await shot('04-transaction-detail');
      await keyed('transaction-edit');
      await enter('transaction-amount', '22000');
      await keyed('finance-save');
      expect(store.snapshot!.balance, 1978000);
      expect(
        store.snapshot!.items.singleWhere((t) => t.input.type == 'expense').id,
        expense.id,
      );
      await keyed('transaction-${expense.id}');
      await keyed('transaction-delete');
      await textTap('Batalkan');
      expect(store.snapshot!.month.expense, 22000);
      await keyed('transaction-delete');
      await textTap('Hapus transaksi');
      await tester.pump(const Duration(seconds: 5));
      await settle();
      expect(store.snapshot!.month.expense, 0);
      expect(store.snapshot!.balance, 2000000);
      await tap(find.byTooltip('Kembali').last);
      await settle();
      // SDK: moving month/type reverses old totals, retains ID and tolerates retry.
      final today = DateTime.parse(financeToday());
      final previous = dateKey(DateTime(today.year, today.month, 0));
      final current = financeToday().substring(0, 7);
      final id = repo.newId();
      final create = FinanceMutation(
        operationId: repo.newId(),
        id: id,
        input: TransactionInput(
          type: 'expense',
          amountRupiah: 30000,
          categoryId: 'transport',
          localDate: financeToday(),
        ),
      );
      await repo.save(create);
      final revision = (await repo.read(current)).revision;
      await repo.save(create);
      expect((await repo.read(current)).revision, revision);
      final updated = FinanceMutation(
        operationId: repo.newId(),
        id: id,
        originalVersion: 1,
        input: TransactionInput(
          type: 'income',
          amountRupiah: 50000,
          categoryId: 'work',
          localDate: previous,
        ),
      );
      await repo.save(updated);
      expect((await repo.read(current)).month.expense, 0);
      expect((await repo.read(previous.substring(0, 7))).month.income, 50000);
      expect((await repo.read(current)).balance, 2050000);
      await expectLater(
        repo.save(
          FinanceMutation(
            operationId: repo.newId(),
            id: id,
            originalVersion: 1,
            input: create.input,
          ),
        ),
        throwsA(isA<FinanceFailure>()),
      );
      // Native SDK write access-budget and shared core regression.
      final ar = AgendaRepository(db, auth);
      await ar.save(
        AgendaMutation(
          operationId: ar.newId(),
          id: ar.newId(),
          input: const AgendaInput(title: 'QA agenda beside money'),
        ),
      );
      expect((await repo.read(current)).balance, 2050000);
      expect((await ar.read()).items.length, 1);
      await db.disableNetwork();
      final offlineId = repo.newId();
      await expectLater(
        repo.save(
          FinanceMutation(
            operationId: repo.newId(),
            id: offlineId,
            input: create.input,
          ),
        ),
        throwsA(anything),
      );
      await db.enableNetwork();
      expect(
        (await db
                .collection('users')
                .doc(owner)
                .collection('transactions')
                .doc(offlineId)
                .get(const GetOptions(source: Source.server)))
            .exists,
        isFalse,
      );
      await store.load();
      await settle();
      await keyed('finance-report');
      await shot('05-finance-report');
      await tap(find.byTooltip('Kembali').last);
      await settle();
      await keyed('tab-0');
      await shot('06-home-time-and-money');
      await auth.signOut();
      await session.enterTemporarily();
      final other = auth.currentUser!.uid;
      await settle();
      await keyed('tab-3');
      await settle();
      final otherStore = tester
          .widget<FinancePage>(find.byType(FinancePage))
          .store;
      expect(otherStore.snapshot!.balance, 0);
      expect(otherStore.snapshot!.items, isEmpty);
      await expectLater(repo.read(current), throwsA(isA<FinanceFailure>()));
      await expectLater(
        db
            .collection('users')
            .doc(owner)
            .collection('transactions')
            .get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      binding.reportData ??= {};
      binding.reportData!.addAll({
        'project': 'demo-ruma',
        'ownerUid': owner,
        'otherUid': other,
        'uiCreateIncomeExpense': true,
        'uiEditKeepsId': true,
        'deleteCancelAndConfirm': true,
        'budgetNeverChangesBalance': true,
        'crossMonthTypeReversal': true,
        'idempotentRetry': true,
        'staleVersionRejected': true,
        'offlineNotQueued': true,
        'agendaInteroperability': true,
        'accountIsolation': true,
        'productionWrites': 0,
      });
    } finally {
      await tester.pumpWidget(const SizedBox());
      await auth.currentUser?.delete();
      session.dispose();
    }
  });
}
