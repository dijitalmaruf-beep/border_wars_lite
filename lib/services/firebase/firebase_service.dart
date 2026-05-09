import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseService {
  const FirebaseService._();

  static bool _isAvailable = false;
  static Object? _initializationError;

  static bool get isAvailable => _isAvailable;
  static Object? get initializationError => _initializationError;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isAvailable = true;
      _initializationError = null;
    } catch (error) {
      _isAvailable = false;
      _initializationError = error;
    }
  }

  static FirebaseFirestore get firestore {
    if (!_isAvailable) {
      throw StateError(
        'Firebase is not configured for this build. '
        'Add Firebase options/google-services files before using online play.',
      );
    }
    return FirebaseFirestore.instance;
  }

  static FirebaseAuth get auth {
    if (!_isAvailable) {
      throw StateError(
        'Firebase is not configured for this build. '
        'Add Firebase options/google-services files before using online play.',
      );
    }
    return FirebaseAuth.instance;
  }

  static Future<String> ensureSignedInAnonymously() async {
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      return currentUser.uid;
    }
    final UserCredential credential;
    try {
      credential = await auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-allowed' ||
          error.code == 'admin-restricted-operation' ||
          error.code == 'configuration-not-found') {
        throw StateError(
          'Anonymous Firebase Auth is not enabled for this project yet. '
          'Enable Authentication > Sign-in method > Anonymous in Firebase Console.',
        );
      }
      rethrow;
    }
    final uid = credential.user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Anonymous Firebase sign-in did not return a user id.');
    }
    return uid;
  }
}
