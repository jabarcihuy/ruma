import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/assistant_snapshot.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/agent_tools.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';

import 'assistant_test.dart' as f;

class MemoryRepo extends f.DraftRepoFake {
  int revision = 0;
  String? payload;
  bool failWrites = false, owner = true;
  @override
  void check() {
    if (!owner) throw const DraftFailure('Sesi berubah');
  }

  @override
  Future<(int, String?)> readAssistant() async {
    check();
    return (revision, payload);
  }

  @override
  Future<int> writeAssistant(String value, int expected) async {
    check();
    if (failWrites) throw const SocketException('offline');
    if (payload == value &&
        (revision == expected || revision == expected + 1)) {
      return revision;
    }
    if (revision != expected) {
      throw const DraftFailure('Riwayat berubah di perangkat lain.');
    }
    payload = value;
    return ++revision;
  }

  @override
  Future<bool> receipt(AssistantDraft d) async {
    check();
    return receipts.contains(d.operationId);
  }
}

AssistantStore create(MemoryRepo r, f.ServiceFake api) => AssistantStore(
  r,
  api,
  AgendaStore(f.AgendaRepoFake()),
  FinanceStore(f.FinanceRepoFake()),
  persistent: true,
);
void main() {
  test(
    'complete draft identity, selections and review flags survive round trip',
    () {
      final d =
          AssistantDraft(
              id: 'draft',
              operationId: 'op',
              uid: 'owner',
              items: [
                DraftEntry(
                  id: 'a',
                  quote: 'belajar',
                  localDate: '2026-10-20',
                  agenda: const AgendaInput(title: 'Belajar'),
                  included: false,
                  suggestedTime: true,
                ),
              ],
              baseAgendaRevision: 7,
              baseFinanceRevision: 8,
            )
            ..attempted = true
            ..revision = 4;
      final restored = AssistantSnapshot.decode(
        AssistantSnapshot(draft: d).encode('owner'),
        'owner',
      ).draft!;
      expect(restored.requestKey, d.requestKey);
      expect(restored.operationId, 'op');
      expect(restored.items.single.included, false);
      expect(restored.items.single.suggestedTime, true);
      expect(restored.attempted, true);
    },
  );
  test('old record and stable undo operation survive without changing request inputs', () {
    final r =
        RecordDraft(
            operationId: 'edit',
            delete: true,
            id: 'a',
            version: 3,
            beforeAgenda: const AgendaInput(title: 'Sebelum'),
            agenda: const AgendaInput(title: 'Sebelum'),
          )
          ..attempted = true
          ..applied = true
          ..undoAttempted = true
          ..undoOperationId = 'undo';
    final restored = AssistantSnapshot.decode(
      AssistantSnapshot(record: r).encode('owner'),
      'owner',
    ).record!;
    expect(restored.beforeAgenda!.toJson(), r.beforeAgenda!.toJson());
    expect(restored.undoOperationId, 'undo');
    expect(restored.version, 3);
    expect(restored.delete, true);
  });
  test('malformed, foreign and oversized snapshots fail closed; history is bounded', () {
    final valid = AssistantSnapshot().encode('owner');
    for (final data in [
      '{',
      valid.replaceFirst('"from":480', '"from":1500'),
      jsonEncode({...jsonDecode(valid) as Map, 'uid': 'other'}),
      'x' * (assistantPayloadLimit + 1),
    ]) {
      expect(
        () => AssistantSnapshot.decode(data, 'owner'),
        throwsA(isA<DraftFailure>()),
      );
    }
    final h = List.generate(
      15,
      (i) => {'message': 'msg$i', 'reply': 'x' * 24000, 'at': ''},
    );
    final data = AssistantSnapshot(history: h).encode('owner');
    expect(data.length, lessThanOrEqualTo(assistantPayloadLimit));
    expect(
      AssistantSnapshot.decode(data, 'owner').history.last['message'],
      'msg14',
    );
  });
  test('recreated store restores edited input, draft and history, never resends model', () async {
    final r = MemoryRepo(), api = f.ServiceFake(), s = create(r, api);
    await s.load();
    s.consent = true;
    await s.send(f.source);
    s.change(() => s.draft!.items.first.included = false);
    s.input = 'teks yang belum dikirim';
    await s.flush();
    final key = s.draft!.requestKey, id = s.draft!.operationId;
    s.dispose();
    final next = create(r, api);
    await next.load();
    expect(next.input, 'teks yang belum dikirim');
    expect(next.draft!.requestKey, key);
    expect(next.draft!.operationId, id);
    expect(api.calls, 1);
    await next.save();
    expect(r.saves, 1);
    next.discard();
    await next.flush();
    next.dispose();
    final last = create(r, api);
    await last.load();
    expect(last.history.single['message'], f.source);
    expect(last.draft, isNull);
    expect(r.saves, 1);
    last.dispose();
  });
  test('lost commit acknowledgement is resolved by receipt after restart without duplication', () async {
    final r = MemoryRepo()..uncertain = true,
        api = f.ServiceFake(),
        s = create(r, api);
    await s.load();
    s.consent = true;
    await s.send(f.source);
    await s.save();
    expect(s.draft!.attempted, true);
    expect(s.draft!.applied, false);
    expect(r.saves, 1);
    s.dispose();
    final next = create(r, api);
    await next.load();
    expect(next.draft!.applied, true);
    await next.save();
    expect(r.saves, 1);
    expect(api.calls, 1);
    next.dispose();
  });
  test(
    'failed durable checkpoint blocks provider and business commit',
    () async {
      final r = MemoryRepo(), api = f.ServiceFake(), s = create(r, api);
      await s.load();
      s.consent = true;
      r.failWrites = true;
      await s.send(f.source);
      expect(api.calls, 0);
      r.failWrites = false;
      await s.send(f.source);
      expect(api.calls, 1);
      r.failWrites = true;
      await s.save();
      expect(r.saves, 0);
      expect(s.storageError, isNotEmpty);
      s.dispose();
    },
  );
  test('stale device cannot overwrite workspace and session changes cannot read it', () async {
    final r = MemoryRepo(),
        a = create(r, f.ServiceFake()),
        b = create(r, f.ServiceFake());
    await a.load();
    await b.load();
    a.input = 'A';
    await a.flush();
    b.input = 'B';
    expect(await b.flush(), false);
    expect(b.storageBlocked, true);
    expect(AssistantSnapshot.decode(r.payload!, 'owner').input, 'A');
    a.dispose();
    b.dispose();
    r.owner = false;
    final foreign = create(r, f.ServiceFake());
    await foreign.load();
    expect(foreign.ready, false);
    expect(foreign.draft, isNull);
    foreign.dispose();
  });
  testWidgets(
    'restored input and chronological history fit 320 width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = MemoryRepo()
        ..payload = AssistantSnapshot(
          input: 'Pesan tersimpan',
          history: [
            {'message': 'Tadi makan', 'reply': 'Draf ditinjau', 'at': ''},
          ],
        ).encode('owner')
        ..revision = 1;
      final s = create(r, f.ServiceFake());
      await tester.pumpWidget(
        f.app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AssistantPage(store: s, onTab: (_) {}),
          ),
        ),
      );
      await s.load();
      await tester.pumpAndSettle();
      expect(find.text('Pesan tersimpan'), findsOneWidget);
      expect(find.text('Tadi makan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
