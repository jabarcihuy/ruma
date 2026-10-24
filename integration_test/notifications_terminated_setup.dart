// Synthetic AVD fixture only. Host restores normal APK and deletes exact fixture.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ruma/main.dart' as app;
import 'package:ruma/firebase_options.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/agenda_repository.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/data/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (RumaFirebaseOptions.useEmulator ||
      !const bool.fromEnvironment('TERMINATED_FCM_FIXTURE')) {
    throw StateError('Explicit synthetic production fixture only');
  }
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('Menyiapkan uji notifikasi…'))),
    ),
  );
  final session = await app.initializeSession(), auth = FirebaseAuth.instance;
  final oldDeleted = <String>[];
  final cleanupDb = app.initializeAgendaDatabase();
  final prior = auth.currentUser;
  if (prior != null) {
    if (!prior.isAnonymous) throw StateError('Synthetic AVD account required');
    final a = AgendaRepository(cleanupDb, auth),
        r = ReminderRepository(cleanupDb, auth);
    final items = (await a.read()).items;
    if (items.length > 1 ||
        items.any((x) => x.input.title != 'QA FCM aplikasi ditutup')) {
      throw StateError('Unexpected prior fixture');
    }
    for (final item in items) {
      final job = await r.read(item.id);
      if ((job?['attempts'] ?? 0) != 0) {
        throw StateError('Prior fixture used remaining send budget');
      }
      if (job != null) await r.configure(item, false, 60);
    }
    final devices = await cleanupDb
        .collection('users')
        .doc(prior.uid)
        .collection('devices')
        .get();
    for (final d in devices.docs) {
      await d.reference.delete();
    }
    await prior.delete();
    oldDeleted.add(prior.uid);
  }
  await auth.signOut();
  await auth.signInAnonymously();
  final db = cleanupDb,
      a = AgendaRepository(db, auth),
      r = ReminderRepository(db, auth);
  final push = RumaNotifications(db, auth);
  await push.initialize();
  if (!await push.setEnabled(true)) throw StateError(push.error);
  final id = a.newId();
  await a.save(
    AgendaMutation(
      operationId: a.newId(),
      id: id,
      input: AgendaInput(
        title: 'QA FCM aplikasi ditutup',
        startAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 63)),
        durationMinutes: 30,
      ),
    ),
  );
  await r.configure((await a.read()).items.single, true, 60);
  final c = HttpClient();
  try {
    final req = await c.postUrl(
      Uri.parse('http://127.0.0.1:8766/terminated-fixture'),
    );
    req.headers.contentType = ContentType.json;
    final body = jsonEncode({
      'project': 'mobile-app-3479f',
      'uid': auth.currentUser!.uid,
      'agendaId': id,
      'idToken': await auth.currentUser!.getIdToken(),
      'priorDeletedUids': oldDeleted,
    });
    req.contentLength = utf8.encode(body).length;
    req.write(body);
    final res = await req.close();
    await res.drain<void>();
    if (res.statusCode != 200) throw StateError('fixture_host_rejected');
  } finally {
    c.close(force: true);
  }
  runApp(app.RumaApp(session: session, firestore: db, notifications: push));
}
