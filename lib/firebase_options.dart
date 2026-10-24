import 'package:firebase_core/firebase_core.dart';

// Public client configuration for the existing metcue09 Firebase project.
// Authentication and API authorization still require a valid user ID token.
const metCueWebOptions = FirebaseOptions(
  apiKey: 'AIzaSyBEcRA7IsRayBe6PwkLxXxLqOeaDgWa20U',
  appId: '1:1084823977938:web:51c6a4a15a82b9c508120b',
  messagingSenderId: '1084823977938',
  projectId: 'metcue09',
  authDomain: String.fromEnvironment(
    'ACQUENTA_AUTH_DOMAIN',
    defaultValue: 'metcue09.firebaseapp.com',
  ),
  storageBucket: 'metcue09.firebasestorage.app',
);

// Public iOS SDK identifiers for the same Acquenta Firebase project.
const metCueIosOptions = FirebaseOptions(
  apiKey: 'AIzaSyDeT_GTz_2g3Dk-TzJpbATMAmiFVpZZoj4',
  appId: '1:1084823977938:ios:fbaea7761ad0002f08120b',
  messagingSenderId: '1084823977938',
  projectId: 'metcue09',
  storageBucket: 'metcue09.firebasestorage.app',
  iosBundleId: 'com.aurunex.contactCardBuilder',
  iosClientId:
      '1084823977938-vd60fspkqnkls6be7vp8ajii3q6vaph1.apps.googleusercontent.com',
);
