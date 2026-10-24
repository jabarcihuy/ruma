import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/savings.dart';
import 'package:ruma/data/savings_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('savings repository uses atomic native Firestore transactions', (
    tester,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) {
      throw StateError('Local demo-ruma only');
    }
    await initializeSession();
    final db = initializeAgendaDatabase(), auth = FirebaseAuth.instance;
    await auth.signOut();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final email = 'savings-$stamp@ruma.test';
    final password = 'Synthetic-$stamp-Aa!';
    final cases = <String>[];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Local savings verification')),
      ),
    );
    try {
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = auth.currentUser!.uid;
      final finance = FinanceRepository(db, auth),
          savings = SavingsRepository(db, auth);
      expect((await savings.read()).totalSavedRupiah, 0);
      await savings.save(
        const SavingsMutation.goal(
          operationId: 'new-empty',
          goalId: 'empty',
          input: SavingsGoalInput(name: 'Tujuan kosong', targetRupiah: 100000),
        ),
      );
      expect((await savings.read()).goals.single.balanceRupiah, 0);
      cases.add('goal initializes an empty core without adding money');
      for (final input in [
        const TransactionInput(
          type: 'income',
          amountRupiah: 2000000,
          categoryId: 'allowance',
          localDate: '2026-01-01',
        ),
        const TransactionInput(
          type: 'expense',
          amountRupiah: 1180000,
          categoryId: 'food',
          localDate: '2026-01-01',
        ),
      ]) {
        await finance.save(
          FinanceMutation(
            operationId: finance.newId(),
            id: finance.newId(),
            input: input,
          ),
        );
      }
      await finance.save(
        FinanceMutation(
          operationId: finance.newId(),
          id: '2026-01',
          budget: BudgetInput(monthKey: '2026-01', total: 1500000),
          originalVersion: 2,
        ),
      );
      final before = await finance.read('2026-01');
      for (final goal in [
        const SavingsMutation.goal(
          operationId: 'create-emergency',
          goalId: 'emergency',
          input: SavingsGoalInput(
            name: 'Dana darurat',
            targetRupiah: 1000000,
            targetDate: '2026-12-31',
          ),
        ),
        const SavingsMutation.goal(
          operationId: 'create-books',
          goalId: 'books',
          input: SavingsGoalInput(name: 'Buku', targetRupiah: 100000),
        ),
      ]) {
        await savings.save(goal);
      }
      SavingsMutation move(
        String id,
        String goal,
        String type,
        int amount,
        int version,
      ) => SavingsMutation.transfer(
        operationId: id,
        goalId: goal,
        expectedVersion: version,
        input: SavingsMovementInput(
          type: type,
          amountRupiah: amount,
          localDate: '2026-01-02',
        ),
      );
      final deposit = move(
        'deposit-emergency',
        'emergency',
        'deposit',
        300000,
        1,
      );
      await savings.save(deposit);
      await savings.save(deposit);
      await savings.save(move('deposit-books', 'books', 'deposit', 100000, 1));
      var s = await savings.read();
      expect(s.totalSavedRupiah, 400000);
      expect(s.availableRupiah, 420000);
      expect(s.movements.length, 2);
      expect(s.goals.singleWhere((g) => g.id == 'books').complete, isTrue);
      cases.add(
        'deposit, multiple goals, reconciliation, 100 percent and idempotent retry',
      );
      await expectLater(
        savings.save(move('deposit-emergency', 'emergency', 'deposit', 1, 1)),
        throwsA(isA<FinanceFailure>()),
      );
      await expectLater(
        savings.save(move('over-deposit', 'emergency', 'deposit', 420001, 2)),
        throwsA(isA<FinanceFailure>()),
      );
      await expectLater(
        savings.save(
          move('over-withdraw', 'emergency', 'withdrawal', 300001, 2),
        ),
        throwsA(isA<FinanceFailure>()),
      );
      await expectLater(
        savings.save(move('stale', 'emergency', 'deposit', 1, 1)),
        throwsA(isA<FinanceFailure>()),
      );
      expect((await savings.read()).movements.length, 2);
      cases.add(
        'overdraft, over-withdrawal, stale version, request collision rollback',
      );
      await savings.save(
        const SavingsMutation.goal(
          operationId: 'edit-emergency',
          goalId: 'emergency',
          originalVersion: 2,
          input: SavingsGoalInput(name: 'Cadangan kos', targetRupiah: 2000000),
        ),
      );
      await savings.save(move('withdraw', 'emergency', 'withdrawal', 50000, 3));
      s = await savings.read();
      expect(s.totalSavedRupiah, 350000);
      expect(s.availableRupiah, 470000);
      expect(
        s.goals.singleWhere((g) => g.id == 'emergency').input.name,
        'Cadangan kos',
      );
      final after = await finance.read('2026-01');
      expect(after.balance, before.balance);
      expect(after.month.income, before.month.income);
      expect(after.month.expense, before.month.expense);
      expect(after.month.budget, before.month.budget);
      expect(after.items.length, before.items.length);
      cases.add(
        'goal edit and withdrawal preserve ledger, reports, budget and recorded balance',
      );
      await db.disableNetwork();
      try {
        await expectLater(
          savings.save(move('offline', 'emergency', 'deposit', 1, 4)),
          throwsA(anything),
        );
      } finally {
        await db.enableNetwork();
      }
      expect(
        (await db
                .collection('users')
                .doc(uid)
                .collection('operations')
                .doc('offline')
                .get(const GetOptions(source: Source.server)))
            .exists,
        isFalse,
      );
      cases.add('offline write rejected without queued mutation');
      await auth.signOut();
      await auth.signInAnonymously();
      await expectLater(savings.read(), throwsA(isA<FinanceFailure>()));
      await expectLater(
        savings.save(move('old-session', 'emergency', 'deposit', 1, 4)),
        throwsA(isA<FinanceFailure>()),
      );
      await expectLater(
        db.collection('users').doc(uid).collection('savingsGoals').get(),
        throwsA(isA<FirebaseException>()),
      );
      expect((await SavingsRepository(db, auth).read()).goals, isEmpty);
      await auth.currentUser!.delete();
      await expectLater(
        db.collection('users').doc(uid).collection('savingsMovements').get(),
        throwsA(isA<FirebaseException>()),
      );
      await auth.signInWithEmailAndPassword(email: email, password: password);
      cases.add(
        'UID lifecycle, cross-account queries and signed-out isolation',
      );
      binding.reportData = {
        'projectId': 'demo-ruma',
        'productionWrites': 0,
        'passed': cases.length,
        'cases': cases,
      };
    } finally {
      await db.enableNetwork();
      if (auth.currentUser?.email != email) {
        if (auth.currentUser != null) await auth.currentUser!.delete();
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      await auth.currentUser!.delete();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
