import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/agent_tools.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';

import 'assistant_test.dart' as f;

final day = DateTime.utc(2026, 11, 1);
AgendaInput task(String title, int hour, {int minutes = 60}) => AgendaInput(
  title: title,
  startAtUtc: agendaUtc(day, hour, 0),
  durationMinutes: minutes,
);
Map<String, dynamic> patch([Map<String, dynamic> values = const {}]) => {
  'title': null,
  'durationMinutes': null,
  'startLocal': null,
  'deadlineLocal': null,
  'status': null,
  'amountRupiah': null,
  'categoryId': null,
  'localDate': null,
  ...values,
};
Map<String, dynamic> change({bool money = false, bool delete = false}) => {
  'recordType': money ? 'transaction' : 'agenda',
  'action': delete ? 'delete' : 'update',
  'targetTitle': 'Belajar',
  'targetDate': money ? '2026-10-01' : null,
  'sourceQuote': delete ? 'Hapus Belajar' : 'Ubah Belajar jadi 30 menit',
  'patch': patch(
    delete
        ? {}
        : money
        ? {'amountRupiah': 30000}
        : {'durationMinutes': 30},
  ),
};

class AgendaRepo extends f.AgendaRepoFake {
  final mutations = <AgendaMutation>[];
  List<AgendaItem> items = [
    AgendaItem(id: 'a', version: 1, input: task('Belajar', 9)),
  ];
  @override
  Future<AgendaSnapshot> read() async => AgendaSnapshot(items, 0);
  @override
  Future<AgendaSnapshot> save(AgendaMutation m) async {
    mutations.add(m);
    return AgendaSnapshot(items, mutations.length);
  }
}

class Api extends f.ServiceFake {
  late Map<String, dynamic> response;
  @override
  Future<Map<String, dynamic>> propose(String text, String id, {List<Map<String, String>>? messages, List<Map<String, dynamic>> activeProposal = const [], String? conversationId}) async {
    calls++;
    return response;
  }
}

