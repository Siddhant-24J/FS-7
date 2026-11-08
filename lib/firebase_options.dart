import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderAndroidKey123456789',
    appId: '1:123456789012:android:abcdef0123456789',
    messagingSenderId: '123456789012',
    projectId: 'fs7-gym-app',
    storageBucket: 'fs7-gym-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholderIOSKey123456789',
    appId: '1:123456789012:ios:abcdef0123456789',
    messagingSenderId: '123456789012',
    projectId: 'fs7-gym-app',
    storageBucket: 'fs7-gym-app.appspot.com',
    iosBundleId: 'com.fs7.gym',
  );
}

