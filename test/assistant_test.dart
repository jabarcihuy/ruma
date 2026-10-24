import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/features/agenda/agenda_form.dart';
import 'package:ruma/features/finance/finance_forms.dart';

const source = 'Besok baca jurnal 30 menit. Tadi makan 18 ribu.';
Map<String, dynamic> proposal({bool money = false}) => {
  'action': money ? 'create_transaction' : 'create_agenda',
  'title': money ? 'Makan' : 'Baca jurnal',
  'localDate': money ? '2026-10-01' : '2026-10-20',
  'durationMinutes': money ? null : 30,
  'amountRupiah': money ? 18000 : null,
  'transactionType': money ? 'expense' : null,
  'categoryId': money ? 'food' : null,
  'transactionStatus': money ? 'actual' : null,
  'sourceQuote': money ? 'Tadi makan 18 ribu.' : 'Besok baca jurnal 30 menit.',
};

class DraftRepoFake extends Fake implements DraftRepository {
  int ids = 0, saves = 0;
  bool uncertain = false;
  final receipts = <String>{};
  @override
  String get uid => 'owner';
  @override
  String newId() => 'id${ids++}';
  @override
  void check() {}
  @override
  Future<Map<String, int>> revisions() async => {'agenda': 0, 'finance': 0};
  @override
  Future<void> apply(AssistantDraft d) async {
    d.attempted = true;
    if (receipts.add(d.operationId)) saves++;
    if (uncertain) {
      throw const SocketException('synthetic lost acknowledgement');
    }
    d.applied = true;
  }
}

class ServiceFake extends Fake implements AssistantService {
  int calls = 0;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> propose(String message, String id) async {
    calls++;
    return pending == null
        ? {
            'type': 'draft_proposal',
            'content': 'Draf siap ditinjau. Data belum disimpan.',
            'items': [proposal(), proposal(money: true)],
          }
        : pending!.future;
  }

  @override
  void dispose() {}
}

class AgendaRepoFake extends Fake implements AgendaRepository {
  @override
  Future<AgendaSnapshot> read() async => const AgendaSnapshot([], 0);
  @override
  String newId() => 'new-agenda';
  @override
  String get uid => 'owner';
}

class FinanceRepoFake extends Fake implements FinanceRepository {
  @override
  Future<FinanceSnapshot> read(String month) async => FinanceSnapshot(
    month: MonthFinance(key: month),
    items: [],
    balance: 0,
    revision: 0,
  );
  @override
  String newId() => 'new-money';
  @override
  String get uid => 'owner';
}

