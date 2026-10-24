import 'dart:async';

import 'user_settings.dart';
import 'recurrence.dart';

import 'package:flutter/foundation.dart';

import 'agenda_repository.dart';
import 'agenda.dart';
import 'finance.dart';
import 'agent_tools.dart';
import 'finance_repository.dart';
import 'assistant_draft.dart';
import 'assistant_service.dart';
import 'draft_repository.dart';
import 'assistant_snapshot.dart';

class AssistantStore extends ChangeNotifier {
  AssistantStore(
    this.repository,
    this.service,
    this.agenda,
    this.finance, {
    this.persistent = false,
    this.settings,
  }) : ready = !persistent;
  final UserSettingsStore? settings;
  final DraftRepository repository;
  final AssistantService service;
  final AgendaStore agenda;
  final FinanceStore finance;
  bool consent = false, busy = false, _disposed = false;
  final bool persistent;
  bool freshWorkspace = false;
  bool ready, storageBlocked = false, loading = false;
  String storageError = '',
      _input = '',
      message = '',
      reply = '',
      error = '',
      messageAt = '';
  List<Map<String, String>> history = [];
  int _storageRevision = 0, _dirty = 0, _saved = 0, _queued = 0;
  Timer? _autosave;
  Future<void> _writes = Future.value();
  String get input => _input;
  set input(String value) {
    if (value == _input) return;
    _input = value;
    _notify();
  }

