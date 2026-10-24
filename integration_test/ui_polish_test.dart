import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ruma/app/main_shell.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/features/auth/auth_form.dart';
import 'package:ruma/features/agenda/agenda_form.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';
import 'package:ruma/features/finance/finance_page.dart';
import 'package:ruma/features/finance/finance_forms.dart';
import 'package:ruma/features/finance/transaction_detail.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/features/home/home_page.dart';
import 'package:ruma/ui/components.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'all implemented phone pages and dialogs use consistent geometry',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError(
          'Local demo-ruma only; no cloud writes or model calls',
        );
      }
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final session = await initializeSession(),
          auth = FirebaseAuth.instance,
          db = initializeAgendaDatabase();
      await auth.signOut();
      await tester.pumpWidget(RumaApp(session: session, firestore: db));
      await tester.pumpAndSettle();
      final screens = <String>[];
      binding.reportData = {
        'project': 'demo-ruma',
        'productionWrites': 0,
        'modelCalls': 0,
        'screens': screens,
      };
      Future<void> tap(Finder f) async {
        await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> shot(String name) async {
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        // Capture the native window now, while this route is visible. Android
        // integrationDriver screenshot callbacks run after the whole test.
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:8766/$name'),
          );
          final response = await request.close();
          await response.drain<void>();
          expect(response.statusCode, HttpStatus.ok);
        } finally {
          client.close(force: true);
        }
        screens.add(name);
      }

      Future<void> route(Widget child, String name) async {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.push(MaterialPageRoute<void>(builder: (_) => child));
        await tester.pumpAndSettle();
        await shot(name);
        nav.pop();
        await tester.pumpAndSettle();
      }

      try {
        await shot('01-welcome');
        await route(AuthForm(session: session), '02-signin');
        await route(AuthForm(session: session, signup: true), '03-signup');
        await session.enterTemporarily();
        final ar = AgendaRepository(db, auth), fr = FinanceRepository(db, auth);
        final a = AgendaMutation(
          operationId: ar.newId(),
          id: ar.newId(),
          input: AgendaInput(
            title: 'Praktikum pemrograman mobile',
            kind: 'class',
            startAtUtc: agendaUtc(agendaLocal(DateTime.now().toUtc()), 9, 0),
            durationMinutes: 90,
            description: 'Data sintetis untuk pemeriksaan tampilan.',
          ),
        );
        await ar.save(a);
        final task = AgendaMutation(
          operationId: ar.newId(),
          id: ar.newId(),
          input: const AgendaInput(
            title: 'Revisi laporan praktikum',
            durationMinutes: 45,
          ),
        );
        await ar.save(task);
        await fr.save(
          FinanceMutation(
            operationId: fr.newId(),
            id: fr.newId(),
            input: TransactionInput(
              type: 'income',
              amountRupiah: 1500000,
              categoryId: 'allowance',
              localDate: financeToday(),
              description: 'Uang saku sintetis',
            ),
          ),
        );
        final expense = FinanceMutation(
          operationId: fr.newId(),
          id: fr.newId(),
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 18000,
            categoryId: 'food',
            localDate: financeToday(),
            description: 'Makan siang sintetis',
          ),
        );
        await fr.save(expense);
        final data = await fr.read(financeToday().substring(0, 7));
        await fr.save(
          FinanceMutation(
            operationId: fr.newId(),
            id: data.month.key,
            originalVersion: data.month.version,
            budget: BudgetInput(
              monthKey: data.month.key,
              total: 700000,
              categories: {'food': 400000},
            ),
          ),
        );
        // Rebuild the shell so its initial reads include all fixtures.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(RumaApp(session: session, firestore: db));
        await tester.pumpAndSettle();
        final home = tester.widget<HomePage>(find.byType(HomePage));
        for (
          var i = 0;
          i < 100 &&
              (!home.agenda!.loaded ||
                  home.finance!.loading ||
                  home.finance!.snapshot == null);
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(home.agenda!.loaded, true);
        expect(home.finance!.snapshot, isNotNull);
        expect(home.finance!.loading, false);
        await shot('04-home');
        await tap(find.byKey(const ValueKey('tab-1')));
        await shot('05-agenda');
        final as = tester.widget<MainShell>(find.byType(MainShell));
        expect(as.firestore, isNotNull);
        // Forms share real repositories; fixtures never leave demo-ruma.
        final agendaStore = AgendaStore(ar);
        await agendaStore.load();
        final financeStore = FinanceStore(fr);
        await financeStore.load();
        await route(AgendaFormPage(store: agendaStore), '06-task-form');
        await route(
          AgendaFormPage(store: agendaStore, kind: 'class'),
          '07-class-form',
        );
        await route(
          AgendaDetailPage(store: agendaStore, id: a.id),
          '08-agenda-detail',
        );
        await tap(find.byKey(const ValueKey('tab-3')));
        await shot('09-finance');
        await route(FinanceFormPage(store: financeStore), '10-expense-form');
        await route(
          FinanceFormPage(store: financeStore, type: 'income'),
          '11-income-form',
        );
        await route(
          FinanceFormPage(store: financeStore, budget: true),
          '12-budget-form',
        );
        await route(FinanceRecordsPage(store: financeStore), '13-history');
        await route(
          FinanceRecordsPage(store: financeStore, report: true),
          '14-report',
        );
        await route(
          TransactionDetailPage(store: financeStore, id: expense.id),
          '15-transaction-detail',
        );
        await tap(find.byKey(const ValueKey('tab-4')));
        await shot('16-profile');
        await tap(find.text('Ubah nama panggilan'));
        await shot('17-profile-name-dialog');
        await tap(find.text('Batal').last);
        final context = tester.element(find.byType(MainShell));
        showRumaPrivacy(context);
        await tester.pumpAndSettle();
        await shot('18-privacy');
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        await tap(find.byKey(const ValueKey('tab-2')));
        await shot('19-assistant');
        await tap(find.byTooltip('Tentang Asisten'));
        await shot('27-assistant-info');
        await tap(find.text('Mengerti'));
        final s = tester
            .widget<AssistantPage>(find.byType(AssistantPage))
            .store;
        final rev = await s.repository.revisions();
        s.message = 'Besok baca jurnal 30 menit. Tadi makan 18 ribu.';
        s.draft = AssistantDraft(
          id: s.repository.newId(),
          operationId: s.repository.newId(),
          uid: auth.currentUser!.uid,
          baseAgendaRevision: rev['agenda']!,
          baseFinanceRevision: rev['finance']!,
          items: [
            DraftEntry(
              id: s.repository.newId(),
              quote: 'Besok baca jurnal 30 menit.',
              localDate: DateTime.parse(financeToday())
                  .add(const Duration(days: 1))
                  .toIso8601String()
                  .substring(0, 10),
              agenda: const AgendaInput(
                title: 'Baca jurnal',
                durationMinutes: 30,
              ),
            ),
            DraftEntry(
              id: s.repository.newId(),
              quote: 'Tadi makan 18 ribu.',
              localDate: financeToday(),
              money: TransactionInput(
                type: 'expense',
                amountRupiah: 18000,
                categoryId: 'food',
                localDate: financeToday(),
                description: 'Makan',
              ),
            ),
          ],
        );
        s.change(() {});
        await tester.pumpAndSettle();
        await shot('20-combined-review');
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('draft-save'))),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await shot('26-combined-review-actions');
        await tap(find.byKey(const ValueKey('draft-save')));
        expect(s.draft!.applied, true);
        Scrollable.of(tester.element(find.byType(AssistantPage))).position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await shot('21-combined-saved');
        s.discard();
        await tester.pumpAndSettle();
        tester.testTextInput.unregister();
        await tap(find.byKey(const ValueKey('assistant-message')));
        // First IME startup on an AVD can finish after the tap animation.
        // Wait for real platform insets, rather than assuming a fixed delay.
        for (var i = 0; i < 50 && tester.view.viewInsets.bottom == 0; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(
          tester.view.viewInsets.bottom,
          greaterThan(0),
          reason: 'Native IME must be visible',
        );
        await tester.pumpAndSettle();
        await shot('22-assistant-keyboard');
        expect(find.byKey(const ValueKey('tab-0')), findsNothing);
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        tester.testTextInput.register();
        // Native pickers retain platform behavior while sharing the Ruma theme.
        final nav = Navigator.of(tester.element(find.byType(MainShell)));
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => AgendaFormPage(store: agendaStore, kind: 'class'),
          ),
        );
        await tester.pumpAndSettle();
        await tap(find.byKey(const ValueKey('agenda-start')));
        await shot('23-date-picker');
        final dateContext = tester.element(find.byType(DatePickerDialog));
        await tap(
          find.text(MaterialLocalizations.of(dateContext).okButtonLabel).last,
        );
        await shot('24-time-picker');
        final timeContext = tester.element(find.byType(TimePickerDialog));
        await tap(
          find
              .text(MaterialLocalizations.of(timeContext).cancelButtonLabel)
              .last,
        );
        nav.pop();
        await tester.pumpAndSettle();
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        await tester.pumpAndSettle();
        await tap(find.byKey(const ValueKey('tab-3')));
        await shot('25-finance-large-text');
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
        agendaStore.dispose();
        financeStore.dispose();
        binding.reportData!['passed'] = true;
      } finally {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await auth.currentUser?.delete();
        session.dispose();
      }
    },
  );
}
