import 'package:flutter/foundation.dart';

import 'finance_repository.dart';
import 'savings.dart';
import 'savings_repository.dart';

class SavingsStore extends ChangeNotifier {
  SavingsStore(this.repository, {this.onCommitted});
  final SavingsRepository repository;
  final Future<void> Function()? onCommitted;
  SavingsSnapshot? snapshot;
  bool loading = false, saving = false, _disposed = false;
  String? error;
  int _generation = 0;

  void invalidate() {
    if (_disposed || saving) return;
    _generation++;
    snapshot = null;
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || saving) return;
    final generation = ++_generation;
    snapshot = null;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await repository.read();
      if (!_disposed && generation == _generation) snapshot = data;
    } catch (e) {
      if (!_disposed && generation == _generation) error = financeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(SavingsMutation mutation) async {
    if (_disposed || saving) return false;
    final generation = ++_generation;
    saving = true;
    loading = false;
    error = null;
    notifyListeners();
    try {
      await repository.save(mutation);
      if (_disposed || generation != _generation) return false;
      snapshot = null;
      // A confirmed write stays successful even when refreshing later fails.
      try {
        await onCommitted?.call();
        final data = await repository.read();
        if (!_disposed && generation == _generation) snapshot = data;
      } catch (_) {
        if (!_disposed) {
          error = 'Tersimpan. Muat ulang untuk melihat tabungan terbaru.';
        }
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
