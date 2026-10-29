import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/savings_repository.dart';
import 'package:ruma/features/agenda/agenda_page.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/features/finance/finance_page.dart';
import 'package:ruma/features/savings/savings_form.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'five core journeys, date context, offline retry and draft recovery',
    (t) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError('demo-ruma only; no production data or AI calls');
      }
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      t.testTextInput.register();
      addTearDown(t.testTextInput.unregister);
      final session = await initializeSession();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      await session.enterTemporarily();
      final uid = auth.currentUser!.uid;
      final db = initializeAgendaDatabase();
      final financeRepo = FinanceRepository(db, auth);
      final savingsRepo = SavingsRepository(db, auth);
      final cases = <String>[];
      binding.reportData = {
        'project': 'demo-ruma',
        'fixtureUid': uid,
        'productionWrites': 0,
        'modelCalls': 0,
        'aiProposal': 'synthetic fixture; real review and Firestore commit',
        'recovery': 'widget/store recreation in the same Android process',
        'cases': cases,
      };
      Future<void> settle() async => t.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 60),
      );
      Future<void> tap(Finder finder) async {
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          await t.pump(const Duration(seconds: 5));
          await settle();
        }
        await t.ensureVisible(finder);
        await settle();
        await t.tap(finder);
        await settle();
      }

      Future<void> key(String name) => tap(find.byKey(ValueKey(name)));
      Future<void> enter(String name, String value) async {
        final finder = find.byKey(ValueKey(name));
        await t.ensureVisible(finder);
        await t.enterText(finder, value);
        await t.pump();
      }

      Future<void> shot(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await binding.takeScreenshot(name);
        expect(t.takeException(), isNull);
      }

      Future<void> pickerOk(Type dialog) async {
        final label = MaterialLocalizations.of(t.element(find.byType(dialog)))
            .okButtonLabel;
        await tap(find.text(label).last);
      }

      try {
        await t.pumpWidget(RumaApp(session: session, firestore: db));
        await settle();
        await binding.convertFlutterSurfaceToImage();
        await shot('01-home-empty');
        await key('tab-1');
        final agenda = t.widget<AgendaPage>(find.byType(AgendaPage)).store;
        final selected = agendaDay(agendaLocal(DateTime.now().toUtc()))
            .add(const Duration(days: 7));
        await tap(find.byTooltip('Minggu berikutnya'));
        await key('agenda-add');
        await tap(find.text('Jadwal kuliah'));
        await enter('agenda-title', 'Kuliah uji usability');
        await key('agenda-start');
        expect(
          DateUtils.isSameDay(
            t
                .widget<DatePickerDialog>(find.byType(DatePickerDialog))
                .initialDate,
            selected,
          ),
          isTrue,
        );
        await pickerOk(DatePickerDialog);
        await pickerOk(TimePickerDialog);
        await key('agenda-save');
        final item = agenda.items.single;
        expect(
          DateUtils.isSameDay(agendaLocal(item.input.startAtUtc!), selected),
          isTrue,
        );
        expect(find.text('Kuliah uji usability'), findsOneWidget);
        expect(
          find
              .byKey(ValueKey('agenda-day-${selected.weekday - 1}'))
              .hitTestable(),
          findsOneWidget,
        );
        await shot('02-agenda-selected-day');
        await tap(find.text('Kuliah uji usability'));
        await tap(find.text('Edit kegiatan'));
        await enter('agenda-title', 'Kuliah setelah revisi');
        await key('agenda-save');
        expect(agenda.items.single.id, item.id);
        expect(agenda.items.single.input.title, 'Kuliah setelah revisi');
        await tap(find.byTooltip('Kembali'));
        cases.add('editing agenda retains its identity and selected date');
        cases.add(
          'agenda creation preserves selected day and appears in that day',
        );

        await key('tab-3');
        final finance = t.widget<FinancePage>(find.byType(FinancePage)).store;
        final currentMonth = financeToday().substring(0, 7);
        await key('finance-income');
        await enter('transaction-amount', '1000000');
        await key('finance-save');
        expect(finance.snapshot!.balance, 1000000);
        await key('finance-previous');
        expect(finance.month, isNot(currentMonth));
        await key('finance-expense');
        expect(find.byKey(const ValueKey('transaction-date')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('transaction-date')),
            matching: find.textContaining(
              '${DateTime.parse(financeToday()).year}',
            ),
          ),
          findsOneWidget,
        );
        await enter('transaction-amount', '18000');
        await shot('03-visible-transaction-date');
        await key('finance-save');
        expect(finance.month, currentMonth);
        expect(finance.snapshot!.month.expense, 18000);
        await key('finance-history');
        final expense = finance.snapshot!.items.singleWhere(
          (e) => e.input.type == 'expense',
        );
        expect(
          find.byKey(ValueKey('transaction-${expense.id}')),
          findsOneWidget,
        );
        await shot('04-saved-transaction-visible');
        await tap(find.byTooltip('Kembali'));
        cases.add(
          'saving from an older month follows the actual transaction date',
        );

        await key('finance-expense');
        await enter('transaction-amount', '22000');
        await db.disableNetwork();
        await key('finance-save');
        expect(finance.error, isNotNull);
        expect(
          t
              .widget<TextFormField>(
                find.byKey(const ValueKey('transaction-amount')),
              )
              .controller!
              .text,
          '22000',
        );
        await shot('05-offline-form-preserved');
        await db.enableNetwork();
        await key('finance-save');
        expect(finance.snapshot!.month.expense, 40000);
        expect(finance.snapshot!.items.length, 3);
        cases.add(
          'offline save preserves input and retry creates one transaction',
        );

        await key('finance-savings');
        await key('savings-add');
        await enter('savings-name', 'Laptop kuliah');
        await enter('savings-amount', '2000000');
        await key('savings-save');
        final goal = (await savingsRepo.read()).goals.single;
        await key('savings-goal-${goal.id}');
        await key('savings-deposit');
        await enter('savings-amount', '200000');
        await key('savings-save');
        await key('savings-withdrawal');
        await enter('savings-amount', '50000');
        await tap(find.byTooltip('Kembali'));
        await tap(find.text('Lanjut mengedit'));
        expect(find.byType(SavingsFormPage), findsOneWidget);
        await key('savings-save');
        final saved = await savingsRepo.read();
        expect(saved.totalSavedRupiah, 150000);
        expect(saved.availableRupiah, 810000);
        final after = await financeRepo.read(currentMonth);
        expect(after.balance, 960000);
        expect(after.month.expense, 40000);
        expect(after.items.length, 3);
        await shot('06-savings-movements');
        cases.add(
          'setor/tarik only allocate money; cancel protects unsaved input',
        );

        await key('tab-2');
        var assistant = t
            .widget<AssistantPage>(find.byType(AssistantPage))
            .store;
        final repository = DraftRepository(db, auth);
        final revisions = await repository.revisions();
        final entryId = repository.newId();
        assistant.message =
            'Draf sintetis untuk menguji tinjauan dan pemulihan.';
        assistant.draft = AssistantDraft(
          id: repository.newId(),
          operationId: repository.newId(),
          uid: uid,
          baseAgendaRevision: revisions['agenda']!,
          baseFinanceRevision: revisions['finance']!,
          items: [
            DraftEntry(
              id: entryId,
              quote: 'Belajar 30 menit',
              localDate: financeToday(),
              agenda: const AgendaInput(
                title: 'Belajar dari draf',
                durationMinutes: 30,
              ),
            ),
          ],
        );
        assistant.change(() {});
        expect(await assistant.flush(), isTrue);
        await shot('07-draft-not-saved');
        expect((await db.collection('users/$uid/agenda').get()).docs.length, 1);
        await t.pumpWidget(const SizedBox.shrink());
        await settle();
        await t.pumpWidget(RumaApp(session: session, firestore: db));
        await settle();
        await key('tab-2');
        assistant = t.widget<AssistantPage>(find.byType(AssistantPage)).store;
        expect(assistant.draft!.applied, isFalse);
        expect(
          assistant.draft!.items.single.agenda!.title,
          'Belajar dari draf',
        );
        await key('draft-toggle-$entryId');
        await key('draft-save');
        expect(assistant.draft!.applied, isFalse);
        expect(assistant.error, isNotEmpty);
        expect((await db.collection('users/$uid/agenda').get()).docs.length, 1);
        await key('draft-toggle-$entryId');
        cases.add('excluding every draft item cannot commit an empty batch');
        await key('draft-edit-$entryId');
        await enter('agenda-title', 'Belajar setelah ditinjau');
        await key('agenda-save');
        await key('draft-save');
        expect(assistant.draft!.applied, isTrue);
        expect(assistant.error, isEmpty);
        await shot('08-draft-saved');
        final receiptCount =
            (await db.collection('users/$uid/operations').get()).docs.length;
        await assistant.save();
        expect(
          (await db.collection('users/$uid/operations').get()).docs.length,
          receiptCount,
        );
        cases.add(
          'draft survives store recreation, stays uncommitted until approved, and cannot duplicate',
        );
        await key('tab-0');
        expect(find.text('Rp960.000'), findsOneWidget);
        expect(find.text('Tersedia Rp810.000'), findsOneWidget);
        await shot('09-home-reconciled');
        cases.add(
          'Home reconciles recorded balance, savings and available money',
        );
        binding.reportData!['passed'] = true;
      } finally {
        await db.enableNetwork();
        await t.pumpWidget(const SizedBox.shrink());
        await auth.currentUser?.delete();
        binding.reportData!['fixtureAuthDeleted'] = true;
        session.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
