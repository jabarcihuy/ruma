import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/reminders.dart';
import 'package:ruma/data/push_notifications.dart';
import 'package:ruma/features/notifications/notification_pages.dart';

import 'assistant_test.dart' as fixtures;

class ReminderFake extends Fake implements ReminderRepository {
  int saves = 0;
  @override
  Future<Map<String, dynamic>?> read(String id) async => null;
  @override
  Future<void> configure(AgendaItem item, bool enabled, int lead) async {
    saves++;
  }
}

class PushFake extends ChangeNotifier implements RumaNotifications {
  @override
  bool get enabled => true;
  @override
  bool get allowed => true;
  @override
  bool get busy => false;
  @override
  String get error => '';
  @override
  Future<void> openSettings() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'reminder controls fit narrow 200 percent text and remain editable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ReminderFake(), push = PushFake();
      await tester.pumpWidget(
        fixtures.app(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: ReminderPage(
              item: AgendaItem(
                id: 'a',
                version: 1,
                input: AgendaInput(
                  title: 'Presentasi kampus',
                  startAtUtc: DateTime.now().toUtc().add(
                    const Duration(hours: 2),
                  ),
                ),
              ),
              repository: repo,
              notifications: push,
            ),
          ),
          form: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.byKey(const ValueKey('reminder-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(save, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      push.dispose();
    },
  );
}