  bool get storagePending => persistent && (_dirty > _saved || _queued > 0);
  bool get usable => ready && !storageBlocked && !_disposed;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  AssistantSnapshot snapshot() => AssistantSnapshot(
    input: input,
    message: message,
    reply: reply,
    at: messageAt,
    history: history,
    draft: draft,
    record: recordDraft,
    from: availableFrom,
    to: availableTo,
  );
  Future<void> load() async {
    if (!persistent || loading || busy || _disposed) return;
    _autosave?.cancel();
    loading = true;
    ready = false;
    storageError = '';
    _emit();
    try {
      await _writes;
      final (revision, payload) = await repository.readAssistant();
      final state = payload == null
          ? AssistantSnapshot()
          : AssistantSnapshot.decode(payload, repository.uid);
      final d = state.draft, r = state.record;
      if (d != null && (d.attempted || d.applied)) {
        d.applied = await repository.receipt(d);
        d.attempted = true;
      }
      if (r != null && (r.attempted || r.applied)) {
        r.applied = await repository.recordReceipt(r);
        r.attempted = true;
        if (r.applied && (r.undoAttempted || r.undone)) {
          r.undone = await repository.recordReceipt(r, undo: true);
        }
        if (!r.applied) {
          r.undone = false;
          r.undoAttempted = false;
        }
      }
      repository.check();
      if (_disposed) return;
      _storageRevision = revision;
      freshWorkspace = payload == null;
      _input = state.input;
      message = state.message;
      reply = state.reply;
      messageAt = state.at;
      history = state.history;
      draft = d;
      recordDraft = r;
      availableFrom = state.from;
      availableTo = state.to;
      if (payload == null &&
          settings?.ready == true &&
          settings!.value.personalize) {
        availableFrom = settings!.value.from;
        availableTo = settings!.value.to;
      }
      _dirty = 0;
      _saved = 0;
      storageBlocked = false;
      ready = true;
    } catch (e) {
      storageError = e is DraftFailure
          ? e.message
          : 'Riwayat belum tersambung. Coba muat lagi; data tidak ditimpa.';
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<bool> flush() async {
    if (!persistent) return true;
    if (!usable) return false;
    _autosave?.cancel();
    late final String payload;
    try {
      payload = snapshot().encode(repository.uid);
    } catch (e) {
      storageError = e.toString();
      _emit();
      return false;
    }
    final generation = _dirty;
    var success = false;
    _queued++;
    _emit();
    final task = _writes.then((_) async {
      try {
        if (_disposed || storageBlocked) return;
        _storageRevision = await repository.writeAssistant(
          payload,
          _storageRevision,
        );
        _saved = generation;
        storageError = '';
        success = true;
      } catch (e) {
        storageBlocked = e is DraftFailure;
        storageError = e is DraftFailure ? e.message : 'Perubahan Asisten belum tersimpan. Coba simpan lagi sebelum menutup aplikasi.';
      } finally {
        _queued--;
        _emit();
      }
    });
    _writes = task;
    await task;
    return success;
  }

  void _archive() {
    if (message.isNotEmpty) {
      history = [
        ...history,
        {'message': message, 'reply': reply, 'at': messageAt},
      ];
      if (history.length > 10) history = history.sublist(history.length - 10);
    }
    message = '';
    reply = '';
    messageAt = '';
  }

  void preferencesChanged() {
    freshWorkspace = false;
    _notify();
  }

  void applyPersonalDefaults({bool replace = false}) {
    if (!usable ||
        busy ||
        draft != null ||
        recordDraft != null ||
        !replace && !freshWorkspace ||
        settings?.ready != true) {
      return;
    }
    final s = settings!.value;
    if (s.personalize) {
      availableFrom = s.from;
      availableTo = s.to;
      _notify();
    }
  }

  AssistantDraft? draft;
  RecordDraft? recordDraft;
  int availableFrom = 480, availableTo = 1260;
  void _notify() {
    if (persistent && ready && !_disposed) {
      _dirty++;
      _autosave?.cancel();
      if (!storageBlocked) {
        _autosave = Timer(
          const Duration(milliseconds: 500),
          () => unawaited(flush()),
        );
      }
    }
    _emit();
  }

  Future<void> send(String text) async {
    if (!usable ||
        busy ||
        !consent ||
        draft != null && !draft!.applied ||
        recordDraft != null &&
            (!recordDraft!.applied ||
                recordDraft!.undoAttempted && !recordDraft!.undone)) {
      return;
    }
    text = text.trim();
    if (text.isEmpty || text.length > 4000) {
      error = 'Isi pesan antara 1 dan 4.000 karakter.';
      _notify();
      return;
    }
    if (settings?.ready == true &&
        settings!.value.personalize &&
        input.trim().isEmpty) {
      availableFrom = settings!.value.from;
      availableTo = settings!.value.to;
    }
    busy = true;
    error = '';
    _archive();
    message = text;
    messageAt = DateTime.now().toUtc().toIso8601String();
    reply = '';
    draft = null;
    recordDraft = null;
    _notify();
    try {
      if (!await flush()) {
        throw const DraftFailure(
          'Pesan belum tersimpan. Coba lagi setelah koneksi pulih.',
        );
      }
      final response = await service
          .propose(text, repository.newId())
          .timeout(const Duration(seconds: 65));
      if (_disposed) return;
      repository.check();
      if (response['type'] == 'draft_proposal') {
        final items = parseProposal(response['items'], text, repository.newId);
        for (final e in items.where((e) => e.agenda != null)) {
          final a = e.agenda!;
          final duration = preferredDuration(
            settings?.ready == true ? settings!.value : null,
            '${e.quote} $text',
            a.durationMinutes,
          );
          if (duration != a.durationMinutes) {
            e.agenda = AgendaInput(
              title: a.title,
              description: a.description,
              kind: a.kind,
              durationMinutes: duration,
              startAtUtc: a.startAtUtc,
              deadlineAtUtc: a.deadlineAtUtc,
              priority: a.priority,
              status: a.status,
            );
          }
        }
        final snapshot = await agenda.repository.read();
        final reserved = [
          ...{
            for (final e in items.where((e) => e.agenda != null))
              for (final a in snapshot.between(
                DateTime.parse('${e.localDate}T00:00:00Z')
                    .subtract(const Duration(days: 1)),
                DateTime.parse('${e.localDate}T00:00:00Z')
                    .add(const Duration(days: 2)),
              ))
                a.id: a,
          }.values.map((a) => a.input),
          ...items
              .where((e) => e.agenda?.startAtUtc != null)
              .map((e) => e.agenda!),
        ];
        for (final e in items.where((e) => e.agenda != null)) {
          final suggestion = suggestSlot(
            e.agenda!,
            e.localDate,
            reserved,
            now: DateTime.now().toUtc(),
            fromMinute: availableFrom,
            toMinute: availableTo,
          );
          if (suggestion != null) {
            e.agenda = suggestion;
            e.suggestedTime = true;
          }
          reserved.add(e.agenda!);
        }
        final rev = await repository.revisions();
        if (snapshot.revision != rev['agenda']) {
          throw const DraftFailure(
            'Agenda baru berubah. Kirim lagi untuk mencari jam terbaru.',
          );
        }
        if (_disposed) return;
        draft = AssistantDraft(
          id: repository.newId(),
          operationId: repository.newId(),
          uid: repository.uid,
          items: items,
          baseAgendaRevision: rev['agenda']!,
          baseFinanceRevision: rev['finance']!,
        );
      }
      if (response['type'] == 'read_request') {
        reply = await readRecords(
          Map<String, dynamic>.from(response['query'] as Map),
        );
      } else if (response['type'] == 'change_proposal') {
        await prepareChange(
          Map<String, dynamic>.from(response['change'] as Map),
          text,
        );
        reply = response['content'] as String;
      } else {
        reply = response['content'] as String;
      }
    } catch (e) {
      error = e is DraftFailure ? e.message : 'Koneksi Asisten terputus. Tidak ada catatan yang disimpan. Coba kirim lagi bila perlu.';
    } finally {
      if (ready && !_disposed) await flush();
      busy = false;
      _emit();
    }
  }

  Future<String> readRecords(Map<String, dynamic> q) async {
    validateReadQuery(q);
    if (q['kind'] == 'agenda') {
      final s = await agenda.repository.read(),
          day = DateTime.parse('${q['date']}T00:00:00Z');
      return agendaAnswer(
        AgendaSnapshot(
          s.between(
            agendaUtc(day, 0, 0),
            agendaUtc(day.add(const Duration(days: 1)), 0, 0),
          ),
          s.revision,
        ),
        q['date'] as String,
      );
    }
    final snapshot = await finance.repository.read(q['date'] as String);
    repository.check();
    return moneyAnswer(
      snapshot,
      history: q['kind'] == 'history',
      category: q['categoryId'] as String?,
    );
  }

  Future<void> prepareChange(Map<String, dynamic> args, String source) async {
    validateChange(args);
    if (!source.contains(args['sourceQuote'] as String)) {
      throw const DraftFailure('Rujukan perubahan tidak cocok dengan pesan.');
    }
    final isAgenda = args['recordType'] == 'agenda';
    final snapshot = isAgenda ? await agenda.repository.read() : null;
    final day = isAgenda && args['targetDate'] != null
        ? DateTime.parse('${args['targetDate']}T00:00:00Z')
        : null;
    final agendas = snapshot == null
        ? <AgendaItem>[]
        : day == null
        ? snapshot.items
        : snapshot.between(
            agendaUtc(day, 0, 0),
            agendaUtc(day.add(const Duration(days: 1)), 0, 0),
          );
    final transactions = isAgenda
        ? <MoneyTransaction>[]
        : (await finance.repository.read(
            (args['targetDate'] as String).substring(0, 7),
          )).items;
    repository.check();
    if (_disposed) return;
    recordDraft = resolveRecord(
      args,
      agendas,
      transactions,
      repository.newId(),
    );
  }

  void editRecord(AgendaInput? a, TransactionInput? m) {
    final d = recordDraft;
    if (!usable || busy || d == null || d.applied || d.attempted || d.delete) {
      return;
    }
    d.agenda = a;
    d.money = m;
    d.operationId = repository.newId();
    error = '';
    _notify();
  }

  void discardRecord() {
    if (!usable ||
        busy ||
        recordDraft?.attempted == true && recordDraft?.applied != true ||
        recordDraft?.undoAttempted == true && recordDraft?.undone != true) {
      return;
    }
    _archive();
    recordDraft = null;
    reply = '';
    error = '';
    _notify();
  }

  Future<void> saveRecord({bool undo = false}) async {
    final d = recordDraft;
    if (!usable ||
        busy ||
        d == null ||
        (undo ? !d.applied || d.undone : d.applied)) {
      return;
    }
    final invalid = d.validate();
    if (invalid != null) {
      error = invalid;
      _notify();
      return;
    }
    busy = true;
    error = '';
    _notify();
    final wasAttempted = undo ? d.undoAttempted : d.attempted;
    try {
      repository.check();
      final operation = undo
          ? (d.undoOperationId ??= repository.newId())
          : d.operationId;
      if (undo) {
        d.undoAttempted = true;
      } else {
        d.attempted = true;
      }
      if (!await flush()) {
        throw const DraftFailure(
          'Draf belum tersimpan. Belum ada perubahan catatan.',
        );
      }
      if (d.agenda != null) {
        await agenda.repository.save(
          AgendaMutation(
            operationId: operation,
            id: d.id,
            originalVersion: d.version + (undo ? 1 : 0),
            input: undo ? d.beforeAgenda! : d.agenda!,
            delete: !undo && d.delete,
            restore: undo && d.delete,
          ),
        );
      } else {
        await finance.repository.save(
          FinanceMutation(
            operationId: operation,
            id: d.id,
            originalVersion: d.version + (undo ? 1 : 0),
            input: undo ? d.beforeMoney! : d.money!,
            delete: !undo && d.delete,
            restore: undo && d.delete,
          ),
        );
      }
      if (_disposed) return;
      if (undo) {
        d.undone = true;
      } else {
        d.applied = true;
      }
      reply = undo ? 'Perubahan diurungkan.' : 'Perubahan tersimpan.';
      await Future.wait([agenda.load(), finance.load()]);
    } catch (e) {
      if (e is AgendaFailure || e is FinanceFailure || e is DraftFailure) {
        if (undo) {
          d.undoAttempted = wasAttempted;
        } else {
          d.attempted = wasAttempted;
        }
        error = e.toString();
      } else {
        error = 'Hasil belum terkonfirmasi. Periksa dan coba lagi dengan draf yang sama; perubahan tidak digandakan.';
      }
    } finally {
      if (ready && !_disposed) await flush();
      busy = false;
      _emit();
    }
  }

  void change(void Function() edit) {
    final d = draft!;
    if (!usable || busy || d.applied || d.attempted) return;
    d.changed(repository.newId());
    edit();
    error = '';
    _notify();
  }

  void discard() {
    if (!usable || busy || draft?.attempted == true && draft?.applied != true) {
      return;
    }
    _archive();
    draft = null;
    reply = '';
    error = '';
    _notify();
  }

  Future<void> save() async {
    final d = draft;
    if (!usable || busy || d == null || d.applied) return;
    final invalid = d.validate();
    if (invalid != null) {
      error = invalid;
      _notify();
      return;
    }
    busy = true;
    error = '';
    _notify();
    final wasUncertain = d.attempted;
    try {
      d.attempted = true;
      if (!await flush()) {
        throw const DraftFailure(
          'Draf belum tersimpan. Belum ada item yang disimpan.',
        );
      }
      await repository.apply(d);
      if (_disposed) return;
      reply = 'Item terpilih sudah disimpan.';
      await Future.wait([agenda.load(), finance.load()]);
    } catch (e) {
      if (e is DraftFailure) {
        // Our own validation failures occur before commit or abort its callback.
        d.attempted = wasUncertain;
        error = e.message;
      } else {
        error = d.attempted
            ? 'Hasil simpan belum terkonfirmasi. Coba periksa dan simpan ulang; item tidak akan digandakan.'
            : 'Koneksi database belum tersedia. Draf tetap ada; coba lagi.';
      }
    } finally {
      if (ready && !_disposed) await flush();
      busy = false;
      _emit();
    }
  }

  Future<void> reviewAgain() async {
    final d = draft;
    if (!usable || busy || d == null || d.applied || d.attempted) return;
    busy = true;
    error = '';
    _notify();
    try {
      final r = await repository.revisions();
      if (_disposed) return;
      draft = AssistantDraft(
        id: d.id,
        operationId: repository.newId(),
        uid: d.uid,
        items: d.items,
        baseAgendaRevision: r['agenda']!,
        baseFinanceRevision: r['finance']!,
      )..revision = d.revision + 1;
      reply =
          'Versi catatan diperbarui. Periksa kembali item sebelum menyimpan.';
    } catch (_) {
      error = 'Versi terbaru belum dapat dimuat. Coba lagi.';
    } finally {
      if (ready && !_disposed) await flush();
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _disposed = true;
    service.dispose();
    super.dispose();
  }
}
