import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCMcsDyRoiU7JAWnRiSERwUi9xLzjs-zAI',
    appId: '1:749466736785:web:0eb891261a87e7a762c730',
    messagingSenderId: '749466736785',
    projectId: 'turbocart-519ea',
    authDomain: 'turbocart-519ea.firebaseapp.com',
    storageBucket: 'turbocart-519ea.firebasestorage.app',
    measurementId: 'G-Y7XXK2TXS5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMcsDyRoiU7JAWnRiSERwUi9xLzjs-zAI',
    appId: '1:749466736785:android:dummy',
    messagingSenderId: '749466736785',
    projectId: 'turbocart-519ea',
    storageBucket: 'turbocart-519ea.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCMcsDyRoiU7JAWnRiSERwUi9xLzjs-zAI',
    appId: '1:749466736785:ios:dummy',
    messagingSenderId: '749466736785',
    projectId: 'turbocart-519ea',
    storageBucket: 'turbocart-519ea.firebasestorage.app',
    iosBundleId: 'com.turbocart.delivery',
  );
}
