import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/savings.dart';
import 'package:ruma/data/savings_store.dart';
import 'package:ruma/features/savings/savings_form.dart';
import 'package:ruma/features/savings/savings_page.dart';

import 'helpers/savings_fixture.dart';

Widget app(Widget page, {double scale = 1}) => MaterialApp(
  theme: rumaTheme(),
  locale: const Locale('id'),
  supportedLocales: const [Locale('id')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);
Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  late SavingsRepoFake repo;
  late SavingsStore store;
  setUp(() {
    repo = SavingsRepoFake();
    store = SavingsStore(repo)..snapshot = savingsFixture();
  });
  tearDown(() => store.dispose());
  test(
    'store ignores stale load and discards a failed refreshed snapshot',
    () async {
      final old = Completer<SavingsSnapshot>();
      repo.onRead = () => old.future;
      final waiting = store.load();
      repo.onRead = () async => savingsFixture(balance: 700000);
      await store.load();
      old.complete(savingsFixture());
      await waiting;
      expect(store.snapshot!.recordedBalance, 700000);
      repo.onRead = () async => throw const FinanceFailure('offline');
      await store.load();
      expect(store.snapshot, isNull);
      expect(store.error, 'offline');
    },
  );
  test('confirmed save remains successful if refresh fails; duplicate presses ignored', () async {
    final pending = Completer<void>();
    var saves = 0;
    repo.onSave = (m) {
      saves++;
      return pending.future;
    };
    repo.onRead = () async => throw const FinanceFailure('refresh failed');
    const m = SavingsMutation.goal(
      operationId: 'op',
      goalId: 'g',
      input: SavingsGoalInput(name: 'Dana', targetRupiah: 1),
    );
    final first = store.save(m);
    expect(await store.save(m), false);
    pending.complete();
    expect(await first, true);
    expect(saves, 1);
    expect(store.snapshot, isNull);
    expect(store.error, startsWith('Tersimpan.'));
  });
  test(
    'late read does not notify or retain another session after disposal',
    () async {
      final future = Completer<SavingsSnapshot>();
      repo.onRead = () => future.future;
      final temporary = SavingsStore(repo);
      final load = temporary.load();
      temporary.dispose();
      future.complete(savingsFixture());
      await load;
      expect(temporary.snapshot, isNull);
    },
  );
  testWidgets(
    'list and detail show real progress/history and open the selected goal',
    (t) async {
      await t.pumpWidget(app(SavingsPage(store: store)));
      await t.pumpAndSettle();
      expect(find.text('Rp400.000'), findsOneWidget);
      expect(find.text('Target tercapai'), findsOneWidget);
      await tap(t, 'savings-goal-emergency');
      expect(find.text('Dana darurat'), findsOneWidget);
      expect(find.text('+Rp300.000'), findsOneWidget);
      await tap(t, 'savings-deposit');
      expect(find.text('Setor tabungan.'), findsOneWidget);
      expect(find.text('Dana darurat'), findsOneWidget);
    },
  );
  testWidgets(
    'goal creation validates rupiah; retry preserves same operation until input changes',
    (t) async {
      final mutations = <SavingsMutation>[];
      repo.onSave = (m) async {
        mutations.add(m);
        throw const FinanceFailure('Offline; isian tetap ada.');
      };
      await t.pumpWidget(app(SavingsPage(store: store)));
      await t.pumpAndSettle();
      await tap(t, 'savings-add');
      await tap(t, 'savings-icon-headphones');
      await t.enterText(
        find.byKey(const ValueKey('savings-name')),
        'Dana laptop',
      );
      await t.enterText(find.byKey(const ValueKey('savings-amount')), '1,5');
      await tap(t, 'savings-save');
      expect(mutations, isEmpty);
      await t.ensureVisible(find.byKey(const ValueKey('savings-amount')));
      await t.enterText(
        find.byKey(const ValueKey('savings-amount')),
        '100.000',
      );
      await tap(t, 'savings-save');
      await tap(t, 'savings-save');
      expect(mutations.length, 2);
      expect(mutations[0].operationId, mutations[1].operationId);
      expect(mutations[0].requestKey, mutations[1].requestKey);
      expect(mutations[0].goal!.name, 'Dana laptop');
      expect(mutations[0].goal!.targetDate, isNull);
      expect(mutations[0].goal!.iconId, 'headphones');
      await t.ensureVisible(find.byKey(const ValueKey('savings-amount')));
      await t.enterText(
        find.byKey(const ValueKey('savings-amount')),
        '200.000',
      );
      await tap(t, 'savings-save');
      expect(mutations.last.operationId, isNot(mutations.first.operationId));
      expect(mutations.last.goalId, mutations.first.goalId);
      await tap(t, 'savings-icon-plane');
      await tap(t, 'savings-save');
      expect(mutations.last.goal!.iconId, 'plane');
      expect(mutations.last.operationId, isNot(mutations[2].operationId));
    },
  );
  testWidgets(
    'withdrawal form saves correct type, captures version and protects dirty cancellation',
    (t) async {
      final mutations = <SavingsMutation>[];
      repo.onSave = (m) async {
        mutations.add(m);
      };
      await t.pumpWidget(app(SavingsPage(store: store)));
      await t.pumpAndSettle();
      await tap(t, 'savings-goal-emergency');
      ScaffoldMessenger.of(t.element(find.byType(SavingsDetailPage)))
          .showSnackBar(
            const SnackBar(
              content: Text('Pesan dari halaman sebelumnya'),
              duration: Duration(minutes: 1),
            ),
          );
      await t.pump();
      await tap(t, 'savings-withdrawal');
      expect(find.byType(SnackBar), findsNothing);
      await t.enterText(find.byKey(const ValueKey('savings-amount')), '50.000');
      await tap(t, 'savings-cancel');
      expect(find.text('Tinggalkan isian ini?'), findsOneWidget);
      await t.tap(find.text('Lanjut mengedit'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const ValueKey('savings-amount')))
            .controller!
            .text,
        '50.000',
      );
      await tap(t, 'savings-save');
      expect(mutations.single.movement!.type, 'withdrawal');
      expect(mutations.single.movement!.amountRupiah, 50000);
      expect(mutations.single.originalVersion, 2);
      expect(find.byType(SavingsDetailPage), findsOneWidget);
    },
  );
  testWidgets('empty/error states retry without invented balance', (t) async {
    store.snapshot = SavingsSnapshot(
      goals: [],
      movements: [],
      recordedBalance: 0,
      totalSavedRupiah: 0,
      revision: 0,
    );
    await t.pumpWidget(app(SavingsPage(store: store)));
    await t.pumpAndSettle();
    expect(find.text('Belum ada tujuan.'), findsOneWidget);
    repo.onRead = () async => throw const FinanceFailure('offline');
    await store.load();
    await t.pumpAndSettle();
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('Rp0'), findsNothing);
    repo.onRead = () async => savingsFixture();
    await t.tap(find.text('Muat ulang'));
    await t.pumpAndSettle();
    expect(find.text('Rp400.000'), findsOneWidget);
  });
  testWidgets(
    'legacy icon defaults and icon-only edits protect dirty cancellation',
    (t) async {
      await t.pumpWidget(app(SavingsPage(store: store)));
      await t.pumpAndSettle();
      expect(find.textContaining('kurang Rp700.000'), findsOneWidget);
      await tap(t, 'savings-goal-emergency');
      await tap(t, 'savings-edit');
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('savings-icon-wallet')),
            )
            .selected,
        true,
      );
      await tap(t, 'savings-icon-shield-check');
      await tap(t, 'savings-cancel');
      expect(find.text('Tinggalkan isian ini?'), findsOneWidget);
      await t.tap(find.text('Lanjut mengedit'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('savings-icon-shield-check')),
            )
            .selected,
        true,
      );
    },
  );
  testWidgets('all savings pages adapt to narrow/large text and keyboard', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final page in [
      SavingsPage(store: store),
      SavingsDetailPage(store: store, goalId: 'emergency'),
      SavingsFormPage(store: store),
      SavingsFormPage(store: store, goal: savingsFixture().goals.first),
      SavingsFormPage(
        store: store,
        goal: savingsFixture().goals.first,
        movement: 'deposit',
      ),
    ]) {
      await t.pumpWidget(app(page, scale: 2));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final input = find.byKey(const ValueKey('savings-amount'));
      if (input.evaluate().isNotEmpty) {
        await t.ensureVisible(input);
        await t.tap(input);
        await t.pumpAndSettle();
        await t.ensureVisible(find.byKey(const ValueKey('savings-save')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    }
    await t.pumpWidget(const SizedBox());
  });
}
