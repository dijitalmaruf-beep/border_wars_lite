import 'package:flutter/material.dart';

import 'app.dart';
import 'services/firebase/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const BorderWarsLiteApp());
}
