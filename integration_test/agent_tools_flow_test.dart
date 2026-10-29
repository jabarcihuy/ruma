import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/finance.dart';
import 'package:ruma/data/finance_repository.dart';
import 'package:ruma/data/assistant_draft.dart';
import 'package:ruma/data/assistant_service.dart';
import 'package:ruma/data/assistant_store.dart';
import 'package:ruma/data/draft_repository.dart';
import 'package:ruma/features/assistant/assistant_page.dart';
import 'package:ruma/ui/components.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class LocalModel extends Fake implements AssistantService {
  late Map<String, dynamic> result;
  @override
  Future<Map<String, dynamic>> propose(String message, String requestId, {List<Map<String, String>>? messages, List<Map<String, dynamic>> activeProposal = const [], String? conversationId}) async => parseAssistantResponse({
    ...result,
    'requestId': requestId,
    'content': 'Untrusted model copy',
  }, requestId);
  @override
  void dispose() {}
}

Map<String, dynamic> patch(Map<String, dynamic> values) => {
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
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('stages 1–3 native SDK and reviewed tools, local synthetic only', (
    tester,
  ) async {
    if (!RumaFirebaseOptions.useEmulator) throw StateError('demo-ruma only');
    final session = await initializeSession(), auth = FirebaseAuth.instance;
    await auth.signOut();
    await session.enterTemporarily();
    final db = initializeAgendaDatabase(),
        repo = DraftRepository(db, auth),
        a = AgendaRepository(db, auth),
        f = FinanceRepository(db, auth),
        api = LocalModel();
    final s = AssistantStore(repo, api, AgendaStore(a), FinanceStore(f))
      ..consent = true;
    final today = financeToday(),
        tomorrow = agendaDay(agendaLocal(DateTime.now().toUtc()))
            .add(const Duration(days: 1));
    final date = dateKey(tomorrow), month = today.substring(0, 7);
    final cases = <String>[];
    binding.reportData = {
      'project': 'demo-ruma',
      'productionWrites': 0,
      'modelCalls': 0,
      'cases': cases,
    };
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final c = HttpClient();
      try {
        final response = await (await c.getUrl(
          Uri.parse('http://127.0.0.1:8766/$name'),
        )).close();
        await response.drain<void>();
        expect(response.statusCode, 200);
      } finally {
        c.close(force: true);
      }
    }

    Future<void> tap(Finder finder) async {
      await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<int> operations() async =>
        (await repo.user.collection('operations').get()).size;
    Future<void> proposeChange(
      String name,
      String kind,
      String action,
      String date,
      Map<String, dynamic> p,
    ) async {
      s.discard();
      s.discardRecord();
      final text = action == 'delete'
          ? 'Hapus $name pada $date.'
          : 'Ubah $name pada $date, ${p['durationMinutes'] != null ? 'durasi ${p['durationMinutes']} menit' : 'nominal ${p['amountRupiah']} rupiah'}.';
      api.result = {
        'type': 'change_proposal',
        'change': {
          'recordType': kind,
          'action': action,
          'targetTitle': name,
          'targetDate': date,
          'sourceQuote': text,
          'patch': patch(p),
        },
      };
      await tester.runAsync(() => s.send(text));
      await tester.pumpAndSettle();
      expect(s.error, isEmpty);
      expect(s.recordDraft, isNotNull);
    }

    tester.testTextInput.register();
    try {
      await a.save(
        AgendaMutation(
          operationId: a.newId(),
          id: a.newId(),
          input: AgendaInput(
            title: 'Kuliah sintetis',
            kind: 'class',
            durationMinutes: 120,
            startAtUtc: agendaUtc(tomorrow, 8, 0),
          ),
        ),
      );
      const source =
          'Besok baca jurnal 30 menit. Besok kerjakan tugas 60 menit. Besok jalan 30 menit. Tadi makan 18 ribu.';
      api.result = {
        'type': 'draft_proposal',
        'items': [
          for (final (title, duration, quote) in [
            ('Baca jurnal', 30, 'Besok baca jurnal 30 menit.'),
            ('Kerjakan tugas', 60, 'Besok kerjakan tugas 60 menit.'),
            ('Jalan', 30, 'Besok jalan 30 menit.'),
          ])
            {
              'action': 'create_agenda',
              'title': title,
              'localDate': date,
              'durationMinutes': duration,
              'amountRupiah': null,
              'transactionType': null,
              'categoryId': null,
              'transactionStatus': null,
              'sourceQuote': quote,
              'startLocal': null,
              'deadlineLocal': null,
            },
          {
            'action': 'create_transaction',
            'title': 'Makan',
            'localDate': today,
            'durationMinutes': null,
            'amountRupiah': 18000,
            'transactionType': 'expense',
            'categoryId': 'food',
            'transactionStatus': 'actual',
            'sourceQuote': 'Tadi makan 18 ribu.',
            'startLocal': null,
            'deadlineLocal': null,
          },
        ],
      };
      await s.send(source);
      expect(s.error, isEmpty);
      final d = s.draft!;
      expect(d.items[0].agenda!.startAtUtc, agendaUtc(tomorrow, 10, 0));
      expect(d.items[1].agenda!.startAtUtc, agendaUtc(tomorrow, 10, 30));
      expect(d.items[2].agenda!.startAtUtc, agendaUtc(tomorrow, 11, 30));
      expect(await operations(), 1);
      await tester.pumpWidget(
        MaterialApp(
          theme: rumaTheme(),
          locale: const Locale('id'),
          supportedLocales: const [Locale('id')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: RumaPageBody(
              child: AssistantPage(store: s, onTab: (_) {}),
            ),
          ),
        ),
      );
      await capture('01-suggested-slots');
      await tap(find.byKey(const ValueKey('draft-save')));
      expect(d.applied, true);
      expect(s.error, isEmpty);
      expect((await a.read()).items.length, 4);
      expect((await f.read(month)).balance, -18000);
      cases.add(
        'three sequential non-overlapping suggested slots; reviewed atomic combined save',
      );
      s.discard();
      for (final kind in ['agenda', 'summary', 'history']) {
        api.result = {
          'type': 'read_request',
          'query': {
            'kind': kind,
            'date': kind == 'agenda' ? date : month,
            'categoryId': null,
          },
        };
        final before = await operations();
        await tester.runAsync(() => s.send('Tampilkan $kind'));
        await tester.pumpAndSettle();
        expect(s.error, isEmpty);
        expect(await operations(), before);
        expect(
          s.reply,
          contains(
            kind == 'agenda'
                ? 'Baca jurnal'
                : kind == 'summary'
                ? 'Rp18.000'
                : 'Makan',
          ),
        );
        if (kind == 'summary') await capture('02-verified-money-answer');
      }
      cases.add(
        'agenda, monthly summary and history read exact database data without writes',
      );
      await proposeChange('Baca jurnal', 'agenda', 'update', date, {
        'durationMinutes': 20,
      });
      await capture('03-edit-review');
      final before = await operations();
      await tap(find.byKey(const ValueKey('record-save')));
      expect(s.recordDraft!.applied, true);
      await s.saveRecord();
      expect(await operations(), before + 1);
      await tap(find.byKey(const ValueKey('record-undo')));
      expect(s.recordDraft!.undone, true);
      expect(
        (await a.read()).items
            .singleWhere((x) => x.input.title == 'Baca jurnal')
            .input
            .durationMinutes,
        30,
      );
      cases.add(
        'agenda edit requires approval, duplicate save idempotent, undo restores old duration',
      );
      await proposeChange('Makan', 'transaction', 'delete', today, {});
      await capture('04-delete-review');
      await tap(find.byKey(const ValueKey('record-save')));
      expect(s.error, isEmpty);
      expect((await f.read(month)).balance, 0);
      await tap(find.byKey(const ValueKey('record-undo')));
      expect(s.error, isEmpty);
      expect((await f.read(month)).balance, -18000);
      expect((await f.read(month)).items.length, 1);
      await s.saveRecord(undo: true);
      expect((await f.read(month)).balance, -18000);
      await capture('05-restored-transaction');
      cases.add(
        'transaction delete/restore exact ledger and monthly totals, no duplicate undo',
      );
      await proposeChange('Jalan', 'agenda', 'delete', date, {});
      await s.saveRecord();
      expect(s.error, isEmpty);
      expect((await a.read()).items.length, 3);
      await s.saveRecord(undo: true);
      expect(s.error, isEmpty);
      expect((await a.read()).items.length, 4);
      cases.add('agenda delete and exact tombstone restoration');
      await proposeChange('Makan', 'transaction', 'update', today, {
        'amountRupiah': 20000,
      });
      await s.saveRecord();
      expect(s.error, isEmpty);
      expect((await f.read(month)).balance, -20000);
      final current = (await f.read(month)).items.single;
      await f.save(
        FinanceMutation(
          operationId: f.newId(),
          id: current.id,
          originalVersion: current.version,
          input: TransactionInput(
            type: 'expense',
            amountRupiah: 21000,
            categoryId: 'food',
            localDate: today,
            description: 'Makan',
          ),
        ),
      );
      await s.saveRecord(undo: true);
      expect(s.error, isNotEmpty);
      expect((await f.read(month)).balance, -21000);
      cases.add('stale undo cannot overwrite a later transaction edit');
      s.discardRecord();
      await proposeChange('Baca jurnal', 'agenda', 'update', date, {
        'durationMinutes': 45,
      });
      await s.saveRecord();
      expect(s.error, contains('berbenturan'));
      expect(
        (await a.read()).items
            .singleWhere((x) => x.input.title == 'Baca jurnal')
            .input
            .durationMinutes,
        30,
      );
      cases.add('conflicting edit aborts without changing agenda');
      s.discardRecord();
      final oldUid = repo.uid;
      await tester.pumpWidget(const SizedBox());
      await auth.currentUser!.delete();
      await session.enterTemporarily();
      await expectLater(
        db.collection('users').doc(oldUid).collection('transactions').get(),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(repo.revisions(), throwsA(isA<DraftFailure>()));
      cases.add('cross-account read and stale session denied');
      await tester.pumpWidget(RumaApp(session: session, firestore: db));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      tester.testTextInput.unregister();
      await tester.tap(find.byKey(const ValueKey('assistant-message')));
      for (var i = 0; i < 50 && tester.view.viewInsets.bottom == 0; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.view.viewInsets.bottom, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-0')), findsNothing);
      final sendRect = tester.getRect(
        find.byKey(const ValueKey('assistant-send')),
      );
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final ime = tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
      expect(sendRect.bottom, lessThanOrEqualTo(height - ime));
      await capture('06-keyboard-send-visible');
      cases.add(
        'native keyboard: entire send button visible, navigation hidden',
      );
      binding.reportData!['passed'] = true;
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
      await auth.currentUser?.delete();
      session.dispose();
    }
  });
}
