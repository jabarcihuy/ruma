import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data != null) {
        data.remove('screenshots');
        await writeResponseData(
          data,
          destinationDirectory:
              Platform.environment['RUMA_QA_DIR'] ?? 'docs/qa/ui-polish',
          testOutputFilename:
              Platform.environment['RUMA_RESULT_NAME'] ?? 'device-results',
        );
      }
    },
  );
}
