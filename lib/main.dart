import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/main_shell.dart';
import 'app/theme.dart';
import 'data/auth_session.dart';
import 'data/push_notifications.dart';
import 'features/auth/welcome_page.dart';
import 'firebase_options.dart';

Future<AuthSession> initializeSession() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: RumaFirebaseOptions.useEmulator
        ? RumaFirebaseOptions.emulator
        : RumaFirebaseOptions.android,
  );
  final auth = FirebaseAuth.instance;
  if (RumaFirebaseOptions.useEmulator) {
    await auth.useAuthEmulator(
      const String.fromEnvironment(
        'AUTH_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      9096,
      automaticHostMapping: false,
    );
  }
  return AuthSession(auth);
}

FirebaseFirestore initializeAgendaDatabase() {
  final db = FirebaseFirestore.instance;
  // Memory cache only for the first slice: no account data survives on disk.
  db.settings = const Settings(persistenceEnabled: false);
  if (RumaFirebaseOptions.useEmulator) {
    db.useFirestoreEmulator(
      const String.fromEnvironment(
        'FIRESTORE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      8086,
      automaticHostMapping: false,
    );
  }
  return db;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: RumaColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    final session = await initializeSession();
    final db = initializeAgendaDatabase();
    final notifications = RumaNotifications(db, FirebaseAuth.instance);
    try {
      await notifications.initialize();
      session.beforeSignOut = notifications.unregister;
    } catch (_) {
      notifications.error =
          'Notifikasi belum siap. Coba buka aplikasi kembali.';
    }
    runApp(
      RumaApp(session: session, firestore: db, notifications: notifications),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: rumaTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ruma belum dapat dibuka.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Periksa koneksi lalu coba lagi.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: main,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RumaApp extends StatelessWidget {
  const RumaApp({
    super.key,
    required this.session,
    this.firestore,
    this.notifications,
  });
  final AuthSession session;
  final RumaNotifications? notifications;
  final FirebaseFirestore? firestore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ruma',
    debugShowCheckedModeBanner: false,
    theme: rumaTheme(),
    locale: const Locale('id'),
    supportedLocales: const [Locale('id')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.ready) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Memuat sesi Ruma',
              ),
            ),
          );
        }
        if (session.account == null) return WelcomePage(session: session);
        return MainShell(
          key: ValueKey(session.account!.uid),
          session: session,
          firestore: firestore,
          notifications: notifications,
        );
      },
    ),
  );
}