AssistantStore makeStore(DraftRepoFake repo, ServiceFake api) => AssistantStore(
  repo,
  api,
  AgendaStore(AgendaRepoFake()),
  FinanceStore(FinanceRepoFake()),
);
Widget app(Widget child, {bool form = false}) => MaterialApp(
  theme: rumaTheme(),
  locale: const Locale('id'),
  supportedLocales: const [Locale('id')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: form
      ? child
      : Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
);
void main() {
  test('strict proposal parsing rejects invented quote, unknown authority, future money and excess items', () {
    var id = 0;
    List<DraftEntry> parse(List<Map<String, dynamic>> list) =>
        parseProposal(list, source, () => 'id${id++}');
    expect(parse([proposal(), proposal(money: true)]).length, 2);
    for (final bad in [
      {...proposal(), 'sourceQuote': 'invented'},
      {...proposal(), 'action': 'delete_agenda'},
      {...proposal(), 'operationId': 'fake'},
      {...proposal(money: true), 'amountRupiah': 1.5},
      {...proposal(money: true), 'localDate': '2027-01-01'},
      {...proposal(money: true), 'transactionStatus': 'planned'},
      {...proposal(), 'localDate': '2026-02-30'},
      {...proposal(), 'durationMinutes': 721},
    ]) {
      expect(() => parse([bad]), throwsA(isA<DraftFailure>()));
    }
    expect(
      () => parse(List.generate(4, (_) => proposal())),
      throwsA(isA<DraftFailure>()),
    );
    expect(
      () => parseAssistantResponse({
        'requestId': 'wrong',
        'type': 'draft_proposal',
        'content': 'x',
      }, 'right'),
      throwsA(isA<DraftFailure>()),
    );
  });
  test(
    'incomplete output uses coded clarification and cannot carry draft items',
    () {
      final response = <String, dynamic>{
        'requestId': 'safe',
        'type': 'clarification',
        'reason': 'incomplete_draft',
        'content': 'Sudah disimpan',
        'items': <dynamic>[],
      };
      final parsed = parseAssistantResponse(response, 'safe');
      expect(
        parsed['content'],
        'Draf belum lengkap. Perjelas kegiatan atau transaksinya.',
      );
      expect(
        () => parseAssistantResponse({
          ...response,
          'items': [proposal()],
        }, 'safe'),
        throwsA(isA<DraftFailure>()),
      );
      expect(
        () => parseAssistantResponse({
          ...response,
          'reason': 'model_invented',
        }, 'safe'),
        throwsA(isA<DraftFailure>()),
      );
    },
  );
  test('consent required, edit changes revision, duplicate taps cannot duplicate save', () async {
    final r = DraftRepoFake(), api = ServiceFake(), s = makeStore(r, api);
    await s.send(source);
    expect(api.calls, 0);
    s.consent = true;
    await s.send(source);
    expect(r.saves, 0);
    final d = s.draft!;
    final original = d.requestKey;
    s.change(() => d.items.last.included = false);
    expect(d.revision, 2);
    expect(d.requestKey, isNot(original));
    await Future.wait([s.save(), s.save()]);
    expect(r.saves, 1);
    expect(d.applied, true);
    expect(api.calls, 1);
    s.dispose();
    s.agenda.dispose();
    s.finance.dispose();
  });
  test(
    'uncertain acknowledgement locks edits and stable retry reconciles receipt',
    () async {
      final r = DraftRepoFake()..uncertain = true,
          api = ServiceFake(),
          s = makeStore(r, api)..consent = true;
      await s.send(source);
      final d = s.draft!, key = d.requestKey;
      await s.save();
      expect(d.attempted, true);
      expect(d.applied, false);
      s.change(() => d.items.first.included = false);
      s.discard();
      expect(s.draft, same(d));
      expect(d.requestKey, key);
      r.uncertain = false;
      await s.save();
      expect(r.saves, 1);
      expect(d.applied, true);
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
  test(
    'response after store disposal cannot restore old account draft',
    () async {
      final r = DraftRepoFake(),
          api = ServiceFake()..pending = Completer(),
          s = makeStore(r, api)..consent = true;
      final work = s.send(source);
      s.dispose();
      api.pending!.complete({
        'type': 'draft_proposal',
        'content': 'd',
        'items': [proposal()],
      });
      await work;
      expect(s.draft, isNull);
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
  testWidgets(
    'review at 320px and 200% text supports remove, restore and editing without saving',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = DraftRepoFake(),
          api = ServiceFake(),
          s = makeStore(r, api)..consent = true;
      await s.send(source);
      await tester.pumpWidget(
        app(
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
      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      final e = s.draft!.items.first;
      await tap(find.byKey(ValueKey('draft-toggle-${e.id}')));
      expect(e.included, false);
      await tap(find.byKey(ValueKey('draft-toggle-${e.id}')));
      expect(e.included, true);
      // Test actual shared form callbacks separately to keep route scrolling predictable.
      AgendaInput? changed;
      Navigator.of(tester.element(find.byType(AssistantPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => AgendaFormPage(
            store: s.agenda,
            existing: AgendaItem(id: e.id, version: 0, input: e.agenda!),
            onDraftChanged: (v) => changed = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('agenda-save')));
      expect(changed?.title, 'Baca jurnal');
      expect(r.saves, 0);
      TransactionInput? money;
      Navigator.of(tester.element(find.byType(AssistantPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => FinanceFormPage(
            store: s.finance,
            existing: MoneyTransaction(
              id: 'm',
              version: 0,
              input: s.draft!.items.last.money!,
            ),
            onDraftChanged: (v) => money = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(find.byKey(const ValueKey('finance-save')));
      expect(money?.amountRupiah, 18000);
      expect(r.saves, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
}
