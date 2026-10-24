import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('explicitly authorized production agenda smoke', (tester) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('AGENDA_LIVE_TESTS')) {
      throw StateError(
        'Requires explicit AGENDA_LIVE_TESTS=true and production',
      );
    }
    final session = await initializeSession();
    final auth = FirebaseAuth.instance;
    final db = initializeAgendaDatabase();
    final report = <String, dynamic>{
      'project': RumaFirebaseOptions.android.projectId,
      'transport': 'Flutter Android SDK on physical USB device',
      'fixtureUids': <String>[],
      'authFixturesDeleted': <String>[],
      'modelCalls': 0,
    };
    binding.reportData = report;
    try {
      await auth.signOut();
      await auth.signInAnonymously();
      final owner = auth.currentUser!.uid;
      (report['fixtureUids'] as List<String>).add(owner);
      final repo = AgendaRepository(db, auth);
      expect((await repo.read()).items, isEmpty);
      final id = repo.newId();
      const input = AgendaInput(title: 'QA sintetis agenda produksi');
      final create = AgendaMutation(
        operationId: repo.newId(),
        id: id,
        input: input,
      );
      final created = await repo.save(create);
      expect(created.items.single.version, 1);
      expect((await repo.read()).items.single.id, id);
      report['createAndRead'] = true;
      expect((await repo.save(create)).revision, created.revision);
      report['idempotentRetry'] = true;
      final completed = await repo.save(
        AgendaMutation(
          operationId: repo.newId(),
          id: id,
          originalVersion: 1,
          input: input.withStatus('completed'),
        ),
      );
      expect(completed.items.single.input.status, 'completed');
      report['update'] = true;
      final deleted = await repo.save(
        AgendaMutation(
          operationId: repo.newId(),
          id: id,
          originalVersion: 2,
          input: input.withStatus('completed'),
          delete: true,
        ),
      );
      expect(deleted.items, isEmpty);
      expect((await repo.read()).items, isEmpty);
      report['softDelete'] = true;
      final ownerPath = db.collection('users').doc(owner).collection('agenda');
      await auth.currentUser!.delete();
      (report['authFixturesDeleted'] as List<String>).add(owner);
      await expectLater(
        ownerPath.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      report['unauthenticatedDenied'] = true;
      await auth.signInAnonymously();
      final other = auth.currentUser!.uid;
      (report['fixtureUids'] as List<String>).add(other);
      await expectLater(
        ownerPath.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      report['otherUserDenied'] = true;
      expect((await AgendaRepository(db, auth).read()).items, isEmpty);
      await auth.currentUser!.delete();
      (report['authFixturesDeleted'] as List<String>).add(other);
      report['passed'] = true;
    } finally {
      if (auth.currentUser != null) {
        final uid = auth.currentUser!.uid;
        await auth.currentUser!.delete();
        (report['authFixturesDeleted'] as List<String>).add(uid);
      }
      session.dispose();
      binding.reportData = report;
    }
  });
}
