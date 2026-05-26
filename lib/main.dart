import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/database/isar_database.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('pt_BR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LeWud4sAAAAAEzyrtnulPxqqnv3iqPLfwipZDct'),
    androidProvider: AndroidProvider.debug,
  );

  // Isar uses dart:ffi — not available on web.
  // On web, ProductRepository uses Firestore real-time streams instead.
  if (!kIsWeb) {
    await IsarDatabase.initialize();
  }

  runApp(const SoyYoApp());
}
