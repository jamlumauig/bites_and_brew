import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/app.dart';
export 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? firebaseInitializationError;
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      await Firebase.initializeApp();
    }
  } catch (error) {
    firebaseInitializationError = error.toString();
  }
  runApp(
    CoffeePosApp(firebaseInitializationError: firebaseInitializationError),
  );
}
