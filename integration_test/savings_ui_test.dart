import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/ui/components.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/savings_repository.dart';
import 'package:ruma/features/savings/savings_page.dart';
import 'package:ruma/features/savings/savings_form.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('savings UI CRUD and summaries with native local Firebase', (
    t,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) {
      throw StateError('Local demo-ruma only');
    }
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    t.testTextInput.register();
    addTearDown(t.testTextInput.unregister);
    final session = await initializeSession();
    final auth = FirebaseAuth.instance;
    await auth.signOut();
    await session.enterTemporarily();
    final db = initializeAgendaDatabase();
    final finance = FinanceRepository(db, auth),
        repo = SavingsRepository(db, auth);
    final cases = <String>[];
    final captureKey = GlobalKey();
    Future<void> settle() async => t.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 60),
    );
    Future<void> tap(String key) async {
      final f = find.byKey(ValueKey(key));
      await Scrollable.ensureVisible(t.element(f), alignment: .5);
      await settle();
      await t.tap(f);
      await settle();
    }

    Future<void> enter(String key, String value) async {
      final f = find.byKey(ValueKey(key));
      await Scrollable.ensureVisible(t.element(f));
      await settle();
      await t.enterText(f, value);
      await t.pump();
    }

    Future<void> shot(String name) async {
      ScaffoldMessenger.of(t.element(find.byType(Scaffold).last))
          .removeCurrentSnackBar();
      FocusManager.instance.primaryFocus?.unfocus();
      final heading = find.byType(RumaHeading);
      if (heading.evaluate().isNotEmpty) {
        await Scrollable.ensureVisible(t.element(heading.last), alignment: 0);
      }
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle();
      await t.pump();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      // Repaint retained SVG layers before exporting the current widget tree.
      void repaint(RenderObject object) {
        object.markNeedsPaint();
        object.visitChildren(repaint);
      }

      repaint(boundary);
      await t.pump();
      final image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      binding.reportData ??= {};
      binding.reportData!['screenshots'] ??= <Map<String, dynamic>>[];
      (binding.reportData!['screenshots'] as List<dynamic>).add({
        'screenshotName': name,
        'bytes': bytes!.buffer.asUint8List().toList(),
      });
    }

    Future<void> back() async {
      await t.tap(find.byTooltip('Kembali'));
      await settle();
    }

    Future<void> newGoal(String name, String target) async {
      await tap('savings-add');
      await enter('savings-name', name);
      await tap('savings-icon-book-open');
      await enter('savings-amount', target);
      await tap('savings-save');
      expect(find.byType(SavingsFormPage), findsNothing);
    }

    try {
      for (final input in [
        TransactionInput(
          type: 'income',
          amountRupiah: 2000000,
          categoryId: 'allowance',
          localDate: financeToday(),
        ),
        for (final e in {
          'food': 640000,
          'transport': 180000,
          'housing': 260000,
          'other': 100000,
        }.entries)
          TransactionInput(
            type: 'expense',
            amountRupiah: e.value,
            categoryId: e.key,
            localDate: financeToday(),
          ),
      ]) {
        await finance.save(
          FinanceMutation(
            operationId: finance.newId(),
            id: finance.newId(),
            input: input,
          ),
        );
      }
      await t.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: RumaApp(session: session, firestore: db),
        ),
      );
      await settle();

      await tap('tab-3');
      await tap('finance-savings');
      expect(find.text('Belum ada tujuan.'), findsOneWidget);
      await shot('01-savings-empty');
      await tap('savings-add');
      await enter('savings-name', 'Dana darurat');
      await tap('savings-icon-shield-check');
      await enter('savings-amount', '1000000');
      await shot('02-goal-form');
      await tap('savings-save');
      var data = await repo.read();
      final emergency = data.goals.single.id;
      expect(data.goals.single.balanceRupiah, 0);
      expect(data.goals.single.input.iconId, 'shield-check');
      cases.add('create goal through form, zero initial savings');
      await tap('savings-goal-$emergency');
      await tap('savings-deposit');
      await enter('savings-amount', '900000');
      await tap('savings-save');
      expect(
        find.text('Uang tersedia belum cukup untuk setoran ini.'),
        findsOneWidget,
      );
      expect((await repo.read()).movements, isEmpty);
      await enter('savings-amount', '300000');
      await shot('03-deposit-form');
      await tap('savings-save');
      expect(find.byType(SavingsDetailPage), findsOneWidget);
      data = await repo.read();
      expect(data.totalSavedRupiah, 300000);
      expect(data.availableRupiah, 520000);
      cases.add(
        'insufficient funds preserves input; corrected deposit saves once',
      );
      await tap('savings-edit');
      await enter('savings-name', 'Wishlist headphone');
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('savings-icon-shield-check')),
            )
            .selected,
        true,
      );
      await tap('savings-icon-headphones');
      await shot('04-edit-goal');
      await tap('savings-save');
      data = await repo.read();
      expect(data.goals.single.input.name, 'Wishlist headphone');
      expect(data.goals.single.input.iconId, 'headphones');
      expect(data.totalSavedRupiah, 300000);
      cases.add('edit goal preserves allocated funds');
      await shot('05-savings-detail');
      await back();
      await newGoal('Buku semester depan', '100000');
      data = await repo.read();
      final books = data.goals.singleWhere((g) => g.id != emergency).id;
      await tap('savings-goal-$books');
      await tap('savings-deposit');
      await enter('savings-amount', '100000');
      await tap('savings-save');
      expect(find.text('Target tercapai'), findsOneWidget);
      await back();
      await shot('06-savings-list');
      cases.add(
        'wishlist icons persist through create, edit, read, deposit; second goal reaches target',
      );
      await tap('savings-goal-$emergency');
      await tap('savings-withdrawal');
      await enter('savings-amount', '50000');
      await shot('07-withdrawal-form');
      await tap('savings-cancel');
      expect(find.text('Tinggalkan isian ini?'), findsOneWidget);
      await t.tap(find.text('Lanjut mengedit'));
      await settle();
      expect(
        t
            .widget<TextFormField>(find.byKey(const ValueKey('savings-amount')))
            .controller!
            .text,
        '50000',
      );
      await tap('savings-save');
      data = await repo.read();
      expect(data.totalSavedRupiah, 350000);
      expect(
        data.goals.singleWhere((g) => g.id == emergency).input.iconId,
        'headphones',
      );
      expect(
        data.goals.singleWhere((g) => g.id == books).input.iconId,
        'book-open',
      );
      expect(data.availableRupiah, 470000);
      cases.add(
        'dirty cancel retains form; withdrawal changes available without income',
      );
      await tap('tab-3');
      expect(find.byType(SavingsPage), findsNothing);
      expect(find.byType(SavingsDetailPage), findsNothing);
      expect(find.textContaining('Tersedia Rp470.000'), findsOneWidget);
      expect(find.textContaining('anggaran'), findsNothing);
      await shot('08-finance-summary');
      await tap('tab-0');
      await shot('09-home-summary');
      expect(find.text('Rp350.000'), findsOneWidget);
      expect(find.text('Tersedia Rp470.000'), findsOneWidget);
      final f = await finance.read(financeToday().substring(0, 7));
      expect(f.balance, 820000);
      expect(f.month.expense, 1180000);
      expect(f.month.income, 2000000);
      expect(f.items.length, 5);
      cases.add(
        'navbar returns to main pages; home/finance reconcile after writes; ledger unchanged',
      );
      binding.reportData = {
        ...?binding.reportData,
        'projectId': 'demo-ruma',
        'productionWrites': 0,
        'passed': cases.length,
        'cases': cases,
      };
    } finally {
      await t.pumpWidget(const SizedBox());
      await auth.currentUser?.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