void main() {
  test('slots respect window, multiple reservations, deadlines and exact boundaries', () {
    final busy = [task('Kuliah', 8, minutes: 120), task('Baca', 11)];
    final one = suggestSlot(
      const AgendaInput(title: 'A', durationMinutes: 60),
      '2026-11-01',
      busy,
      now: agendaUtc(day, 7, 0),
    )!;
    expect(one.startAtUtc, agendaUtc(day, 10, 0));
    final two = suggestSlot(
      const AgendaInput(title: 'B', durationMinutes: 30),
      '2026-11-01',
      [...busy, one],
      now: agendaUtc(day, 7, 0),
    )!;
    expect(two.startAtUtc, agendaUtc(day, 12, 0));
    expect(
      suggestSlot(
        const AgendaInput(title: 'C', durationMinutes: 120),
        '2026-11-01',
        busy,
        now: agendaUtc(day, 7, 0),
        fromMinute: 8 * 60,
        toMinute: 11 * 60,
      ),
      isNull,
    );
    expect(
      suggestSlot(
        AgendaInput(title: 'D', deadlineAtUtc: agendaUtc(day, 9, 0)),
        '2026-11-01',
        busy,
        now: agendaUtc(day, 7, 0),
      ),
      isNull,
    );
    expect(
      suggestSlot(
        const AgendaInput(title: 'E'),
        '2026-10-31',
        [],
        now: agendaUtc(day, 7, 0),
      ),
      isNull,
    );
    expect(
      suggestSlot(const AgendaInput(title: 'F'), '2026-11-01', [
        task('Done', 8).withStatus('completed'),
      ], now: agendaUtc(day, 7, 0))!.startAtUtc,
      agendaUtc(day, 8, 0),
    );
  });
  test(
    'read answers use verified totals, disclose coverage and bound history',
    () {
      final s = FinanceSnapshot(
        month: const MonthFinance(
          key: '2026-10',
          income: 100000,
          expense: 18000,
          budget: 50000,
          categoryExpense: {'food': 18000},
        ),
        items: [],
        balance: 82000,
        revision: 1,
      );
      final text = moneyAnswer(s);
      expect(text, contains('Rp82.000'));
      expect(text, contains('Rp32.000'));
      expect(text, contains('Makan: Rp18.000'));
      expect(text, contains('Hanya mencakup'));
      expect(moneyAnswer(s, history: true), contains('0 transaksi'));
      final a = agendaAnswer(
        AgendaSnapshot([
          AgendaItem(id: 'a', version: 1, input: task('Belajar', 9)),
          const AgendaItem(
            id: 'b',
            version: 1,
            input: AgendaInput(title: 'Tanpa jam'),
          ),
        ], 1),
        '2026-11-01',
      );
      expect(a, contains('09:00–10:00'));
      expect(a, contains('1 tugas belum dijadwalkan'));
    },
  );
  test('existing target must be exact and unique; invalid fields cannot cross domains', () {
    final item = AgendaItem(id: 'a', version: 1, input: task('Belajar', 9));
    validateChange(change());
    expect(
      resolveRecord(change(), [item], [], 'op').agenda!.durationMinutes,
      30,
    );
    expect(
      () => resolveRecord(change(), [item, item], [], 'op'),
      throwsA(isA<DraftFailure>()),
    );
    expect(
      () => resolveRecord(
        {...change(), 'targetTitle': 'Belaj'},
        [item],
        [],
        'op',
      ),
      throwsA(isA<DraftFailure>()),
    );
    expect(
      () => resolveRecord(
        {
          ...change(),
          'patch': patch({'amountRupiah': 5}),
        },
        [item],
        [],
        'op',
      ),
      throwsA(isA<DraftFailure>()),
    );
    for (final bad in [
      {...change(), 'uid': 'other'},
      {
        ...change(),
        'patch': patch({'durationMinutes': 1.5}),
      },
      {
        ...change(),
        'patch': patch({'startLocal': '2026-02-30T08:00'}),
      },
      {
        ...change(delete: true),
        'patch': patch({'title': 'Oops'}),
      },
    ]) {
      expect(() => validateChange(bad), throwsA(isA<DraftFailure>()));
    }
    expect(
      () => parseAssistantResponse({
        'type': 'read_request',
        'requestId': 'r',
        'content': 'x',
        'query': {'kind': 'summary', 'date': '2026-13', 'categoryId': null},
      }, 'r'),
      throwsA(isA<DraftFailure>()),
    );
  });
  test(
    'read never writes; edit and undo require separate explicit approval',
    () async {
      final a = AgendaRepo(), api = Api(), r = f.DraftRepoFake();
      final s = AssistantStore(
        r,
        api,
        AgendaStore(a),
        FinanceStore(f.FinanceRepoFake()),
      )..consent = true;
      api.response = {
        'type': 'read_request',
        'query': {'kind': 'agenda', 'date': '2026-11-01', 'categoryId': null},
        'content': 'x',
      };
      await s.send('Agenda 1 November?');
      expect(s.reply, contains('Belajar'));
      expect(a.mutations, isEmpty);
      api.response = {
        'type': 'change_proposal',
        'change': change(),
        'content': 'Draf',
      };
      await s.send('Ubah Belajar jadi 30 menit');
      expect(s.recordDraft, isNotNull);
      expect(a.mutations, isEmpty);
      await s.saveRecord();
      expect(a.mutations.length, 1);
      expect(a.mutations.single.input.durationMinutes, 30);
      await s.saveRecord();
      expect(a.mutations.length, 1);
      await s.saveRecord(undo: true);
      expect(a.mutations.last.input.durationMinutes, 60);
      expect(a.mutations.last.originalVersion, 2);
      expect(s.recordDraft!.undone, true);
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
  testWidgets('old-record review has no overflow at narrow 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = f.makeStore(f.DraftRepoFake(), f.ServiceFake())
      ..recordDraft = resolveRecord(
        change(),
        [AgendaItem(id: 'a', version: 1, input: task('Belajar', 9))],
        [],
        'op',
      );
    await tester.pumpWidget(
      f.app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: AssistantPage(store: s, onTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    s.agenda.dispose();
    s.finance.dispose();
  });
}
