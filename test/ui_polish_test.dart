import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ruma/data/savings_store.dart';
import 'package:ruma/features/savings/savings_page.dart';
import 'package:ruma/features/savings/savings_form.dart';
import 'package:ruma/features/profile/personal_settings_page.dart';

import 'helpers/savings_fixture.dart';
import 'final_stages_test.dart' show SettingsFake;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/features/agenda/agenda_page.dart';
import 'package:ruma/features/agenda/agenda_form.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';
import 'package:ruma/features/finance/finance_page.dart';
import 'package:ruma/features/finance/finance_forms.dart';
import 'package:ruma/features/finance/transaction_detail.dart';
import 'package:ruma/features/auth/auth_form.dart';
import 'package:ruma/features/auth/welcome_page.dart';
import 'package:ruma/features/home/home_page.dart';
import 'package:ruma/features/profile/profile_page.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/main.dart';
import 'package:ruma/ui/components.dart';

import 'foundation_test.dart' as foundation;
import 'assistant_test.dart' as fixtures;

void main() {
  const capture = bool.fromEnvironment('UI_AUDIT_CAPTURE');
  setUpAll(() async {
    if (capture) {
      final loader = FontLoader('Manrope')
        ..addFont(
          rootBundle.load('design/assets/ruma/fonts/Manrope-Variable.ttf'),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(390, 844),
    const Size(320, 640),
    const Size(844, 390),
  ]) {
    testWidgets(
      'all pages remain scrollable at $size, including large type and keyboard',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = foundation.session(signedIn: true),
            guest = foundation.session();
        final s = fixtures.makeStore(
          fixtures.DraftRepoFake(),
          fixtures.ServiceFake(),
        );
        final a = AgendaItem(
          id: 'a1',
          version: 1,
          input: AgendaInput(
            title: 'Revisi laporan praktikum pemrograman mobile',
            startAtUtc: DateTime.utc(2026, 10, 19, 3),
            description:
                'Catatan kegiatan sintetis untuk memeriksa pembungkusan teks.',
          ),
        );
        s.agenda
          ..items = [a]
          ..loaded = true;
        final money = MoneyTransaction(
          id: 't1',
          version: 1,
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 1234567890,
            categoryId: 'housing',
            localDate: '2026-10-19',
            description: 'Catatan sintetis untuk menguji detail transaksi.',
          ),
        );
        s.finance
          ..month = '2026-10'
          ..snapshot = FinanceSnapshot(
            month: const MonthFinance(
              key: '2026-10',
              income: 2000000000,
              expense: 1234567890,
              budget: 1800000000,
              categoryExpense: {'housing': 1234567890},
            ),
            items: [money],
            balance: 765432110,
            revision: 1,
          );
        Widget shell(Widget child) => Scaffold(
          appBar: AppBar(title: const Text('Ruma')),
          body: RumaPageBody(child: child),
        );
        final settings = SettingsFake();
        final savings = SavingsStore(SavingsRepoFake())
          ..snapshot = savingsFixture(balance: s.finance.snapshot!.balance);
        addTearDown(settings.dispose);
        addTearDown(savings.dispose);
        final pages = <String, Widget Function()>{
          'personal profile': () => PersonalSettingsPage(store: settings),
          'ai preferences': () =>
              PersonalSettingsPage(store: settings, preferences: true),
          'savings': () => SavingsPage(store: savings),
          'savings detail': () =>
              SavingsDetailPage(store: savings, goalId: 'emergency'),
          'savings goal': () => SavingsFormPage(store: savings),
          'savings edit': () => SavingsFormPage(
            store: savings,
            goal: savings.snapshot!.goals.first,
          ),
          'savings deposit': () => SavingsFormPage(
            store: savings,
            goal: savings.snapshot!.goals.first,
            movement: 'deposit',
          ),
          'savings withdrawal': () => SavingsFormPage(
            store: savings,
            goal: savings.snapshot!.goals.first,
            movement: 'withdrawal',
          ),

          'welcome': () => WelcomePage(session: guest),
          'signin': () => AuthForm(session: guest),
          'signup': () => AuthForm(session: guest, signup: true),
          'home': () => shell(
            HomePage(
              account: auth.account!,
              onTab: (_) {},
              agenda: s.agenda,
              finance: s.finance,
              savings: savings,
            ),
          ),
          'agenda': () => shell(AgendaPage(store: s.agenda)),
          'agenda form': () => AgendaFormPage(store: s.agenda),
          'class form': () => AgendaFormPage(store: s.agenda, kind: 'class'),
          'agenda detail': () => AgendaDetailPage(store: s.agenda, id: a.id),
          'finance': () => shell(
            FinancePage(store: s.finance, savings: savings, onAssistant: () {}),
          ),
          'expense': () => FinanceFormPage(store: s.finance),
          'income': () => FinanceFormPage(store: s.finance, type: 'income'),
          'budget': () => FinanceFormPage(store: s.finance, budget: true),
          'history': () => FinanceRecordsPage(store: s.finance),
          'report': () => FinanceRecordsPage(store: s.finance, report: true),
          'transaction detail': () =>
              TransactionDetailPage(store: s.finance, id: money.id),
          'profile': () => shell(
            ProfilePage(
              session: auth,
              settings: settings,
              onNotifications: () {},
            ),
          ),
          'assistant': () => shell(AssistantPage(store: s, onTab: (_) {})),
        };
        final scaler = size.width == 320 ? 2.0 : 1.0;
        Widget host(Widget child, {double keyboard = 0}) => MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: rumaTheme(),
          locale: const Locale('id'),
          supportedLocales: const [Locale('id')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(scaler),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: child,
        );
        for (final page in pages.entries) {
          await tester.pumpWidget(host(page.value()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: page.key);
          if (capture && size.width == 390) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../docs/qa/ui-simplicity/${page.key.replaceAll(' ', '-')}.png',
              ),
            );
          }
          if (page.key == 'assistant') {
            await tester.tap(find.byTooltip('Tentang Asisten'));
            await tester.pumpAndSettle();
            expect(find.text('Tentang Asisten'), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'assistant help');
            await tester.ensureVisible(find.text('Mengerti'));
            await tester.tap(find.text('Mengerti'));
            await tester.pumpAndSettle();
          }
          final scroll = find.byType(Scrollable).first;
          await tester.drag(scroll, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.key} scrolled',
          );
        }
        // Shared review, both before and after commit.
        s.draft = AssistantDraft(
          id: 'draft',
          operationId: 'op',
          uid: 'owner',
          items: parseProposal(
            [fixtures.proposal(), fixtures.proposal(money: true)],
            fixtures.source,
            () => s.repository.newId(),
          ),
          baseAgendaRevision: 0,
          baseFinanceRevision: 0,
        );
        for (final applied in [false, true]) {
          s.draft!.applied = applied;
          await tester.pumpWidget(
            host(shell(AssistantPage(store: s, onTab: (_) {}))),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'draft/applied=$applied',
          );
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -4000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        // IME leaves every auth action reachable, also in phone landscape.
        await tester.pumpWidget(
          host(AuthForm(session: guest, signup: true), keyboard: 220),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'signup + keyboard');
        await tester.pumpWidget(
          host(
            shell(
              ProfilePage(
                session: auth,
                settings: settings,
                onNotifications: () {},
              ),
            ),
            keyboard: 220,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ubah nama panggilan'));
        await tester.tap(find.text('Ubah nama panggilan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'profile edit dialog');
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
        guest.dispose();
        s.dispose();
        s.agenda.dispose();
        s.finance.dispose();
      },
    );
  }
  testWidgets(
    'duration shortcuts preserve custom values and respect disabled state',
    (tester) async {
      final controller = TextEditingController(text: '45');
      addTearDown(controller.dispose);
      var changes = 0;
      Future<void> host(bool enabled) => tester.pumpWidget(
        MaterialApp(
          theme: rumaTheme(),
          home: Scaffold(
            body: RumaDurationChoices(
              controller: controller,
              enabled: enabled,
              onChanged: () => changes++,
            ),
          ),
        ),
      );
      await host(true);
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((c) => !c.selected),
        isTrue,
      );
      await tester.tap(find.text('30 menit'));
      await tester.pump();
      expect(controller.text, '30');
      expect(changes, 1);
      controller.text = '75';
      await tester.pump();
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((c) => !c.selected),
        isTrue,
      );
      await host(false);
      await tester.tap(find.text('15 menit'));
      expect(controller.text, '75');
      expect(changes, 1);
    },
  );
  testWidgets('navigation makes room for IME without losing a tab', (
    tester,
  ) async {
    final auth = foundation.session(signedIn: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(RumaApp(session: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-2')));
    await tester.pumpAndSettle();
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tab-0')), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tab-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
