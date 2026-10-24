import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/savings.dart';

const goalInput = SavingsGoalInput(name: 'Dana darurat', targetRupiah: 1000000);
SavingsMutation transfer({String type = 'deposit', int amount = 100000}) =>
    SavingsMutation.transfer(
      operationId: 'operation-1',
      goalId: 'goal-1',
      expectedVersion: 2,
      input: SavingsMovementInput(
        type: type,
        amountRupiah: amount,
        localDate: '2026-01-01',
      ),
    );
SavingsSnapshot example({
  int balance = 820000,
  int total = 400000,
  int emergency = 300000,
  List<SavingsMovement>? movements,
}) => SavingsSnapshot(
  goals: [
    SavingsGoal(
      id: 'goal-1',
      version: 2,
      input: goalInput,
      balanceRupiah: emergency,
    ),
    const SavingsGoal(
      id: 'books',
      version: 2,
      input: SavingsGoalInput(name: 'Buku', targetRupiah: 100000),
      balanceRupiah: 100000,
    ),
  ],
  movements:
      movements ??
      [
        const SavingsMovement(
          id: 'deposit-1',
          goalId: 'goal-1',
          input: SavingsMovementInput(
            type: 'deposit',
            amountRupiah: 350000,
            localDate: '2026-01-01',
          ),
        ),
        const SavingsMovement(
          id: 'withdraw-1',
          goalId: 'goal-1',
          input: SavingsMovementInput(
            type: 'withdrawal',
            amountRupiah: 50000,
            localDate: '2026-01-02',
          ),
        ),
        const SavingsMovement(
          id: 'deposit-2',
          goalId: 'books',
          input: SavingsMovementInput(
            type: 'deposit',
            amountRupiah: 100000,
            localDate: '2026-01-01',
          ),
        ),
      ],
  recordedBalance: balance,
  totalSavedRupiah: total,
  revision: 3,
);
void main() {
  test('wishlist icons are optional, validated and part of retry identity', () {
    expect(goalInput.toJson().containsKey('iconId'), false);
    expect(goalInput.icon, 'wallet');
    for (final icon in SavingsGoalInput.iconLabels.keys) {
      final input = SavingsGoalInput(
        name: 'Wishlist',
        targetRupiah: 800000,
        iconId: icon,
      );
      expect(input.validate(), isNull);
      expect(input.toJson()['iconId'], icon);
    }
    expect(
      const SavingsGoalInput(
        name: 'Wishlist',
        targetRupiah: 1,
        iconId: 'unknown',
      ).validate(),
      isNotNull,
    );
    SavingsMutation mutation(String icon) => SavingsMutation.goal(
      operationId: 'op',
      goalId: 'g',
      input: SavingsGoalInput(
        name: 'Wishlist',
        targetRupiah: 800000,
        iconId: icon,
      ),
    );
    expect(
      mutation('headphones').requestKey,
      isNot(mutation('plane').requestKey),
    );
  });
  test('goal names, targets and optional real dates are validated', () {
    expect(goalInput.validate(), isNull);
    expect(
      const SavingsGoalInput(
        name: ' Dana ',
        targetRupiah: 1,
        targetDate: '2024-02-29',
      ).toJson()['name'],
      'Dana',
    );
    for (final input in [
      const SavingsGoalInput(name: ' \t\n', targetRupiah: 1),
      SavingsGoalInput(name: 'a' * 81, targetRupiah: 1),
      const SavingsGoalInput(name: 'Dana', targetRupiah: 0),
      const SavingsGoalInput(name: 'Dana', targetRupiah: 1000000001),
      const SavingsGoalInput(
        name: 'Dana',
        targetRupiah: 1,
        targetDate: '2026-02-29',
      ),
      const SavingsGoalInput(
        name: 'Dana',
        targetRupiah: 1,
        targetDate: '2101-01-01',
      ),
    ]) {
      expect(input.validate(), isNotNull);
    }
  });
  test(
    'movements require positive integer rupiah, known type, past WIB date',
    () {
      for (final input in [
        const SavingsMovementInput(
          type: 'deposit',
          amountRupiah: 0,
          localDate: '2026-01-01',
        ),
        const SavingsMovementInput(
          type: 'withdrawal',
          amountRupiah: -1,
          localDate: '2026-01-01',
        ),
        const SavingsMovementInput(
          type: 'income',
          amountRupiah: 1,
          localDate: '2026-01-01',
        ),
        const SavingsMovementInput(
          type: 'deposit',
          amountRupiah: 1000000001,
          localDate: '2026-01-01',
        ),
        const SavingsMovementInput(
          type: 'deposit',
          amountRupiah: 1,
          localDate: '2026-02-30',
        ),
        const SavingsMovementInput(
          type: 'deposit',
          amountRupiah: 1,
          localDate: '2026-01-03',
        ),
        SavingsMovementInput(
          type: 'deposit',
          amountRupiah: 1,
          localDate: '2026-01-01',
          description: 'a' * 1001,
        ),
      ]) {
        expect(input.validate(today: '2026-01-02'), isNotNull);
      }
    },
  );
  test('IDs and optimistic versions reject malformed mutation requests', () {
    for (final id in ['', 'a/b', 'x' * 81]) {
      expect(
        SavingsMutation.goal(
          operationId: id,
          goalId: 'goal',
          input: goalInput,
        ).validate(),
        isNotNull,
      );
      expect(
        SavingsMutation.goal(
          operationId: 'op',
          goalId: id,
          input: goalInput,
        ).validate(),
        isNotNull,
      );
    }
    expect(
      const SavingsMutation.goal(
        operationId: 'op',
        goalId: 'goal',
        input: goalInput,
        originalVersion: 0,
      ).validate(),
      isNotNull,
    );
  });
  test(
    'deposit allocates available money without changing recorded balance',
    () {
      final s = example();
      s.verify();
      expect(s.availableRupiah, 420000);
      final next = transfer().balanceAfter(
        goalBalance: 300000,
        totalSaved: s.totalSavedRupiah,
        recordedBalance: s.recordedBalance,
      );
      expect(next, 400000);
      final after = example(total: 500000, emergency: next);
      expect(after.recordedBalance, 820000);
      expect(after.availableRupiah, 320000);
    },
  );
  test('withdrawal returns money to available without becoming income', () {
    expect(
      transfer(type: 'withdrawal', amount: 50000).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 820000,
      ),
      250000,
    );
    expect(example(total: 350000, emergency: 250000).availableRupiah, 470000);
  });
  test('deposit and withdrawal cannot overspend their source, exact source allowed', () {
    expect(
      () => transfer(amount: 420001).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 820000,
      ),
      throwsA(isA<FinanceFailure>()),
    );
    expect(
      () => transfer(type: 'withdrawal', amount: 300001).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 820000,
      ),
      throwsA(isA<FinanceFailure>()),
    );
    expect(
      transfer(amount: 420000).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 820000,
      ),
      720000,
    );
    expect(
      transfer(type: 'withdrawal', amount: 300000).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 820000,
      ),
      0,
    );
  });
  test('negative available is visible and blocks new deposits but permits withdrawal', () {
    final s = example(balance: 200000);
    s.verify();
    expect(s.availableRupiah, -200000);
    expect(
      () => transfer(amount: 1).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 200000,
      ),
      throwsA(isA<FinanceFailure>()),
    );
    expect(
      transfer(type: 'withdrawal', amount: 1).balanceAfter(
        goalBalance: 300000,
        totalSaved: 400000,
        recordedBalance: 200000,
      ),
      299999,
    );
  });
  test('target progress caps at 100 while preserving overfunded balance', () {
    for (final balance in [0, 300000, 1000000, 1200000]) {
      final g = SavingsGoal(
        id: 'g',
        version: 1,
        input: goalInput,
        balanceRupiah: balance,
      );
      expect(g.progress, balance >= 1000000 ? 1 : balance / 1000000);
      expect(g.complete, balance >= 1000000);
      expect(g.remainingRupiah, balance >= 1000000 ? 0 : 1000000 - balance);
      expect(g.balanceRupiah, balance);
    }
  });
  test(
    'reconciliation rejects forged totals, missing/duplicate/orphan history',
    () {
      for (final s in [
        example(total: 400001),
        example(emergency: 300001),
        example(movements: []),
        example(movements: [...example().movements, example().movements.first]),
        example(
          movements: [
            ...example().movements,
            const SavingsMovement(
              id: 'orphan',
              goalId: 'unknown',
              input: SavingsMovementInput(
                type: 'deposit',
                amountRupiah: 1,
                localDate: '2026-01-01',
              ),
            ),
          ],
        ),
      ]) {
        expect(s.verify, throwsA(isA<FinanceFailure>()));
      }
      expect(() => example().goals.clear(), throwsUnsupportedError);
    },
  );
  test(
    'goal edits do not reallocate savings and retry keys change with request',
    () {
      const edit = SavingsMutation.goal(
        operationId: 'op',
        goalId: 'g',
        input: SavingsGoalInput(name: 'Laptop', targetRupiah: 2000000),
        originalVersion: 2,
      );
      expect(
        edit.balanceAfter(
          goalBalance: 300000,
          totalSaved: 400000,
          recordedBalance: 820000,
        ),
        300000,
      );
      expect(edit.kind, 'savings_goal_update');
      expect(transfer().requestKey, transfer().requestKey);
      expect(transfer().requestKey, isNot(transfer(amount: 1).requestKey));
      expect(
        transfer().requestKey,
        isNot(transfer(type: 'withdrawal').requestKey),
      );
    },
  );
}
