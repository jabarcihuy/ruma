import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/home/home_page.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';
import 'package:ruma/features/finance/finance_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('home uses real SDK summaries, exact details and current month', (
    t,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) throw StateError('demo-ruma only');
    final session = await initializeSession(),
        auth = FirebaseAuth.instance,
        db = initializeAgendaDatabase();
    final cases = <String>[], screens = <String>[];
    binding.reportData = {
      'project': 'demo-ruma',
      'productionWrites': 0,
      'modelCalls': 0,
      'fcmSends': 0,
      'cases': cases,
      'screens': screens,
    };
    Future<void> shot(String name) async {
      expect(t.takeException(), isNull);
      final client = HttpClient();
      try {
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:8766/$name'),
        );
        final r = await req.close();
        await r.drain<void>();
        expect(r.statusCode, 200);
        screens.add(name);
      } finally {
        client.close(force: true);
      }
    }

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 200 && !condition(); i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), true);
      await t.pumpAndSettle();
    }

    try {
      await auth.signOut();
      await t.pumpWidget(RumaApp(session: session, firestore: db));
      await t.pumpAndSettle();
      expect(await session.enterTemporarily(), true);
      await t.pumpAndSettle();
      var home = t.widget<HomePage>(find.byType(HomePage));
      await waitFor(
        () =>
            home.agenda!.loaded &&
            !home.finance!.loading &&
            home.finance!.snapshot != null,
      );
      expect(find.text('0 kegiatan'), findsOneWidget);
      expect(find.text('Belum diatur'), findsOneWidget);
      await shot('01-home-empty');
      final ar = AgendaRepository(db, auth),
          fr = FinanceRepository(db, auth),
          now = DateTime.now().toUtc();
      final nextId = ar.newId(), dueId = ar.newId();
      await ar.save(
        AgendaMutation(
          operationId: ar.newId(),
          id: nextId,
          input: AgendaInput(
            title: 'Praktikum pemrograman mobile',
            kind: 'class',
            startAtUtc: now.add(const Duration(minutes: 30)),
            durationMinutes: 90,
          ),
        ),
      );
      await ar.save(
        AgendaMutation(
          operationId: ar.newId(),
          id: dueId,
          input: AgendaInput(
            title: 'Kumpulkan laporan praktikum',
            durationMinutes: 30,
            deadlineAtUtc: now.add(const Duration(hours: 5)),
          ),
        ),
      );
      for (final income in [true, false]) {
        await fr.save(
          FinanceMutation(
            operationId: fr.newId(),
            id: fr.newId(),
            input: TransactionInput(
              type: income ? 'income' : 'expense',
              amountRupiah: income ? 1500000 : 18000,
              categoryId: income ? 'allowance' : 'food',
              localDate: financeToday(),
            ),
          ),
        );
      }
      final month = financeToday().substring(0, 7),
          data = await fr.read(financeToday().substring(0, 7));
      await fr.save(
        FinanceMutation(
          operationId: fr.newId(),
          id: month,
          originalVersion: data.month.version,
          budget: BudgetInput(monthKey: month, total: 700000),
        ),
      );
      await home.agenda!.load();
      await home.finance!.load(month);
      await t.pumpAndSettle();
      expect(home.agenda!.error, isNull);
      expect(home.finance!.error, isNull);
      expect(find.text('Praktikum pemrograman mobile'), findsOneWidget);
      expect(find.text('Kumpulkan laporan praktikum'), findsOneWidget);
      expect(find.text('Rp1.482.000'), findsOneWidget);
      expect(find.text('Rp18.000'), findsOneWidget);
      expect(find.text('Rp682.000'), findsOneWidget);
      cases.add(
        'current agenda and canonical balance, expense and budget match real SDK',
      );
      await shot('02-home-populated');
      await t.ensureVisible(find.text('Lihat keuangan'));
      await t.pumpAndSettle();
      await shot('03-home-money');
      await t.ensureVisible(find.text('Kumpulkan laporan praktikum'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kumpulkan laporan praktikum'));
      await t.pumpAndSettle();
      expect(
        t.widget<AgendaDetailPage>(find.byType(AgendaDetailPage)).id,
        dueId,
      );
      await t.tap(find.byTooltip('Kembali'));
      await t.pumpAndSettle();
      cases.add('deadline opens the exact agenda detail');
      await t.tap(find.byKey(const ValueKey('tab-3')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('finance-previous')));
      await t.pumpAndSettle();
      final finance = t.widget<FinancePage>(find.byType(FinancePage)).store;
      await waitFor(() => !finance.loading);
      expect(finance.month, isNot(month));
      await t.tap(find.byKey(const ValueKey('tab-0')));
      await t.pumpAndSettle();
      home = t.widget<HomePage>(find.byType(HomePage));
      await waitFor(
        () =>
            !home.finance!.loading &&
            home.finance!.snapshot?.month.key == month,
      );
      expect(home.finance!.month, month);
      expect(find.text('Rp18.000'), findsOneWidget);
      expect(find.text('Rp682.000'), findsOneWidget);
      cases.add(
        'returning from an older finance report restores current month without relabelling old figures',
      );
      await shot('04-home-current-month');
      binding.reportData!['passed'] = true;
    } finally {
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await auth.currentUser?.delete();
      await auth.signOut();
      session.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
