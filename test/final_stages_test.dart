import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/data/agenda.dart';
import 'package:ruma/data/recurrence.dart';
import 'package:ruma/data/user_settings.dart';
import 'package:ruma/features/profile/personal_settings_page.dart';

import 'assistant_test.dart' as fixture;

final start = DateTime.utc(2026, 11, 2, 2);
AgendaItem series({Map<String, dynamic>? pattern, String status = 'planned'}) =>
    AgendaItem(
      id: 'series',
      version: 3,
      input: AgendaInput(
        title: 'Kuliah',
        kind: 'class',
        startAtUtc: start,
        status: status,
        recurrence: pattern ?? weeklyPattern(start),
      ),
    );

class SettingsFake extends ChangeNotifier implements UserSettingsStore {
  @override
  UserSettings value = const UserSettings();
  @override
  bool ready = true, busy = false;
  @override
  String error = '';
  @override
  Future<bool> save(UserSettings next) async {
    if (next.validate() != null) {
      error = next.validate()!;
      notifyListeners();
      return false;
    }
    value = next;
    notifyListeners();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test(
    'weekly patterns remain bounded and stable for arbitrary calendar windows',
    () {
      final s = series(),
          items = expandWeekly(
            [series()],
            DateTime.utc(2026, 11, 1),
            DateTime.utc(2026, 11, 18),
          );
      expect(items.map((a) => a.id), [
        'series__2026-11-02',
        'series__2026-11-09',
        'series__2026-11-16',
      ]);
      expect(
        items.every((a) => a.input.recurrence == null && a.version == 3),
        true,
      );
      expect(weeklyMeeting(s, '2026-11-03'), isNull);
      expect(occurrenceKey(items[1].id), ('series', '2026-11-09'));
      expect(
        expandWeekly([s], DateTime.utc(2030, 1, 1), DateTime.utc(2030, 1, 8)),
        isNotEmpty,
      );
      expect(
        () => expandWeekly([s], DateTime.utc(2026), DateTime.utc(2027)),
        throwsA(isA<AgendaFailure>()),
      );
    },
  );
  test(
    'moved-in exception is found and never skips an earlier regular meeting',
    () {
      final r = weeklyPattern(start);
      r['exceptions'] = jsonEncode({
        '2026-11-09': AgendaInput(
          title: 'Pindah',
          kind: 'class',
          startAtUtc: DateTime.utc(2026, 12, 1, 2),
        ).toJson(),
      });
      final s = series(pattern: r),
          moved = expandWeekly(
            [s],
            DateTime.utc(2026, 12, 1),
            DateTime.utc(2026, 12, 2),
          );
      expect(moved.single.id, 'series__2026-11-09');
      expect(moved.single.input.title, 'Pindah');
      expect(
        nextWeekly(s, DateTime.utc(2026, 11, 8))!.id,
        'series__2026-11-16',
      );
    },
  );
  test('cancel one, future shift, series end and global cancellation preserve identity', () {
    final r = weeklyPattern(start, until: '2026-11-23');
    r['changes'] = jsonEncode({
      '2026-11-09': AgendaInput(
        title: 'Jam baru',
        kind: 'class',
        startAtUtc: DateTime.utc(2026, 11, 10, 3),
      ).toJson(),
    });
    r['exceptions'] = jsonEncode({
      '2026-11-16': AgendaInput(
        title: 'Libur',
        kind: 'class',
        startAtUtc: DateTime.utc(2026, 11, 17, 3),
        status: 'cancelled',
      ).toJson(),
    });
    final s = series(pattern: r);
    expect(weeklyMeeting(s, '2026-11-02')!.input.title, 'Kuliah');
    expect(
      weeklyMeeting(s, '2026-11-09')!.input.startAtUtc,
      DateTime.utc(2026, 11, 10, 3),
    );
    expect(weeklyMeeting(s, '2026-11-16')!.input.status, 'cancelled');
    expect(weeklyMeeting(s, '2026-11-30'), isNull);
    expect(nextWeekly(s, DateTime.utc(2026, 11, 11))!.id, 'series__2026-11-23');
    expect(
      nextWeekly(
        series(pattern: r, status: 'cancelled'),
        DateTime.utc(2026, 11, 1),
      ),
      isNull,
    );
    expect(
      weeklyMeeting(
        series(pattern: r, status: 'cancelled'),
        '2026-11-09',
      )!.input.status,
      'cancelled',
    );
  });
  test(
    'corrupt recurrence, illegal override date and payload size fail closed',
    () {
      for (final patch in [
        {'exceptions': '[]'},
        {'originDate': '2026-02-30'},
        {'untilLocalDate': '2026-01-01'},
        {'changes': 'x' * 60001},
        {
          'exceptions': jsonEncode({
            '2026-11-03': AgendaInput(
              title: 'Fake',
              kind: 'class',
              startAtUtc: start,
            ).toJson(),
          }),
        },
      ]) {
        final s = series(pattern: {...weeklyPattern(start), ...patch});
        expect(s.input.validate(), isNotNull);
        expect(
          () => expandWeekly(
            [s],
            DateTime.utc(2026, 11, 1),
            DateTime.utc(2026, 11, 10),
          ),
          throwsA(anything),
        );
      }
    },
  );
  test(
    'personal settings validate and explicit duration wins over default',
    () {
      const s = UserSettings(
        personalize: true,
        duration: 45,
        from: 600,
        to: 720,
      );
      expect(s.validate(), isNull);
      expect(UserSettings.decode(s.toJson()).duration, 45);
      expect(preferredDuration(s, 'Besok belajar', 20), 45);
      expect(preferredDuration(s, 'Belajar 20 menit', 20), 20);
      expect(preferredDuration(s, 'Belajar satu jam', 60), 60);
      expect(preferredDuration(s, 'Study 20 minutes', 20), 20);
      expect(preferredDuration(s, 'Belajar 20menit', 20), 20);
      expect(preferredDuration(const UserSettings(), 'Belajar', 20), 20);
      for (final s in [
        const UserSettings(duration: 0),
        const UserSettings(from: 600, to: 599),
        UserSettings(bio: 'x' * 161),
        const UserSettings(avatar: 'url'),
      ]) {
        expect(s.validate(), isNotNull);
      }
    },
  );
  testWidgets(
    'profile and preferences remain editable at narrow 200 percent text',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final s = SettingsFake();
      addTearDown(s.dispose);
      for (final pref in [false, true]) {
        await t.pumpWidget(fixture.app(const SizedBox()));
        await t.pumpAndSettle();
        t
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PersonalSettingsPage(store: s, preferences: pref),
              ),
            );
        await t.pumpAndSettle();
        if (!pref) {
          await t.enterText(
            find.byKey(const ValueKey('profile-study')),
            'Teknik Informatika',
          );
        } else {
          await t.ensureVisible(
            find.byKey(const ValueKey('preferred-duration')),
          );
          await t.enterText(
            find.byKey(const ValueKey('preferred-duration')),
            '45',
          );
        }
        await t.pumpAndSettle();
        await Scrollable.ensureVisible(
          t.element(find.byKey(const ValueKey('personal-settings-save'))),
          alignment: 0.5,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.tap(find.byKey(const ValueKey('personal-settings-save')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(
          pref ? s.value.duration == 45 : s.value.study == 'Teknik Informatika',
          isTrue,
        );
      }
    },
  );
}
