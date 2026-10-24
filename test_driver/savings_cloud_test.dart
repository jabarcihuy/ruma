import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data != null) {
        await writeResponseData(
          data,
          destinationDirectory:
              Platform.environment['RUMA_WISHLIST_TESTS'] == '1'
              ? 'docs/qa/wishlist'
              : 'docs/qa/savings-ui',
          testOutputFilename: 'cloud-results',
        );
      }
    },
  );
}
