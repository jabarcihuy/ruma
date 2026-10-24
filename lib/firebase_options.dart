import 'package:firebase_core/firebase_core.dart';

abstract final class RumaFirebaseOptions {
  static const useEmulator = bool.fromEnvironment('AUTH_EMULATOR');
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDD6TuRjVRL8p1TYsWpsSkSwgr5jbm7NeU',
    appId: '1:18934621879:android:8f7ae40b378ec1dce08f32',
    messagingSenderId: '18934621879',
    projectId: 'mobile-app-3479f',
    storageBucket: 'mobile-app-3479f.firebasestorage.app',
  );
  static const emulator = FirebaseOptions(
    apiKey: 'demo-ruma-public-key',
    appId: '1:1234567890:android:0123456789abcdef',
    messagingSenderId: '1234567890',
    projectId: 'demo-ruma',
  );
}
