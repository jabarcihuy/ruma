import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/finance/finance_forms.dart';
import 'package:ruma/features/finance/finance_page.dart';

class TestFinanceRepository extends Fake implements FinanceRepository {
  Future<FinanceSnapshot> Function(String)? onRead;
  Future<void> Function(FinanceMutation)? onSave;
  @override
  String newId() => 'synthetic-id';
  @override
  String get uid => 'synthetic';
  @override
  Future<FinanceSnapshot> read(String month) async =>
      onRead == null ? snapshot(month) : onRead!(month);
  @override
  Future<void> save(FinanceMutation m) async {
    await onSave?.call(m);
  }
}

FinanceSnapshot snapshot(String key, {int? budget}) => FinanceSnapshot(
  month: MonthFinance(key: key, budget: budget),
  items: [],
  balance: 0,
  revision: 0,
);
Widget app(Widget child) => MaterialApp(
  theme: rumaTheme(),
  locale: const Locale('id'),
  supportedLocales: const [Locale('id')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
void main() {
  test('Indonesian rupiah accepts whole amounts and rejects decimals or ambiguous grouping', () {
    for (final text in ['22.000', '22000', 'Rp22.000', 'Rp 22.000']) {
      expect(parseRupiah(text), 22000);
    }
    for (final text in [
      '1,5',
      '1.5',
      '-100',
      '1e3',
      '12.34',
      'abc',
      '',
      '1 000',
    ]) {
      expect(parseRupiah(text), isNull);
    }
    expect(rupiah(-1234567), '-Rp1.234.567');
  });
  test('money boundary validates integer range, matching category and actual past dates', () {
    TransactionInput value({
      String date = '2026-10-01',
      int amount = 18000,
      String category = 'food',
    }) => TransactionInput(
      type: 'expense',
      amountRupiah: amount,
      categoryId: category,
      localDate: date,
    );
    expect(value().validate(today: '2026-10-19'), isNull);
    for (final v in [
      value(date: '2026-02-30'),
      value(date: '2026-10-20'),
      value(amount: 0),
      value(amount: 1000000001),
      value(category: 'work'),
    ]) {
      expect(v.validate(today: '2026-10-19'), isNotNull);
    }
    expect(validDate('2024-02-29'), isTrue);
    expect(validDate('2025-02-29'), isFalse);
  });
  test(
    'budget distinguishes unset/zero, caps progress but exposes overspending',
    () {
      expect(BudgetInput(monthKey: '2026-10', total: null).validate(), isNull);
      expect(
        BudgetInput(
          monthKey: '2026-10',
          total: null,
          categories: {'food': 0},
        ).validate(),
        isNotNull,
      );
      expect(
        BudgetInput(
          monthKey: '2026-10',
          total: 100,
          categories: {'food': 60, 'transport': 41},
        ).validate(),
        isNotNull,
      );
      expect(const MonthFinance(key: '2026-10').remaining, isNull);
      const zero = MonthFinance(key: '2026-10', budget: 0, expense: 100);
      expect(zero.remaining, -100);
      expect(zero.progress, 1);
      expect(
        const MonthFinance(key: '2026-10', budget: 100, expense: 150).progress,
        1,
      );
    },
  );
  test(
    'generation and account disposal discard late finance reads and refreshes',
    () async {
      final pending = Completer<FinanceSnapshot>();
      final repo = TestFinanceRepository()..onRead = (_) => pending.future;
      final store = FinanceStore(repo);
      final load = store.load();
      store.dispose();
      pending.complete(snapshot('2026-10'));
      await load;
      expect(store.snapshot, isNull);
      final pendingRefresh = Completer<FinanceSnapshot>();
      final second = FinanceStore(
        TestFinanceRepository()..onRead = (_) => pendingRefresh.future,
      );
      final save = second.save(
        const FinanceMutation(
          operationId: 'o',
          id: 't',
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 1,
            categoryId: 'food',
            localDate: '2026-10-01',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      second.dispose();
      pendingRefresh.complete(snapshot('2026-10'));
      expect(await save, isFalse);
      expect(second.snapshot, isNull);
    },
  );
  test('confirmed write plus failed refresh reports saved and does not invite duplicate creation', () async {
    final repo = TestFinanceRepository()
      ..onRead = (_) async => throw const FinanceFailure('offline');
    final store = FinanceStore(repo);
    expect(
      await store.save(
        const FinanceMutation(
          operationId: 'o',
          id: 't',
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 1,
            categoryId: 'food',
            localDate: '2026-10-01',
          ),
        ),
      ),
      isTrue,
    );
    expect(store.error, startsWith('Tersimpan.'));
    store.dispose();
  });
  testWidgets(
    'transaction form retains invalid and failed input; unchanged retry keeps ID',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mutations = <FinanceMutation>[];
      final repo = TestFinanceRepository()
        ..onSave = (m) async {
          mutations.add(m);
          throw const FinanceFailure('Offline; isian tetap ada.');
        };
      final store = FinanceStore(repo);
      await store.load();
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: FinanceFormPage(store: store),
          ),
        ),
      );
      final amount = find.byKey(const ValueKey('transaction-amount')),
          save = find.byKey(const ValueKey('finance-save'));
      await tester.enterText(amount, '1,5');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(mutations, isEmpty);
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '22.000');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
      }
      expect(mutations.length, 2);
      expect(mutations[0].requestKey, mutations[1].requestKey);
      expect(mutations[0].operationId, mutations[1].operationId);
      expect(mutations[0].input!.amountRupiah, 22000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'dashboard, report and budget at narrow width and large text remain scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FinanceStore(TestFinanceRepository());
      await store.load();
      for (final page in [
        Scaffold(
          body: SingleChildScrollView(
            child: FinancePage(store: store, onAssistant: () {}),
          ),
        ),
        FinanceRecordsPage(store: store, report: true),
        FinanceFormPage(store: store, budget: true),
      ]) {
        await tester.pumpWidget(
          app(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: page,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
