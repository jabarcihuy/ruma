import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data != null) {
        await writeResponseData(
          data,
          destinationDirectory: 'docs/qa/finance',
          testOutputFilename: 'cloud-results',
        );
      }
    },
  );
}
