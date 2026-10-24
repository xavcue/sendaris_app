import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/session/acknowledged_session_timeout_store.dart';
import 'app/session/biometric_vault_gateway.dart';
import 'app/session/firebase_account_contexts.dart';
import 'app/session/sendaris_dual_account_root.dart';
import 'app/session/session_timeout_store.dart';
import 'app/theme/sendaris_theme_preference.dart';
import 'firebase_options.dart';

/// Punto de entrada principal de Sendaris.
///
/// La arquitectura de dos cuentas es ahora el funcionamiento
/// habitual de la aplicacion.
///
/// No requiere SENDARIS_DUAL_ACCOUNT_PREVIEW ni otras
/// opciones --dart-define para habilitar AUTH-03.
///
/// Conserva:
/// - Cuenta A vinculada a biometria.
/// - Cuenta B convencional.
/// - Restauracion independiente de sesiones.
/// - Android Keystore.
/// - Limites temporales.
/// - Revocacion por cierre manual.
/// - Registros, rutinas e indicadores.
/// - Tema Claro, Oscuro o Sistema.
///
/// Las autorizaciones privadas siguen siendo responsabilidad
/// de SendarisDualAccountRoot y sus coordinadores.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Recuperar la apariencia elegida en el dispositivo.
  //
  // Es independiente de la identidad Firebase
  // que se restaure durante el arranque.
  await SendarisThemePreference.initialize();

  // Inicializar Firebase antes de utilizar sus servicios.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Utilizar el proveedor Debug solamente durante
  // el desarrollo.
  //
  // Las compilaciones release utilizan Play Integrity.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  // Inicializar los contextos Firebase independientes
  // utilizados por la arquitectura dual de Sendaris.
  //
  // El mismo flujo se utiliza en debug y release.
  final contexts = await FirebaseAccountContextManager.initialize();

  // El segundo contexto necesita su propia instancia
  // de App Check y el proveedor correspondiente al
  // tipo de compilacion.
  await FirebaseAppCheck.instanceFor(app: contexts.secondary.app).activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  // Conservar la persistencia de Firestore existente.
  contexts.primary.firestore.settings = const Settings(
    persistenceEnabled: true,
  );

  contexts.secondary.firestore.settings = const Settings(
    persistenceEnabled: true,
  );

  // Almacenamiento temporal usado por el guard
  // convencional. La raiz dual mantiene el diario
  // independiente de sesiones A y B.
  final sessionStore = AcknowledgedSessionTimeoutStore(
    delegate: PreferencesSessionTimeoutStore(),
  );

  // Adaptador nativo de Android Keystore.
  //
  // No altera las vinculaciones biometricas existentes.
  final biometricGateway = AndroidBiometricVaultGateway();

  // Arquitectura oficial de Sendaris.
  //
  // Ya no existe un camino alternativo condicionado
  // por SENDARIS_DUAL_ACCOUNT_PREVIEW.
  runApp(
    SendarisDualAccountRoot(
      contexts: contexts,
      store: sessionStore,
      gateway: biometricGateway,
    ),
  );
}
