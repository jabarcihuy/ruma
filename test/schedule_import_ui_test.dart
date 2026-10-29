import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/schedule_images.dart';
import 'package:ruma/data/schedule_import.dart';
import 'package:ruma/data/schedule_import_repository.dart';
import 'package:ruma/features/assistant/schedule_import_page.dart';

import 'assistant_test.dart' as f;

class Images extends Fake implements ScheduleImages {
  @override
  Future<List<ScheduleImage>> pending() async => [];
  @override
  Future<void> clear() async {}
}

class ImportRepo extends Fake implements ScheduleImportRepository {
  int attempts = 0;
  final keys = <String>[];
  bool uncertain = false;
  @override
  String get uid => 'owner';
  @override
  void check() {}
  @override
  String newId() => 'next';
  @override
  Future<ImportPreview> preview(ScheduleWorkspace w) async => ImportPreview([
    for (final r in w.rows)
      ImportPreviewRow(
        r,
        input: r.build(w.from, w.to),
        message: 'Jadwal baru.',
      ),
  ], 0);
  @override
  void prepare(ScheduleWorkspace w, ImportPreview p) {
    w.operationId = 'same-operation';
    w.plans = [
      {'id': 'target', 'version': 0},
    ];
  }

  @override
  Future<int> apply(ScheduleWorkspace w) async {
    attempts++;
    keys.add(w.requestKey);
    if (uncertain) {
      throw const SocketException('synthetic missing acknowledgement');
    }
    w.applied = true;
    w.resultCount = 1;
    return 1;
  }
}

class Corrections extends f.ServiceFake {
  @override
  Future<Map<String, dynamic>> correctSchedule(
    List<Map<String, dynamic>> rows,
    List<Map<String, String>> messages,
  ) async => {
    'type': 'schedule_correction',
    'updates': [
      {
        'index': 0,
        'title': 'Basis Data',
        'weekday': 4,
        'date': null,
        'start': '10:00',
        'end': '11:40',
        'location': 'Lab',
        'included': true,
      },
    ],
    'question': '',
  };
}

ScheduleWorkspace initial() => ScheduleWorkspace(
  id: 'import',
  from: '2026-11-02',
  to: '2027-03-01',
  periodConfirmed: true,
  rows: [
    ScheduleRow(
      id: 'row',
      title: 'Basis Data',
      weekday: 2,
      start: '10:00',
      end: '11:40',
      location: 'Lab',
    ),
  ],
);
void main() {
  testWidgets(
    'correction changes only the proposal and narrow large text review stays usable',
    (t) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = ImportRepo(),
          s = f.makeStore(f.DraftRepoFake(), Corrections());
      s.updateScheduleWorkspace(initial().toJson());
      await t.pumpWidget(
        f.app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ScheduleImportPage(
              assistant: s,
              repository: repo,
              images: Images(),
            ),
          ),
          form: true,
        ),
      );
      await t.pumpAndSettle();
      final input = find.byKey(const ValueKey('schedule-correction'));
      await t.ensureVisible(input);
      await t.enterText(input, 'Pindah Kamis');
      await t.ensureVisible(find.text('Perbarui usulan'));
      await t.tap(find.text('Perbarui usulan'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Izinkan koreksi'));
      await t.tap(find.text('Izinkan koreksi'));
      await t.pumpAndSettle();
      expect(s.scheduleWorkspace!['rows'][0]['weekday'], 4);
      expect(repo.attempts, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
  testWidgets(
    'unknown save result locks editing and retry uses the same receipt identity',
    (t) async {
      final repo = ImportRepo()..uncertain = true,
          s = f.makeStore(f.DraftRepoFake(), f.ServiceFake());
      s.updateScheduleWorkspace(initial().toJson());
      Future<void> mount() async {
        await t.pumpWidget(
          f.app(
            ScheduleImportPage(
              assistant: s,
              repository: repo,
              images: Images(),
            ),
            form: true,
          ),
        );
        await t.pumpAndSettle();
      }

      Future<void> save() async {
        final button = find.byKey(const ValueKey('schedule-import-save'));
        await t.ensureVisible(button);
        await t.tap(button);
        await t.pumpAndSettle();
      }

      await mount();
      await save();
      expect(repo.attempts, 1);
      expect(s.scheduleWorkspace!['attempted'], true);
      expect(find.byKey(const ValueKey('schedule-correction')), findsNothing);
      await t.pumpWidget(const SizedBox());
      repo.uncertain = false;
      await mount();
      await save();
      expect(repo.attempts, 2);
      expect(repo.keys.toSet().length, 1);
      expect(s.scheduleWorkspace!['applied'], true);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
}
