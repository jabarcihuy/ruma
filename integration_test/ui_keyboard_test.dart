import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/firebase_options.dart';
import 'package:ruma/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native assistant keyboard leaves the input visible and hides navigation',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator) {
        throw StateError('Local demo-ruma only');
      }
      final session = await initializeSession();
      await FirebaseAuth.instance.signOut();
      await session.enterTemporarily();
      try {
        await tester.pumpWidget(
          RumaApp(session: session, firestore: initializeAgendaDatabase()),
        );
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
        expect(tester.takeException(), isNull);
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:8766/22-assistant-keyboard'),
          );
          final response = await request.close();
          await response.drain<void>();
          expect(response.statusCode, HttpStatus.ok);
        } finally {
          client.close(force: true);
        }
        binding.reportData = {
          'passed': true,
          'project': 'demo-ruma',
          'nativeInsetsObserved': true,
          'productionWrites': 0,
          'modelCalls': 0,
        };
      } finally {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await FirebaseAuth.instance.currentUser?.delete();
        session.dispose();
      }
    },
  );
}
