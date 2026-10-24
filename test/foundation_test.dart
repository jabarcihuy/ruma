import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/auth_session.dart';
import 'package:ruma/features/auth/auth_form.dart';
import 'package:ruma/main.dart';

class QuietAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> userChanges() => const Stream.empty();
  @override
  User? get currentUser => null;
}

AuthSession session({bool signedIn = false}) {
  final session = AuthSession(QuietAuth())..ready = true;
  if (signedIn) {
    session.account = const RumaAccount(
      uid: 'synthetic',
      name: 'Naya',
      anonymous: false,
      email: 'naya@example.invalid',
    );
  }
  return session;
}

void main() {
  test('validation does not trim passwords and login failures do not expose account existence', () {
    expect(validateEmail(' naya@kampus.ac.id '), isNull);
    expect(validateEmail('naya@'), isNotNull);
    expect(validateName('   '), isNotNull);
    expect(validatePassword('123', signup: true), isNotNull);
    expect(validatePassword(' x12345 ', signup: true), isNull);
    expect(
      authErrorMessage('wrong-password'),
      authErrorMessage('user-not-found'),
    );
    expect(
      authErrorMessage('credential-already-in-use'),
      contains('Akun sementara tetap tersedia'),
    );
    expect(
      authErrorMessage('network-request-failed'),
      contains('Isianmu tetap ada'),
    );
  });

  testWidgets(
    'welcome and sign-in remain usable on a small screen at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = session();
      addTearDown(auth.dispose);
      await tester.pumpWidget(RumaApp(session: auth));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Masuk atau buat akun'));
      await tester.tap(find.text('Masuk atau buat akun'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Masukkan email yang valid.'));
      expect(find.text('Masukkan email yang valid.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'five tabs preserve icon geometry, semantics and home navigation',
    (tester) async {
      final auth = session(signedIn: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(RumaApp(session: auth));
      await tester.pumpAndSettle();
      for (var tab = 0; tab < 5; tab++) {
        final target = find.byKey(ValueKey('tab-$tab'));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Naya'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-0')));
      await tester.pumpAndSettle();
      expect(find.text('Waktu & uangmu.'), findsOneWidget);
      expect(find.text('Uang bulan ini'), findsOneWidget);
      expect(find.byTooltip('Asisten'), findsOneWidget);
    },
  );
}
