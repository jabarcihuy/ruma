import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruma/main.dart';
import 'package:ruma/firebase_options.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const environment = RumaFirebaseOptions.useEmulator
      ? 'emulator'
      : 'production';
  testWidgets(
    '$environment Android Firebase SDK: anonymous linking, sign out, sign in, validation and navigation',
    (tester) async {
      if (!RumaFirebaseOptions.useEmulator &&
          !const bool.fromEnvironment('AUTH_LIVE_TESTS')) {
        throw StateError(
          'Use AUTH_EMULATOR=true for isolated tests, or explicitly opt in '
          'with AUTH_LIVE_TESTS=true for disposable production Auth fixtures.',
        );
      }
      // Programmatic entry must track fresh TextInput client IDs after a field
      // is disabled while Auth is busy. Native keyboard UX is tested separately.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      final session = await initializeSession();
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      await tester.pumpWidget(RumaApp(session: session));
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      Future<void> screenshot(String name) async {
        // Let asynchronous SVG decoding finish before recording visual evidence.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 1)),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot('$environment-$name');
      }

      await tester.pumpAndSettle();
      await screenshot('01-welcome');
      String? ownedUid;
      const runId = String.fromEnvironment('AUTH_TEST_RUN');
      final suffix = runId.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : runId;
      final email = 'ruma-foundation-$suffix@example.invalid';
      final password = 'Ruma-test-$suffix!';
      Future<void> tapText(String text) async {
        final finder = find.text(text).last;
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 60),
        );
      }

      Future<void> submit({String? expectedPassword}) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (expectedPassword != null) {
          final field = tester.widget<TextFormField>(
            find.byKey(const ValueKey('password')),
          );
          expect(
            field.controller!.text == expectedPassword,
            isTrue,
            reason: 'The retry must submit the newly entered password',
          );
        }
        final button = find.byKey(const ValueKey('auth-submit'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 60),
        );
      }

      try {
        await tapText('Masuk atau buat akun');
        await screenshot('02-signin');
        await tester.tap(find.byKey(const ValueKey('auth-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Masukkan email yang valid.'), findsOneWidget);
        await tester.tap(find.byTooltip('Kembali'));
        await tester.pumpAndSettle();
        await tapText('Mulai tanpa akun');
        await tapText('Lanjut tanpa daftar');
        expect(session.account?.anonymous, isTrue, reason: session.error);
        ownedUid = auth.currentUser!.uid;
        expect(find.text('Waktu & uangmu.'), findsOneWidget);
        await screenshot('03-home');
        for (var index = 1; index <= 4; index++) {
          await tester.tap(find.byKey(ValueKey('tab-$index')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await screenshot('04-profile-temporary');
        await tapText('Daftarkan email');
        await screenshot('05-signup');
        await tester.enterText(find.byKey(const ValueKey('name')), 'Naya');
        await tester.enterText(find.byKey(const ValueKey('email')), email);
        await tester.enterText(
          find.byKey(const ValueKey('password')),
          password,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('privacy-agreement')),
        );
        await tester.tap(find.byKey(const ValueKey('privacy-agreement')));
        await submit();
        expect(session.account?.anonymous, isFalse, reason: session.error);
        expect(
          auth.currentUser?.uid,
          ownedUid,
          reason: 'Linking must preserve the original UID',
        );
        expect(session.account?.name, 'Naya');
        await tester.tap(find.byKey(const ValueKey('tab-4')));
        await tester.pumpAndSettle();
        await tapText('Keluar dari akun');
        await tapText('Batalkan');
        expect(auth.currentUser?.uid, ownedUid);
        await tapText('Keluar dari akun');
        await tapText('Keluar');
        expect(session.account, isNull);
        await tapText('Masuk atau buat akun');
        await tester.enterText(find.byKey(const ValueKey('email')), email);
        await tester.enterText(
          find.byKey(const ValueKey('password')),
          'incorrect-password',
        );
        await submit();
        expect(session.account, isNull);
        expect(
          find.textContaining('Email atau kata sandi belum cocok'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('email')))
              .controller!
              .text,
          email,
        );
        await tester.enterText(
          find.byKey(const ValueKey('password')),
          password,
        );
        await tester.pumpAndSettle();
        await submit(expectedPassword: password);
        expect(auth.currentUser?.uid, ownedUid, reason: session.error);
        await tester.tap(find.byKey(const ValueKey('tab-4')));
        await tester.pumpAndSettle();
        expect(find.text('Naya'), findsOneWidget);
        await screenshot('06-profile-registered');
        expect(await session.updateName('Naya Putri'), isTrue);
        expect(session.account?.name, 'Naya Putri');
        // Also exercise direct registration, independently of anonymous linking.
        await auth.currentUser!.delete();
        await auth.signOut();
        final registered = await session.signUp('Naya', email, password);
        ownedUid = auth.currentUser?.uid;
        expect(registered, isTrue, reason: session.error);
        expect(ownedUid, isNotNull);
        expect(session.account?.anonymous, isFalse, reason: session.error);
        expect(session.account?.name, 'Naya');
        binding.reportData ??= {};
        binding.reportData![environment] = {
          'anonymous': true,
          'linkedUidPreserved': true,
          'displayNamePersisted': true,
          'logoutCancel': true,
          'logout': true,
          'wrongPasswordRejected': true,
          'formPreservedAfterFailure': true,
          'login': true,
          'fiveTabs': true,
          'nameUpdated': true,
          'directRegistration': true,
          'cpuProxyRetested': false,
          'firebaseProject': environment == 'emulator'
              ? 'demo-ruma'
              : 'mobile-app-3479f',
        };
      } finally {
        // Delete only the synthetic account this test owns, never another session.
        if (ownedUid != null) {
          if (auth.currentUser == null) {
            try {
              await auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            } catch (_) {
              /* Original test failure is reported by the runner. */
            }
          }
          if (auth.currentUser?.uid == ownedUid) {
            await auth.currentUser!.delete();
            binding.reportData?[environment]?['fixtureDeleted'] = true;
          }
        }
        await auth.signOut();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      }
    },
  );
}
