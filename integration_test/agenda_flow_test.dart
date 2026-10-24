import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'manual agenda UI and Firestore: CRUD, retry, conflict, offline and account isolation',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError('This suite only runs against local demo-ruma');
      }
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final session = await initializeSession();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      await session.enterTemporarily();
      final owner = auth.currentUser!.uid;
      final db = initializeAgendaDatabase();
      final repository = AgendaRepository(db, auth);
      await tester.pumpWidget(RumaApp(session: session, firestore: db));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      Future<void> settle() async {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 60),
        );
      }

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await settle();
      }

      Future<void> textTap(String text) async => tap(find.text(text).last);
      Future<void> shot(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await settle();
        await binding.takeScreenshot(name);
      }

      Future<void> enter(String key, String value) async {
        await tester.enterText(find.byKey(ValueKey(key)), value);
        await tester.pump();
      }

      try {
        await tap(find.byKey(const ValueKey('tab-1')));
        await settle();
        expect(find.text('Harimu masih lapang'), findsOneWidget);
        await shot('01-agenda-empty');
        await tap(find.byKey(const ValueKey('agenda-add')));
        await textTap('Tugas / kegiatan');
        await enter('agenda-title', 'Laporan praktikum sintetis');
        await enter('agenda-duration', '45');
        await shot('02-agenda-form');
        await tap(find.byKey(const ValueKey('agenda-save')));
        expect(find.text('Laporan praktikum sintetis'), findsOneWidget);
        var saved = (await repository.read()).items.single;
        final originalId = saved.id;
        await textTap('Laporan praktikum sintetis');
        await textTap('Edit kegiatan');
        await enter('agenda-title', 'Laporan praktikum diperbarui');
        await tap(find.byKey(const ValueKey('agenda-save')));
        expect(find.text('Laporan praktikum diperbarui'), findsOneWidget);
        await shot('03-agenda-detail');
        saved = (await repository.read()).items.single;
        expect(saved.id, originalId);
        expect(saved.version, 2);
        await tap(find.byKey(const ValueKey('agenda-complete')));
        expect(find.text('SELESAI'), findsOneWidget);
        await textTap('Laporan praktikum diperbarui');
        await tap(find.byKey(const ValueKey('agenda-complete')));
        saved = (await repository.read()).items.single;
        expect(saved.input.status, 'planned');
        await textTap('Laporan praktikum diperbarui');
        await textTap('Hapus kegiatan');
        await textTap('Batalkan');
        expect((await repository.read()).items.length, 1);
        await textTap('Hapus kegiatan');
        await textTap('Hapus kegiatan');
        expect((await repository.read()).items, isEmpty);
        expect(
          (await db
                  .doc('users/$owner/agenda/$originalId')
                  .get(const GetOptions(source: Source.server)))
              .data()!['deletedAt'],
          isA<Timestamp>(),
        );
        // Real SDK transactions, using the same repository the UI uses.
        final day = agendaDay(agendaLocal(DateTime.now().toUtc()));
        final first = AgendaMutation(
          operationId: repository.newId(),
          id: repository.newId(),
          input: AgendaInput(
            title: 'Kuliah sintetis',
            kind: 'class',
            startAtUtc: agendaUtc(day, 9, 0),
          ),
        );
        await repository.save(first);
        final overlap = AgendaMutation(
          operationId: repository.newId(),
          id: repository.newId(),
          input: AgendaInput(
            title: 'Bentrok',
            startAtUtc: agendaUtc(day, 9, 30),
          ),
        );
        await expectLater(
          repository.save(overlap),
          throwsA(isA<AgendaFailure>()),
        );
        final adjacent = AgendaMutation(
          operationId: repository.newId(),
          id: repository.newId(),
          input: AgendaInput(
            title: 'Sesi berikutnya',
            startAtUtc: agendaUtc(day, 10, 0),
          ),
        );
        final once = await repository.save(adjacent);
        final retry = await repository.save(adjacent);
        expect(once.revision, retry.revision);
        expect(retry.items.length, 2);
        final initial = retry.items.firstWhere((a) => a.id == first.id);
        await repository.save(
          AgendaMutation(
            operationId: repository.newId(),
            id: first.id,
            input: initial.input.withStatus('completed'),
            originalVersion: initial.version,
          ),
        );
        await expectLater(
          repository.save(
            AgendaMutation(
              operationId: repository.newId(),
              id: first.id,
              input: initial.input,
              originalVersion: initial.version,
            ),
          ),
          throwsA(isA<AgendaFailure>()),
        );
        await tap(find.byTooltip('Muat ulang agenda'));
        await shot('04-agenda-timeline');
        await db.disableNetwork();
        final offline = AgendaMutation(
          operationId: repository.newId(),
          id: repository.newId(),
          input: const AgendaInput(title: 'Tidak boleh antre otomatis'),
        );
        try {
          await expectLater(repository.save(offline), throwsA(anything));
        } finally {
          await db.enableNetwork();
        }
        expect(
          (await db
                  .doc('users/$owner/agenda/${offline.id}')
                  .get(const GetOptions(source: Source.server)))
              .exists,
          isFalse,
        );
        await auth.signOut();
        await settle();
        expect(find.text('Kuliah sintetis'), findsNothing);
        await expectLater(
          db
              .collection('users')
              .doc(owner)
              .collection('agenda')
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        await session.enterTemporarily();
        await settle();
        final other = auth.currentUser!.uid;
        expect(other == owner, isFalse);
        await expectLater(
          db
              .collection('users')
              .doc(owner)
              .collection('agenda')
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        await expectLater(repository.read(), throwsA(isA<AgendaFailure>()));
        await tap(find.byKey(const ValueKey('tab-1')));
        expect(find.text('Harimu masih lapang'), findsOneWidget);
        expect(find.text('Sesi berikutnya'), findsNothing);
        await shot('05-other-account-empty');
        binding.reportData ??= {};
        binding.reportData!.addAll({
          'project': 'demo-ruma',
          'ownerUid': owner,
          'otherUid': other,
          'manualCreate': true,
          'editKeepsId': true,
          'completeAndReopen': true,
          'deleteCancel': true,
          'softDelete': true,
          'conflictRejected': true,
          'adjacentAllowed': true,
          'idempotentRetry': true,
          'staleVersionRejected': true,
          'offlineDidNotQueue': true,
          'unauthenticatedDenied': true,
          'otherUserDenied': true,
          'oldSessionDiscarded': true,
          'productionWrites': 0,
        });
      } finally {
        await db.enableNetwork();
        await auth.currentUser?.delete();
        await auth.signOut();
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      }
    },
  );
}
