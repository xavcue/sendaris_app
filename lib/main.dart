import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/data/services/firebase_auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = FirebaseAuthService(FirebaseAuth.instance);

  final authRepository = FirebaseAuthRepository(authService);

  runApp(SendarisApp(authRepository: authRepository));
}
