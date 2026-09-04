import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/data/services/firebase_auth_service.dart';
import 'features/tracking/data/repositories/firebase_tracking_repository.dart';
import 'features/tracking/data/services/firestore_tracking_service.dart';
import 'features/tracking/data/services/uuid_anonymous_id_generator.dart';
import 'features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  firestore.settings = const Settings(persistenceEnabled: true);

  final authService = FirebaseAuthService(firebaseAuth);
  final authRepository = FirebaseAuthRepository(authService);

  final trackingService = FirestoreTrackingService(firestore, firebaseAuth);

  final trackingRepository = FirebaseTrackingRepository(trackingService);

  final trackingProfileFactory = AnonymousTrackingProfileFactory(
    UuidAnonymousIdGenerator(),
  );

  runApp(
    SendarisApp(
      authRepository: authRepository,
      trackingRepository: trackingRepository,
      trackingProfileFactory: trackingProfileFactory,
    ),
  );
}
