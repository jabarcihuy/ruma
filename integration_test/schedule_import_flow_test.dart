import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/recurrence.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/schedule_import.dart';
import 'package:ruma/data/schedule_import_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/features/assistant/schedule_import_page.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'semester import review, receipt retry and source refresh protect local edits',
    (t) async {
      const live = bool.fromEnvironment('SCHEDULE_IMPORT_LIVE_TESTS');
      if (RumaFirebaseOptions.useEmulator == live) {
        throw StateError(
          'Use demo-ruma, or explicitly opt into the production fixture test.',
        );
      }
      final session = await initializeSession();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      await session.enterTemporarily();
      final uid = auth.currentUser!.uid, db = initializeAgendaDatabase();
      final repo = ScheduleImportRepository(db, auth),
          agenda = AgendaRepository(db, auth);
      final cases = <String>[], deleted = <String>[];
      binding.reportData = {
        'project': live ? 'mobile-app-3479f' : 'demo-ruma',
        'suite': live
            ? 'schedule_import_cloud_test'
            : 'schedule_import_flow_test',
        'fixtureUid': uid,
        'productionWrites': live ? 'synthetic fixture UID only' : 0,
        'authFixturesDeleted': deleted,
        'providerCalls': 0,
        'calendarSource':
            'synthetic Google rows; no real OAuth authorization in this test',
        'cases': cases,
      };
      Future<void> settle() => t.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 60),
      );
      Future<void> tap(Finder f) async {
        await t.ensureVisible(f);
        await settle();
        await t.tap(f);
        await settle();
      }

      Future<void> shot(String name) async {
        await settle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await binding.takeScreenshot(name);
        expect(t.takeException(), isNull);
      }

      ScheduleRow row(
        String id,
        String title,
        int day, {
        String version = 'v1',
      }) => ScheduleRow(
        id: id,
        title: title,
        weekday: day,
        start: '08:00',
        end: '09:40',
        provider: 'google',
        sourceKey: 'google:${scheduleHash(id)}',
        sourceVersion: version,
        calendarKey: scheduleHash('synthetic-calendar'),
        remote: {
          'calendarId': 'synthetic-calendar',
          'eventId': id,
          'account': 'fixture@example.invalid',
          'series': true,
        },
      );
      ScheduleWorkspace workspace(List<ScheduleRow> rows) => ScheduleWorkspace(
        id: repo.newId(),
        from: '2026-11-02',
        to: '2027-03-01',
        rows: rows,
        source: 'Kalender kuliah (fixture)',
        periodConfirmed: true,
      );
      try {
        await t.pumpWidget(RumaApp(session: session, firestore: db));
        await settle();
        await tap(find.byKey(const ValueKey('tab-2')));
        final assistant = t
            .widget<AssistantPage>(find.byType(AssistantPage))
            .store;
        final w = workspace([
          row('algoritma', 'Algoritma', 1),
          row('basis', 'Basis Data', 2),
        ]);
        expect((await repo.preview(w)).writes.length, 2);
        expect((await agenda.read()).series, isEmpty);
        assistant.updateScheduleWorkspace(w.toJson());
        await assistant.flush();
        Navigator.of(t.element(find.byType(AssistantPage))).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ScheduleImportPage(assistant: assistant, repository: repo),
          ),
        );
        await settle();
        await binding.convertFlutterSurfaceToImage();
        await shot('01-import-review');
        await tap(find.byKey(const ValueKey('schedule-import-save')));
        expect(
          find.textContaining('Penyimpanan terkonfirmasi.'),
          findsOneWidget,
        );
        await shot('02-import-confirmed');
        final committed = ScheduleWorkspace.fromJson(
          assistant.scheduleWorkspace!,
        );
        var snapshot = await agenda.read();
        expect(snapshot.series.length, 2);
        expect(
          scheduleOccurrences(
            snapshot.series
                .firstWhere((a) => a.input.title == 'Algoritma')
                .input,
            'series',
            w.from,
            w.to,
          ).length,
          18,
        );
        await repo.apply(committed);
        expect((await agenda.read()).series.length, 2);
        cases.add(
          'review then atomic two-series commit, eighteen Monday meetings and idempotent receipt retry',
        );
        final identical = await repo.preview(
          workspace([
            row('algoritma', 'Algoritma', 1),
            row('basis', 'Basis Data', 2),
          ]),
        );
        expect(identical.writes, isEmpty);
        cases.add('same source refresh creates no duplicates');
        final first = snapshot.series.firstWhere(
          (a) => a.input.title == 'Algoritma',
        );
        await agenda.save(
          AgendaMutation(
            operationId: repo.newId(),
            id: first.id,
            originalVersion: first.version,
            input: agendaJson({
              ...first.input.toJson(),
              'title': 'Algoritma lokal',
            }),
          ),
        );
        final local = (await agenda.read()).series.firstWhere(
          (a) => a.id == first.id,
        );
        expect(local.importSource, first.importSource);
        final changed = workspace([
          row('algoritma', 'Algoritma baru dari Google', 1, version: 'v2'),
        ]);
        var preview = await repo.preview(changed);
        expect(preview.rows.single.requiresChoice, isTrue);
        expect(preview.canSave, isFalse);
        changed.rows.single.useSource = true;
        changed.changed();
        preview = await repo.preview(changed);
        expect(preview.canSave, isTrue);
        repo.prepare(changed, preview);
        changed.attempted = true;
        await repo.apply(changed);
        snapshot = await agenda.read();
        expect(snapshot.series.length, 2);
        expect(
          snapshot.series.firstWhere((a) => a.id == first.id).input.title,
          'Algoritma baru dari Google',
        );
        cases.add(
          'manual edit preserves linkage and source refresh requires an explicit choice',
        );
        final core =
            (await db
                    .collection('users')
                    .doc(uid)
                    .collection('state')
                    .doc('core')
                    .get())
                .data()!;
        expect(core['balanceRupiah'], 0);
        expect(core['financeRevision'], 0);
        cases.add('import and source update leave finances unchanged');
        final conflict = workspace([
          row('overlap', 'Bentrok akhir semester', 1)..date = '2027-02-01',
        ]);
        expect((await repo.preview(conflict)).canSave, isFalse);
        cases.add('overlap beyond ninety days is blocked');
        final cancellation = workspace([
          row('basis', 'Basis Data', 2, version: 'cancelled')..cancelled = true,
        ]);
        final deletion = await repo.preview(cancellation);
        expect(deletion.rows.single.action, 'delete');
        repo.prepare(cancellation, deletion);
        cancellation.attempted = true;
        await repo.apply(cancellation);
        expect((await agenda.read()).series.length, 1);
        final deletedRefresh = await repo.preview(
          workspace([row('basis', 'Basis Data', 2)]),
        );
        expect(deletedRefresh.rows.single.action, 'skip');
        expect(deletedRefresh.writes, isEmpty);
        cases.add(
          'explicit source cancellation creates a tombstone and reimport never silently resurrects it',
        );
        await tap(find.byTooltip('Kembali'));
        await settle();
        await shot('03-chat-home');
      } finally {
        await t.pumpWidget(const SizedBox());
        await settle();
        await auth.currentUser?.delete();
        deleted.add(uid);
        session.dispose();
      }
    },
  );
}
