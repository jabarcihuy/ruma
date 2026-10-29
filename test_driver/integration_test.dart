import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['RUMA_QA_DIR'] ?? 'docs/qa/flutter',
  );
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, image, [args]) async {
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
          destinationDirectory: directory.path,
          testOutputFilename:
              Platform.environment['RUMA_RESULT_NAME'] ??
              (data.containsKey('production')
                  ? 'auth-production-results'
                  : 'auth-emulator-results'),
        );
      }
    },
  );
}
