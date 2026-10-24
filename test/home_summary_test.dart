import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/agenda/agenda_detail.dart';
import 'package:ruma/features/home/home_page.dart';
import 'package:ruma/ui/components.dart';

import 'assistant_test.dart' as fixture;
import 'helpers/savings_fixture.dart';

import 'package:ruma/data/savings_store.dart';

import 'package:ruma/data/auth_session.dart';

final instant = DateTime.utc(2026, 10, 21, 3);
AgendaItem item(
  String id,
  String title, {
  DateTime? start,
  DateTime? due,
  String status = 'planned',
}) => AgendaItem(
  id: id,
  version: 1,
  input: AgendaInput(
    title: title,
    startAtUtc: start,
    deadlineAtUtc: due,
    status: status,
  ),
);
FinanceSnapshot money({
  int balance = 820000,
  int expense = 180000,
  int? budget = 500000,
}) => FinanceSnapshot(
  month: MonthFinance(key: '2026-10', expense: expense, budget: budget),
  items: [],
  balance: balance,
  revision: 1,
);

class PeriodRepo extends fixture.FinanceRepoFake {
  final months = <String>[];
  @override
  Future<FinanceSnapshot> read(String month) async {
    months.add(month);
    return money();
  }
}

void main() {
  late AgendaStore agenda;
  late FinanceStore finance;
  late PeriodRepo repo;
  late SavingsStore savings;
  setUp(() {
    agenda = AgendaStore(fixture.AgendaRepoFake())..loaded = true;
    savings = SavingsStore(SavingsRepoFake())..snapshot = savingsFixture();
    repo = PeriodRepo();
    finance = FinanceStore(repo)
      ..month = '2026-10'
      ..snapshot = money();
  });
  tearDown(() {
    agenda.dispose();
    finance.dispose();
    savings.dispose();
  });
  Widget page({ValueChanged<int>? onTab, double scale = 1}) => MaterialApp(
    key: UniqueKey(),
    theme: rumaTheme(),
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: RumaPageBody(
        child: HomePage(
          account: const RumaAccount(
            uid: 'synthetic',
            name: 'Naya',
            anonymous: false,
          ),
          onTab: onTab ?? (_) {},
          agenda: agenda,
          finance: finance,
          savings: savings,
          now: instant,
        ),
      ),
    ),
  );
  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  testWidgets(
    'only planned items count; ongoing and overdue have priority; detail opens exact item',
    (t) async {
      agenda.items = [
        item(
          'past',
          'Sesi berakhir',
          start: instant.subtract(const Duration(hours: 2)),
        ),
        item(
          'ongoing',
          'Kuliah berlangsung',
          start: instant.subtract(const Duration(minutes: 30)),
        ),
        item(
          'next',
          'Sesi nanti',
          start: instant.add(const Duration(hours: 2)),
        ),
        item(
          'late',
          'Laporan terlambat',
          due: instant.subtract(const Duration(days: 1)),
        ),
        item(
          'future',
          'Deadline berikut',
          due: instant.add(const Duration(days: 1)),
        ),
        item(
          'done',
          'Tugas selesai',
          due: instant.subtract(const Duration(days: 2)),
          status: 'completed',
        ),
        item(
          'cancelled',
          'Kuliah dibatalkan',
          start: instant,
          status: 'cancelled',
        ),
      ];
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('3 kegiatan'), findsOneWidget);
      expect(find.text('2 belum dijadwalkan'), findsOneWidget);
      expect(find.text('Sedang berlangsung'), findsOneWidget);
      expect(find.text('Kuliah berlangsung'), findsOneWidget);
      expect(find.text('Deadline terlewat'), findsOneWidget);
      expect(find.text('Laporan terlambat'), findsOneWidget);
      expect(find.text('Tugas selesai'), findsNothing);
      expect(find.text('Kuliah dibatalkan'), findsNothing);
      await tap(t, 'Laporan terlambat');
      expect(
        t.widget<AgendaDetailPage>(find.byType(AgendaDetailPage)).id,
        'late',
      );
    },
  );
  testWidgets(
    'upcoming excludes exact end boundary and includes next-day class; deadline can be unscheduled',
    (t) async {
      agenda.items = [
        item(
          'end',
          'Baru berakhir',
          start: instant.subtract(const Duration(hours: 1)),
        ),
        item(
          'tomorrow',
          'Kuliah besok',
          start: instant.add(const Duration(days: 1)),
        ),
        item('due', 'Kirim tugas', due: instant.add(const Duration(hours: 3))),
      ];
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('Berikutnya'), findsOneWidget);
      expect(find.text('Kuliah besok'), findsOneWidget);
      expect(find.text('Besok · 10.00'), findsOneWidget);
      expect(find.text('Kirim tugas'), findsOneWidget);
      expect(find.text('Hari ini · 13.00'), findsOneWidget);
      expect(find.text('Baru berakhir'), findsNothing);
    },
  );
  testWidgets(
    'current month replaces old selected report and uses canonical totals',
    (t) async {
      finance
        ..month = '2026-09'
        ..snapshot = const FinanceSnapshot(
          month: MonthFinance(key: '2026-09', expense: 999999),
          items: [],
          balance: 999999,
          revision: 0,
        );
      final tabs = <int>[];
      await t.pumpWidget(page(onTab: tabs.add));
      await t.pumpAndSettle();
      expect(repo.months, ['2026-10']);
      expect(find.text('Rp999.999'), findsNothing);
      expect(find.text('Rp820.000'), findsOneWidget);
      expect(find.text('Rp180.000'), findsOneWidget);
      expect(find.text('Rp400.000'), findsOneWidget);
      expect(find.text('Tersedia Rp420.000'), findsOneWidget);
      await tap(t, 'Lihat keuangan');
      expect(tabs.last, 3);
      await tap(t, 'Lihat agenda');
      expect(tabs.last, 1);
      await t.ensureVisible(find.byKey(const ValueKey('home-assistant')));
      await t.tap(find.byKey(const ValueKey('home-assistant')));
      expect(tabs.last, 2);
    },
  );
  testWidgets(
    'legacy budgets do not affect savings and available may be negative',
    (t) async {
      for (final budget in <int?>[null, 0, 100000]) {
        finance.snapshot = money(balance: -180000, budget: budget);
        savings.snapshot = savingsFixture(balance: -180000);
        await t.pumpWidget(page());
        await t.pumpAndSettle();
        expect(find.text('-Rp180.000'), findsOneWidget);
        expect(find.text('Rp400.000'), findsOneWidget);
        expect(find.text('Tersedia -Rp580.000'), findsOneWidget);
        expect(find.textContaining('anggaran'), findsNothing);
      }
    },
  );
  testWidgets(
    'empty, loading and error do not invent or display stale totals; retry recovers',
    (t) async {
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('Belum ada jadwal'), findsOneWidget);
      expect(find.text('Tidak ada deadline'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Berikutnya')).dy,
        t.getTopLeft(find.text('Deadline terdekat')).dy,
      );
      agenda.loading = true;
      finance.loading = true;
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('Memuat agenda…'), findsOneWidget);
      expect(find.text('Memuat keuangan…'), findsOneWidget);
      expect(find.text('Rp820.000'), findsNothing);
      agenda
        ..loading = false
        ..error = 'offline';
      finance
        ..loading = false
        ..error = 'offline';
      await t.pumpWidget(page());
      await t.pumpAndSettle();
      expect(find.text('Rp820.000'), findsNothing);
      await t.ensureVisible(find.text('Muat ulang').first);
      await t.tap(find.text('Muat ulang').first);
      await t.pumpAndSettle();
      expect(find.text('Rp820.000'), findsOneWidget);
      expect(find.text('Agenda belum termuat.'), findsNothing);
    },
  );
  testWidgets(
    'WIB midnight selects new month and counts a class crossing midnight',
    (t) async {
      final at = DateTime.utc(2026, 10, 31, 17, 5);
      agenda.items = [
        item(
          'midnight',
          'Kegiatan lintas malam',
          start: at.subtract(const Duration(minutes: 20)),
        ),
      ];
      await t.pumpWidget(
        MaterialApp(
          theme: rumaTheme(),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('id')],
          locale: const Locale('id'),
          home: Scaffold(
            body: RumaPageBody(
              child: HomePage(
                account: const RumaAccount(
                  uid: 'synthetic',
                  name: 'Naya',
                  anonymous: false,
                ),
                onTab: (_) {},
                agenda: agenda,
                finance: finance,
                now: at,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.months, ['2026-11']);
      // A repository returning the wrong month must never be relabelled November.
      expect(find.text('Rp820.000'), findsNothing);
      expect(find.text('1 kegiatan'), findsOneWidget);
      expect(find.text('Sedang berlangsung'), findsOneWidget);
    },
  );
  testWidgets(
    'long populated summaries fit small landscape and 200 percent text',
    (t) async {
      agenda.items = [
        item(
          'long',
          'Praktikum pengembangan aplikasi dan penyusunan laporan penelitian mahasiswa',
          start: instant.add(const Duration(hours: 1)),
          due: instant.add(const Duration(hours: 4)),
        ),
      ];
      finance.snapshot = money(
        balance: -9876543210,
        expense: 1000000000,
        budget: 0,
      );
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      t.view.devicePixelRatio = 1;
      for (final size in [const Size(320, 640), const Size(844, 390)]) {
        t.view.physicalSize = size;
        await t.pumpWidget(page(scale: size.width == 320 ? 2 : 1));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Lihat keuangan'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(
          t.getSize(find.byType(TextButton).last).height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );
}
