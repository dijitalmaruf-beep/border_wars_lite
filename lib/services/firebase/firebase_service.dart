import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  const FirebaseService._();

  static bool _isAvailable = false;
  static Object? _initializationError;

  static bool get isAvailable => _isAvailable;
  static Object? get initializationError => _initializationError;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
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
}
