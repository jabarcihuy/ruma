import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final dir = Directory('docs/qa/agenda');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png').writeAsBytes(image);
      return image.isNotEmpty;
    },
    responseDataCallback: (data) async {
      if (data != null) {
        data.remove('screenshots');
        await writeResponseData(
          data,
          destinationDirectory: 'docs/qa/agenda',
          testOutputFilename: 'device-results',
        );
      }
    },
  );
}
