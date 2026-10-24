import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      await File('docs/qa/finance/$name.png').writeAsBytes(image);
      return image.isNotEmpty;
    },
    responseDataCallback: (data) async {
      if (data != null) {
        data.remove('screenshots');
        await writeResponseData(
          data,
          destinationDirectory: 'docs/qa/finance',
          testOutputFilename: 'device-results',
        );
      }
    },
  );
}
