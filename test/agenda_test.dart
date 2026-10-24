import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/features/agenda/agenda_form.dart';
import 'package:ruma/features/agenda/agenda_page.dart';
import 'package:ruma/app/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class TestAgendaRepository extends Fake implements AgendaRepository {
  Future<AgendaSnapshot> Function()? onRead;
  Future<AgendaSnapshot> Function(AgendaMutation)? onSave;
  @override
  String get uid => 'synthetic';
  @override
  String newId() => 'synthetic-id';
  @override
  Future<AgendaSnapshot> read() async =>
      onRead == null ? const AgendaSnapshot([], 0) : onRead!();
  @override
  Future<AgendaSnapshot> save(AgendaMutation mutation) async =>
      onSave!(mutation);
}

Widget app(Widget child) => MaterialApp(
  theme: rumaTheme(),
  locale: const Locale('id'),
  supportedLocales: const [Locale('id')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);
void main() {
  test('server-bound inputs reject missing class time, invalid duration and deadline overflow', () {
    expect(
      const AgendaInput(title: 'Kuliah', kind: 'class').validate(),
      isNotNull,
    );
    expect(
      const AgendaInput(title: 'Tugas', durationMinutes: 0).validate(),
      isNotNull,
    );
    expect(
      AgendaInput(
        title: 'Tugas',
        startAtUtc: DateTime.utc(2026, 10, 20, 3),
        deadlineAtUtc: DateTime.utc(2026, 10, 20, 3, 30),
      ).validate(),
      isNotNull,
    );
    expect(
      const AgendaInput(title: 'Tugas', startAtUtc: null).validate(),
      isNull,
    );
  });
  test('adjacent sessions are allowed; overlap excludes completed and cancelled agenda', () {
    final a = AgendaInput(
      title: 'A',
      startAtUtc: DateTime.utc(2026, 10, 20, 3),
    );
    expect(
      a.overlaps(
        AgendaInput(title: 'B', startAtUtc: DateTime.utc(2026, 10, 20, 4)),
      ),
      isFalse,
    );
    final overlap = AgendaInput(
      title: 'B',
      startAtUtc: DateTime.utc(2026, 10, 20, 3, 30),
    );
    expect(a.overlaps(overlap), isTrue);
    expect(a.overlaps(overlap.withStatus('completed')), isFalse);
    expect(a.overlaps(overlap.withStatus('cancelled')), isFalse);
  });
  test('WIB date conversion and midnight boundaries do not depend on the device zone', () {
    final first = DateTime.utc(2026, 10, 20),
        second = DateTime.utc(2026, 10, 21);
    final item = AgendaItem(
      id: 'a',
      version: 1,
      input: AgendaInput(title: 'Malam', startAtUtc: agendaUtc(first, 23, 30)),
    );
    expect(item.occursOn(first), isTrue);
    expect(item.occursOn(second), isTrue);
    final midnight = AgendaItem(
      id: 'b',
      version: 1,
      input: AgendaInput(title: 'Malam', startAtUtc: agendaUtc(first, 23, 0)),
    );
    expect(midnight.occursOn(second), isFalse);
    expect(agendaLocal(agendaUtc(second, 8, 0)).hour, 8);
  });
  test('account disposal discards late asynchronous data', () async {
    final pending = Completer<AgendaSnapshot>();
    final repo = TestAgendaRepository()..onRead = () => pending.future;
    final store = AgendaStore(repo);
    final loading = store.load();
    store.dispose();
    pending.complete(
      AgendaSnapshot([
        const AgendaItem(
          id: 'old',
          version: 1,
          input: AgendaInput(title: 'Old account'),
        ),
      ], 1),
    );
    await loading;
    expect(store.items, isEmpty);
  });
  test(
    'failed writes keep current agenda and a retry uses the same operation',
    () async {
      final repo = TestAgendaRepository();
      final store = AgendaStore(repo);
      repo.onRead = () async => AgendaSnapshot([
        const AgendaItem(
          id: 'old',
          version: 1,
          input: AgendaInput(title: 'Existing'),
        ),
      ], 1);
      await store.load();
      AgendaMutation? first;
      var calls = 0;
      repo.onSave = (m) async {
        first ??= m;
        calls++;
        if (calls == 1) throw const AgendaFailure('Offline; isian tetap ada.');
        expect(m.operationId, first!.operationId);
        return AgendaSnapshot([
          ...store.items,
          AgendaItem(id: m.id, version: 1, input: m.input),
        ], 2);
      };
      const mutation = AgendaMutation(
        operationId: 'stable-op',
        id: 'new',
        input: AgendaInput(title: 'New'),
      );
      expect(await store.save(mutation), isFalse);
      expect(store.items.length, 1);
      expect(store.saving, isFalse);
      expect(await store.save(mutation), isTrue);
      expect(store.items.length, 2);
      store.dispose();
    },
  );
  testWidgets(
    'agenda form keeps validation and actions reachable at 320px and text 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AgendaStore(TestAgendaRepository());
      addTearDown(store.dispose);
      await tester.pumpWidget(app(AgendaFormPage(store: store)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('agenda-save')));
      await tester.tap(find.byKey(const ValueKey('agenda-save')));
      await tester.pumpAndSettle();
      expect(find.text('Isi nama kegiatan.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'agenda empty state and week navigation remain usable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = AgendaStore(TestAgendaRepository());
      await store.load();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AgendaPage(store: store),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Harimu masih lapang'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Minggu berikutnya'));
      await tester.tap(find.byTooltip('Minggu berikutnya'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
