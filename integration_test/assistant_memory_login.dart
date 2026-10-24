import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ruma/main.dart' as app;
import 'package:ruma/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!RumaFirebaseOptions.useEmulator) {
    throw StateError('Local demo-ruma fixture only');
  }
  final session = await app.initializeSession();
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'assistant-memory@ruma.invalid',
    password: 'SyntheticMemory123!',
  );
  runApp(
    app.RumaApp(session: session, firestore: app.initializeAgendaDatabase()),
  );
  // ignore: avoid_print
  print('RUMA_MEMORY_LOCAL_LOGIN_READY');
}
