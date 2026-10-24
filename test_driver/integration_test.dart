import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, image, [args]) async {
      final directory = Directory('docs/qa/flutter');
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(image);
      return image.isNotEmpty;
    },
    responseDataCallback: (data) async {
      if (data != null) {
        // Screenshots already exist separately; do not duplicate binary data in JSON.
        data.remove('screenshots');
        await writeResponseData(
          data,
          destinationDirectory: 'docs/qa/flutter',
          testOutputFilename: data.containsKey('production')
              ? 'auth-production-results'
              : 'auth-emulator-results',
        );
      }
    },
  );
}
