import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'finance.dart';

class FinanceRepository {
  FinanceRepository(this.db, this.auth) : uid = auth.currentUser!.uid;
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String uid;
  DocumentReference<Map<String, dynamic>> get _user =>
      db.collection('users').doc(uid);
  void _check() {
    if (auth.currentUser?.uid != uid) {
      throw const FinanceFailure(
        'Sesi akun berubah. Buka kembali keuangan dari akunmu.',
      );
    }
  }

  String newId() => _user.collection('transactions').doc().id;
  static const _server = GetOptions(source: Source.server);
  Future<FinanceSnapshot> read(String month) async {
    _check();
    if (!validMonth(month)) throw const FinanceFailure('Periode tidak valid.');
    final cr = _user.collection('state').doc('core');
    final before = await cr.get(_server).timeout(const Duration(seconds: 15));
    final summary = await _user
        .collection('months')
        .doc(month)
        .get(_server)
        .timeout(const Duration(seconds: 15));
    // ponytail: all pages of the selected month, capped at 1000 including tombstones.
    // Add server reporting/range partitioning before raising this coursework ceiling.
    final items = <MoneyTransaction>[];
    DocumentSnapshot? cursor;
    var count = 0;
    while (true) {
      Query<Map<String, dynamic>> q = _user
          .collection('transactions')
          .where('monthKey', isEqualTo: month)
          .limit(100);
      if (cursor != null) q = q.startAfterDocument(cursor);
      final page = await q.get(_server).timeout(const Duration(seconds: 15));
      _check();
      count += page.size;
      if (count > 1000) {
        throw const FinanceFailure(
          'Catatan bulan ini melebihi batas tahap ini. Ringkasan tidak ditampilkan sebagian.',
        );
      }
      items.addAll(
        page.docs
            .where((d) => d.data()['deletedAt'] == null)
            .map(
              (d) => MoneyTransaction(
                id: d.id,
                version: d.data()['version'] as int,
                input: _input(d.data()),
              ),
            ),
      );
      if (page.size < 100) break;
      cursor = page.docs.last;
    }
    final after = await cr.get(_server).timeout(const Duration(seconds: 15));
    _check();
    final revision = (after.data()?['financeRevision'] as int?) ?? 0;
    if (revision != ((before.data()?['financeRevision'] as int?) ?? 0)) {
      throw const FinanceFailure(
        'Keuangan berubah. Muat ulang untuk melihat angka terbaru.',
      );
    }
    final m = _month(month, summary.data());
    if (items.fold<int>(0, (a, b) => a + b.input.income) != m.income ||
        items.fold<int>(0, (a, b) => a + b.input.expense) != m.expense ||
        expenseCategories.keys.any(
          (k) =>
              items
                  .where(
                    (a) => a.input.type == 'expense' && a.input.categoryId == k,
                  )
                  .fold<int>(0, (a, b) => a + b.input.amountRupiah) !=
              (m.categoryExpense[k] ?? 0),
        )) {
      throw const FinanceFailure(
        'Ringkasan belum cocok dengan catatan. Muat ulang; tidak ada angka perkiraan yang ditampilkan.',
      );
    }
    items.sort((a, b) {
      final d = b.input.localDate.compareTo(a.input.localDate);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
    return FinanceSnapshot(
      month: m,
      items: items,
      balance: (after.data()?['balanceRupiah'] as int?) ?? 0,
      revision: revision,
    );
  }

  Future<void> save(FinanceMutation m) async {
    _check();
    if (m.restore &&
        (m.delete || m.originalVersion == null || m.budget != null)) {
      throw const FinanceFailure('Permintaan pemulihan tidak valid.');
    }
    final error = m.budget?.validate() ?? m.input?.validate();
    if (error != null) throw FinanceFailure(error);
    if ((m.budget == null) == (m.input == null) ||
        (m.budget != null && (m.delete || m.id != m.budget!.monthKey))) {
      throw const FinanceFailure('Permintaan keuangan tidak valid.');
    }
    final coreRef = _user.collection('state').doc('core');
    // Native SDK disableNetwork does not gate transaction RPCs consistently.
    // Require a fresh server read before entering any write callback.
    await coreRef.get(_server).timeout(const Duration(seconds: 15));
    _check();
    final opRef = _user.collection('operations').doc(m.operationId);
    final target = _user
        .collection(m.budget != null ? 'months' : 'transactions')
        .doc(m.id);
    await db.runTransaction(
      (tx) async {
        _check();
        final op = await tx.get(opRef);
        if (op.exists) {
          if (op.data()?['result']?['requestKey'] != m.requestKey) {
            throw const FinanceFailure(
              'Permintaan sudah diproses dengan isian berbeda. Muat ulang sebelum melanjutkan.',
            );
          }
          return;
        }
        final core = await tx.get(coreRef);
        final prior = await tx.get(target);
        final old = prior.data();
        if (m.originalVersion == null
            ? prior.exists
            : (!prior.exists ||
                  old?['version'] != m.originalVersion ||
                  ((old?['deletedAt'] != null) != m.restore))) {
          throw const FinanceFailure(
            'Catatan atau anggaran sudah berubah. Buka ulang sebelum menyimpan; isianmu tetap ada.',
          );
        }
        final oldInput =
            m.budget == null && old != null && old['deletedAt'] == null
            ? _input(old)
            : null;
        final keys =
            m.budget != null
                  ? [m.id]
                  : <String>{
                      if (oldInput != null) oldInput.monthKey,
                      m.input!.monthKey,
                    }.toList()
              ..sort();
        final months = <String, Map<String, dynamic>?>{};
        for (final key in keys) {
          months[key] = m.budget != null
              ? old
              : (await tx.get(_user.collection('months').doc(key))).data();
        }
        final now = FieldValue.serverTimestamp();
        final version = (old?['version'] as int? ?? 0) + 1;
        int delta(bool income) =>
            (m.budget != null || m.delete
                ? 0
                : income
                ? m.input!.income
                : m.input!.expense) -
            (oldInput == null
                ? 0
                : income
                ? oldInput.income
                : oldInput.expense);
        final di = delta(true), de = delta(false);
        if (m.budget == null) {
          tx.set(
            target,
            m.delete
                ? {
                    ...old!,
                    'version': version,
                    'updatedAt': now,
                    'deletedAt': now,
                    'operationId': m.operationId,
                  }
                : {
                    'schemaVersion': 1,
                    'version': version,
                    'createdAt': old?['createdAt'] ?? now,
                    'updatedAt': now,
                    'deletedAt': null,
                    'operationId': m.operationId,
                    ...m.input!.toJson(),
                    'monthKey': m.input!.monthKey,
                    'source': old?['source'] ?? 'manual',
                  },
          );
        }
        for (final key in keys) {
          final data = months[key];
          final previous = _month(key, data);
          int contribution(
            TransactionInput? input,
            bool income,
            String? category,
          ) =>
              input == null ||
                  input.monthKey != key ||
                  (category != null && input.categoryId != category)
              ? 0
              : income
              ? input.income
              : input.expense;
          final next = m.delete ? null : m.input;
          final categories = {
            for (final k in expenseCategories.keys)
              k:
                  (previous.categoryExpense[k] ?? 0) +
                  contribution(next, false, k) -
                  contribution(oldInput, false, k),
          };
          tx.set(_user.collection('months').doc(key), {
            'schemaVersion': 1,
            'version': previous.version + 1,
            'createdAt': data?['createdAt'] ?? now,
            'updatedAt': now,
            'incomeRupiah':
                previous.income +
                contribution(next, true, null) -
                contribution(oldInput, true, null),
            'expenseRupiah':
                previous.expense +
                contribution(next, false, null) -
                contribution(oldInput, false, null),
            'categoryExpenseRupiah': categories,
            'budgetTotalRupiah':
                m.budget?.total ?? (m.budget != null ? null : previous.budget),
            'categoryBudgetRupiah':
                m.budget?.categories ??
                {
                  for (final k in expenseCategories.keys)
                    k: previous.categoryBudget[k],
                },
            'operationId': m.operationId,
          });
        }
        final c = core.data();
        tx.set(coreRef, {
          'schemaVersion': 1,
          'version': (c?['version'] as int? ?? 0) + 1,
          'createdAt': c?['createdAt'] ?? now,
          'updatedAt': now,
          'agendaRevision': c?['agendaRevision'] ?? 0,
          'financeRevision': (c?['financeRevision'] as int? ?? 0) + 1,
          'balanceRupiah': (c?['balanceRupiah'] as int? ?? 0) + di - de,
          'lifetimeIncomeRupiah':
              (c?['lifetimeIncomeRupiah'] as int? ?? 0) + di,
          'lifetimeExpenseRupiah':
              (c?['lifetimeExpenseRupiah'] as int? ?? 0) + de,
          'lastUndoOperationId': m.operationId,
        });
        tx.set(opRef, {
          'schemaVersion': 1,
          'version': 1,
          'createdAt': now,
          'updatedAt': now,
          'draftId': 'manual',
          'approvedRevision': 1,
          'kind': m.kind,
          'targets': [
            '${m.budget != null ? 'months' : 'transactions'}/${m.id}',
          ],
          'result': {
            'entityId': m.id,
            'version': version,
            'requestKey': m.requestKey,
            'monthKeys': keys,
          },
          'undoState': 'unavailable',
        });
      },
      timeout: const Duration(seconds: 15),
      maxAttempts: 3,
    );
    _check();
  }
}

TransactionInput _input(Map<String, dynamic> d) => TransactionInput(
  type: d['type'] as String,
  amountRupiah: d['amountRupiah'] as int,
  categoryId: d['categoryId'] as String,
  localDate: d['localDate'] as String,
  description: d['description'] as String,
);
MonthFinance _month(String key, Map<String, dynamic>? d) => MonthFinance(
  key: key,
  version: d?['version'] as int? ?? 0,
  income: d?['incomeRupiah'] as int? ?? 0,
  expense: d?['expenseRupiah'] as int? ?? 0,
  categoryExpense: Map<String, int>.from(d?['categoryExpenseRupiah'] ?? {}),
  budget: d?['budgetTotalRupiah'] as int?,
  categoryBudget: Map<String, int?>.from(d?['categoryBudgetRupiah'] ?? {}),
);

class FinanceStore extends ChangeNotifier {
  FinanceStore(this.repository) : month = financeToday().substring(0, 7);
  final FinanceRepository repository;
  String month;
  FinanceSnapshot? snapshot;
  bool loading = false, saving = false, _disposed = false;
  String? error;
  int _generation = 0;
  Future<void> load([String? selected]) async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    if (selected != null && selected != month) {
      month = selected;
      snapshot = null;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.read(month);
      if (!_disposed && generation == _generation) snapshot = result;
    } catch (e) {
      if (!_disposed && generation == _generation) error = financeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(FinanceMutation m) async {
    if (_disposed || saving) return false;
    final generation = ++_generation;
    saving = true;
    loading = false;
    error = null;
    notifyListeners();
    try {
      await repository.save(m);
      if (_disposed || generation != _generation) return false;
      // Follow a confirmed transaction to its actual period. Failed writes keep
      // the previous selection; stale totals must not survive a failed refresh.
      if (m.input != null && !m.delete) {
        month = m.input!.localDate.substring(0, 7);
      }
      snapshot = null;
      // The write is confirmed even if the subsequent refresh fails. Retry IDs
      // remain valid, and the UI must not describe a failed refresh as lost data.
      try {
        final refreshed = await repository.read(month);
        if (!_disposed && generation == _generation) snapshot = refreshed;
      } catch (e) {
        if (!_disposed) error = 'Tersimpan. Ringkasan belum termuat; muat ulang untuk melihat angka terbaru.';
      }
      return !_disposed && generation == _generation;
    } catch (e) {
      if (!_disposed && generation == _generation) error = financeError(e);
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        saving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    snapshot = null;
    super.dispose();
  }
}

String financeError(Object e) {
  if (e is FinanceFailure) return e.message;
  if (e is TimeoutException) {
    return 'Penyimpanan belum terkonfirmasi. Periksa internet lalu coba lagi; isianmu tetap ada.';
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'Server menolak perubahan keuangan. Muat ulang atau coba lagi; isianmu tetap ada.';
  }
  return 'Belum terhubung ke data keuangan. Muat ulang atau coba simpan lagi saat online.';
}
