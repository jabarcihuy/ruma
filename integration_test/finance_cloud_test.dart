import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('explicitly authorized production finance smoke', (tester) async {
    if (RumaFirebaseOptions.useEmulator ||
        !const bool.fromEnvironment('FINANCE_LIVE_TESTS')) {
      throw StateError(
        'Requires explicit FINANCE_LIVE_TESTS=true and production',
      );
    }
    final session = await initializeSession();
    final auth = FirebaseAuth.instance;
    final db = initializeAgendaDatabase();
    final report = <String, dynamic>{
      'project': RumaFirebaseOptions.android.projectId,
      'transport': 'Flutter Android SDK on physical USB device',
      'suite': 'finance_cloud_test',
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
      // UID-only recovery marker: never prints credentials or real user content.
      // ignore: avoid_print
      print('RUMA_FINANCE_SYNTHETIC_UID=$owner');
      final repo = FinanceRepository(db, auth);
      final today = financeToday();
      final current = today.substring(0, 7);
      final day = DateTime.parse(today);
      final prior = dateKey(DateTime(day.year, day.month, 0));
      expect((await repo.read(current)).items, isEmpty);
      final income = FinanceMutation(
        operationId: repo.newId(),
        id: repo.newId(),
        input: TransactionInput(
          type: 'income',
          amountRupiah: 100000,
          categoryId: 'allowance',
          localDate: today,
          description: 'QA sintetis produksi',
        ),
      );
      final expense = FinanceMutation(
        operationId: repo.newId(),
        id: repo.newId(),
        input: TransactionInput(
          type: 'expense',
          amountRupiah: 18000,
          categoryId: 'food',
          localDate: today,
          description: 'QA sintetis produksi',
        ),
      );
      await repo.save(income);
      await repo.save(expense);
      var data = await repo.read(current);
      expect(data.balance, 82000);
      expect(data.month.expense, 18000);
      report['createReadTotals'] = true;
      final revision = data.revision;
      await repo.save(expense);
      expect((await repo.read(current)).revision, revision);
      report['retryWithoutDuplicate'] = true;
      await repo.save(
        FinanceMutation(
          operationId: repo.newId(),
          id: current,
          originalVersion: data.month.version,
          budget: BudgetInput(
            monthKey: current,
            total: 50000,
            categories: {'food': 30000},
          ),
        ),
      );
      data = await repo.read(current);
      expect(data.month.budget, 50000);
      expect(data.balance, 82000);
      report['budgetNeverChangesBalance'] = true;
      final edited = TransactionInput(
        type: 'expense',
        amountRupiah: 22000,
        categoryId: 'transport',
        localDate: prior,
        description: 'QA pindah periode',
      );
      await repo.save(
        FinanceMutation(
          operationId: repo.newId(),
          id: expense.id,
          originalVersion: 1,
          input: edited,
        ),
      );
      data = await repo.read(current);
      expect(data.month.expense, 0);
      expect(data.balance, 78000);
      expect(
        (await repo.read(prior.substring(0, 7)))
            .month
            .categoryExpense['transport'],
        22000,
      );
      report['crossMonthEdit'] = true;
      await repo.save(
        FinanceMutation(
          operationId: repo.newId(),
          id: expense.id,
          originalVersion: 2,
          input: edited,
          delete: true,
        ),
      );
      expect((await repo.read(current)).balance, 100000);
      expect((await repo.read(prior.substring(0, 7))).month.expense, 0);
      report['softDeleteReversesTotals'] = true;
      final path = db.collection('users').doc(owner).collection('transactions');
      await auth.currentUser!.delete();
      (report['authFixturesDeleted'] as List<String>).add(owner);
      await expectLater(
        path.get(const GetOptions(source: Source.server)),
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
        path.get(const GetOptions(source: Source.server)),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect((await FinanceRepository(db, auth).read(current)).items, isEmpty);
      report['otherUserDenied'] = true;
      await auth.currentUser!.delete();
      (report['authFixturesDeleted'] as List<String>).add(other);
      report['passed'] = true;
    } finally {
      if (auth.currentUser != null) {
        final uid = auth.currentUser!.uid;
        if ((report['fixtureUids'] as List<String>).contains(uid)) {
          await auth.currentUser!.delete();
          (report['authFixturesDeleted'] as List<String>).add(uid);
        } else {
          await auth.signOut();
        }
      }
      session.dispose();
      binding.reportData = report;
    }
  });
}
