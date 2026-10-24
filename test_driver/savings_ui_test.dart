import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

final evidence = Platform.environment['RUMA_WISHLIST_TESTS'] == '1'
    ? 'docs/qa/wishlist'
    : 'docs/qa/savings-ui';

Future<void> main() async => integrationDriver(
  onScreenshot: (name, image, [args]) async {
    await File('$evidence/$name.png').writeAsBytes(image);
    return image.isNotEmpty;
  },
  responseDataCallback: (data) async {
    if (data != null) {
      data.remove('screenshots');
      await writeResponseData(
        data,
        destinationDirectory: evidence,
        testOutputFilename: 'android-results',
      );
    }
  },
);
