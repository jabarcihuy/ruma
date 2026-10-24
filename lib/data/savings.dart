import 'dart:convert';

import 'finance.dart';

bool validSavingsId(String value) =>
    RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(value);

class SavingsGoalInput {
  const SavingsGoalInput({
    required this.name,
    required this.targetRupiah,
    this.targetDate,
    this.iconId,
  });
  final String name;
  final int targetRupiah;
  final String? targetDate;
  // Absent on legacy goals; null keeps the general savings icon.
  final String? iconId;
  static const iconLabels = {
    'wallet': 'Umum',
    'headphones': 'Gadget',
    'book-open': 'Pendidikan',
    'plane': 'Liburan',
    'shield-check': 'Dana darurat',
  };
  String get icon => iconId ?? 'wallet';

  String? validate() {
    if (iconId != null && !iconLabels.containsKey(iconId)) {
      return 'Pilih ikon tujuan yang tersedia.';
    }
    if (name.trim().isEmpty || name.length > 80) {
      return 'Nama tujuan wajib diisi, maksimal 80 karakter.';
    }
    if (targetRupiah < 1 || targetRupiah > 1000000000) {
      return 'Target tabungan Rp1 sampai Rp1.000.000.000.';
    }
    // An existing goal may be overdue; changing its name must still be possible.
    if (targetDate != null && !validDate(targetDate!)) {
      return 'Tanggal target tidak valid.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'targetRupiah': targetRupiah,
    'targetDate': targetDate,
    if (iconId != null) 'iconId': iconId,
  };
}

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.version,
    required this.input,
    required this.balanceRupiah,
  });
  final String id;
  final int version, balanceRupiah;
  final SavingsGoalInput input;
  bool get complete => balanceRupiah >= input.targetRupiah;
  int get remainingRupiah =>
      (input.targetRupiah - balanceRupiah).clamp(0, input.targetRupiah);
  double get progress => (balanceRupiah / input.targetRupiah).clamp(0, 1);
}

class SavingsMovementInput {
  const SavingsMovementInput({
    required this.type,
    required this.amountRupiah,
    required this.localDate,
    this.description = '',
  });
  final String type, localDate, description;
  final int amountRupiah;
  int get delta => type == 'deposit' ? amountRupiah : -amountRupiah;

  String? validate({String? today}) {
    if (!['deposit', 'withdrawal'].contains(type)) {
      return 'Pilih setoran atau penarikan.';
    }
    if (amountRupiah < 1 || amountRupiah > 1000000000) {
      return 'Nominal Rp1 sampai Rp1.000.000.000.';
    }
    if (!validDate(localDate) ||
        localDate.compareTo(today ?? financeToday()) > 0) {
      return 'Pilih tanggal yang valid, paling lambat hari ini (WIB).';
    }
    if (description.length > 1000) return 'Catatan maksimal 1.000 karakter.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'amountRupiah': amountRupiah,
    'localDate': localDate,
    'description': description,
  };
}

class SavingsMovement {
  const SavingsMovement({
    required this.id,
    required this.goalId,
    required this.input,
  });
  final String id, goalId;
  final SavingsMovementInput input;
}

class SavingsMutation {
  const SavingsMutation.goal({
    required this.operationId,
    required this.goalId,
    required SavingsGoalInput input,
    this.originalVersion,
  }) : goal = input,
       movement = null;
  const SavingsMutation.transfer({
    required this.operationId,
    required this.goalId,
    required SavingsMovementInput input,
    required int expectedVersion,
  }) : movement = input,
       goal = null,
       originalVersion = expectedVersion;

  final String operationId, goalId;
  final int? originalVersion;
  final SavingsGoalInput? goal;
  final SavingsMovementInput? movement;
  String get kind => movement != null
      ? (movement!.type == 'deposit' ? 'savings_deposit' : 'savings_withdrawal')
      : originalVersion == null
      ? 'savings_goal_create'
      : 'savings_goal_update';
  String? validate() {
    if (!validSavingsId(operationId) || !validSavingsId(goalId)) {
      return 'Identitas tabungan tidak valid.';
    }
    if (originalVersion != null && originalVersion! < 1) {
      return 'Versi tujuan tidak valid.';
    }
    return goal?.validate() ?? movement?.validate();
  }

  String get requestKey => jsonEncode({
    'goalId': goalId,
    'version': originalVersion,
    'goal': goal?.toJson(),
    'movement': movement?.toJson(),
  });

  /// Only allocation changes. Income, expenses and recorded balance stay intact.
  int balanceAfter({
    required int goalBalance,
    required int totalSaved,
    required int recordedBalance,
  }) {
    final error = validate();
    if (error != null) throw FinanceFailure(error);
    final m = movement;
    if (m == null) return goalBalance;
    if (m.type == 'deposit' && m.amountRupiah > recordedBalance - totalSaved) {
      throw const FinanceFailure(
        'Uang tersedia belum cukup untuk setoran ini.',
      );
    }
    if (m.type == 'withdrawal' && m.amountRupiah > goalBalance) {
      throw const FinanceFailure('Penarikan melebihi tabungan tujuan ini.');
    }
    return goalBalance + m.delta;
  }
}

class SavingsSnapshot {
  SavingsSnapshot({
    required List<SavingsGoal> goals,
    required List<SavingsMovement> movements,
    required this.recordedBalance,
    required this.totalSavedRupiah,
    required this.revision,
  }) : goals = List.unmodifiable(goals),
       movements = List.unmodifiable(movements);
  final List<SavingsGoal> goals;
  final List<SavingsMovement> movements;
  final int recordedBalance, totalSavedRupiah, revision;
  // May be negative after an expense correction; do not hide that shortfall.
  int get availableRupiah => recordedBalance - totalSavedRupiah;

  void verify() {
    final balances = <String, int>{};
    for (final m in movements) {
      balances.update(
        m.goalId,
        (balance) => balance + m.input.delta,
        ifAbsent: () => m.input.delta,
      );
    }
    final ids = goals.map((g) => g.id).toSet();
    if (ids.length != goals.length ||
        movements.map((m) => m.id).toSet().length != movements.length ||
        totalSavedRupiah < 0 ||
        goals.any(
          (g) =>
              g.balanceRupiah < 0 || (balances[g.id] ?? 0) != g.balanceRupiah,
        ) ||
        balances.keys.any((id) => !ids.contains(id)) ||
        goals.fold<int>(0, (sum, g) => sum + g.balanceRupiah) !=
            totalSavedRupiah) {
      throw const FinanceFailure(
        'Ringkasan tabungan belum cocok dengan riwayat. Muat ulang.',
      );
    }
  }
}
