import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async => integrationDriver(
  responseDataCallback: (data) async {
    if (data != null) {
      await writeResponseData(
        data,
        destinationDirectory: 'docs/qa/savings',
        testOutputFilename: 'android-results',
      );
    }
  },
);
