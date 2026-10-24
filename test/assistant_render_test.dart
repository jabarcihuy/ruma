import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruma/app/theme.dart';
import 'package:ruma/features/assistant/assistant_page.dart';

import 'assistant_test.dart' as fixtures;

void main() {
  testWidgets(
    'render assistant and approved review with local Manrope assets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final loader = FontLoader('Manrope')
        ..addFont(
          rootBundle.load('design/assets/ruma/fonts/Manrope-Variable.ttf'),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final s = fixtures.makeStore(
        fixtures.DraftRepoFake(),
        fixtures.ServiceFake(),
      )..consent = true;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: rumaTheme(),
            locale: const Locale('id'),
            supportedLocales: const [Locale('id')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              appBar: AppBar(title: const Text('Asisten Ruma')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AssistantPage(store: s, onTab: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> render(String name) async {
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final pixels =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final png = await pixels.toByteData(format: ui.ImageByteFormat.png);
          const directory = String.fromEnvironment(
            'RUMA_RENDER_DIR',
            defaultValue: 'docs/qa/assistant',
          );
          await Directory(directory).create(recursive: true);
          await File('$directory/$name.png')
              .writeAsBytes(png!.buffer.asUint8List());
          pixels.dispose();
        });
      }

      await render('render-chat');
      await tester.runAsync(() => s.send(fixtures.source));
      await tester.pumpAndSettle();
      await render('render-review');
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      s.agenda.dispose();
      s.finance.dispose();
    },
  );
}
