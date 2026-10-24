import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/savings.dart';
import 'package:ruma/data/savings_repository.dart';

SavingsSnapshot savingsFixture({
  int balance = 820000,
  int total = 400000,
  int revision = 1,
}) => SavingsSnapshot(
  goals: const [
    SavingsGoal(
      id: 'emergency',
      version: 2,
      input: SavingsGoalInput(name: 'Dana darurat', targetRupiah: 1000000),
      balanceRupiah: 300000,
    ),
    SavingsGoal(
      id: 'books',
      version: 2,
      input: SavingsGoalInput(
        name: 'Buku semester depan',
        targetRupiah: 100000,
      ),
      balanceRupiah: 100000,
    ),
  ],
  movements: const [
    SavingsMovement(
      id: 'a',
      goalId: 'emergency',
      input: SavingsMovementInput(
        type: 'deposit',
        amountRupiah: 300000,
        localDate: '2026-01-01',
      ),
    ),
    SavingsMovement(
      id: 'b',
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
  revision: revision,
);

class SavingsRepoFake extends Fake implements SavingsRepository {
  Future<SavingsSnapshot> Function()? onRead;
  Future<void> Function(SavingsMutation)? onSave;
  int ids = 0;
  @override
  String newId() => 'savings-${ids++}';
  @override
  Future<SavingsSnapshot> read() async =>
      onRead == null ? savingsFixture() : onRead!();
  @override
  Future<void> save(SavingsMutation m) async => onSave?.call(m);
}
