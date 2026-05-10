import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase options are configured for Android, iOS, and Web only.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCWCoTmn7Y5-CMPspTUuWo5jnx63npnaDo',
    appId: '1:776853906650:web:185edda213c7b9e900b1e3',
    messagingSenderId: '776853906650',
    projectId: 'border-wars-lite',
    authDomain: 'border-wars-lite.firebaseapp.com',
    storageBucket: 'border-wars-lite.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNo-Xi0ayN9vryqE-UIf_0AjfJqOt7WyY',
    appId: '1:776853906650:android:444e6a257a11d7ca00b1e3',
    messagingSenderId: '776853906650',
    projectId: 'border-wars-lite',
    storageBucket: 'border-wars-lite.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBn3NbACtvEl0Ur2M1KBB1bk2y1uMT7yjM',
    appId: '1:776853906650:ios:293462905649436100b1e3',
    messagingSenderId: '776853906650',
    projectId: 'border-wars-lite',
    storageBucket: 'border-wars-lite.firebasestorage.app',
    iosBundleId: 'com.marleklabs.chromaconquest',
  );
}
