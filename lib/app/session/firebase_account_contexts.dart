import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Ubicación de una sesión dentro de la instalación.
enum FirebaseAccountSlot { primary, secondary }

/// Resultado de buscar una identidad entre dos sesiones.
///
/// Ninguno de estos resultados concede acceso privado.
enum FirebaseAccountMatch { primary, secondary, notFound, conflict, invalid }

/// Determina en qué contexto se encuentra una identidad.
///
/// No inicia sesiones, no modifica Firebase y no autoriza
/// el acceso a documentos privados.
///
/// Si ambas instancias contienen el mismo UID, se rechaza
/// la selección ambigua en lugar de elegir arbitrariamente
/// una de ellas.
abstract final class FirebaseAccountIdentityPolicy {
  static FirebaseAccountMatch locate({
    required String expectedUserId,
    required String? primaryUserId,
    required String? secondaryUserId,
  }) {
    if (!_validUserId(expectedUserId)) {
      return FirebaseAccountMatch.invalid;
    }

    if (primaryUserId != null && !_validUserId(primaryUserId)) {
      return FirebaseAccountMatch.invalid;
    }

    if (secondaryUserId != null && !_validUserId(secondaryUserId)) {
      return FirebaseAccountMatch.invalid;
    }

    final matchesPrimary = primaryUserId == expectedUserId;
    final matchesSecondary = secondaryUserId == expectedUserId;

    if (matchesPrimary && matchesSecondary) {
      return FirebaseAccountMatch.conflict;
    }

    if (matchesPrimary) {
      return FirebaseAccountMatch.primary;
    }

    if (matchesSecondary) {
      return FirebaseAccountMatch.secondary;
    }

    return FirebaseAccountMatch.notFound;
  }

  static bool _validUserId(String value) {
    return value.isNotEmpty && value.trim() == value;
  }
}

/// Agrupa los servicios Firebase de una misma aplicación.
///
/// Authentication y Firestore deben pertenecer exactamente
/// a la misma instancia FirebaseApp.
///
/// No se permite crear un contexto mezclando servicios
/// procedentes de aplicaciones diferentes.
final class FirebaseAccountContext {
  FirebaseAccountContext._({
    required this.app,
    required this.auth,
    required this.firestore,
  }) {
    if (auth.app.name != app.name || firestore.app.name != app.name) {
      throw StateError(
        'Authentication y Firestore deben pertenecer '
        'a la misma aplicación Firebase.',
      );
    }
  }

  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  String? get currentUserId => auth.currentUser?.uid;

  String get applicationName => app.name;

  bool get hasAuthenticatedUser => currentUserId != null;
}

/// Mantiene separados los servicios Firebase de dos cuentas.
///
/// Este componente es exclusivamente la infraestructura
/// de contextos. Todavía no selecciona qué cuenta puede
/// mostrar datos privados.
///
/// La selección definitiva requerirá:
/// - autorización biométrica o convencional válida;
/// - verificación de identidad y UID;
/// - validación de sesión Firebase;
/// - desmontaje seguro del contexto anterior;
/// - protección de las suscripciones a Firestore.
///
/// Ningún constructor inicia sesión ni cierra sesiones.
final class FirebaseAccountContextManager {
  FirebaseAccountContextManager._({
    required this.primary,
    required this.secondary,
  });

  /// Nombre estable para conservar la sesión secundaria
  /// entre reinicios de la aplicación.
  ///
  /// No modificarlo después de desplegar el mecanismo
  /// sin preparar una migración de persistencia.
  static const secondaryApplicationName = 'sendaris_secondary_account';

  final FirebaseAccountContext primary;
  final FirebaseAccountContext secondary;

  /// Crea o recupera las aplicaciones Firebase existentes.
  ///
  /// Requiere que Firebase.initializeApp se haya ejecutado
  /// previamente para la aplicación predeterminada.
  ///
  /// No lee Firestore, no solicita credenciales y no
  /// cambia el contexto activo de Sendaris.
  static Future<FirebaseAccountContextManager> initialize() async {
    final primaryApp = Firebase.app();

    if (primaryApp.name == secondaryApplicationName) {
      throw StateError(
        'El contexto secundario no puede ser '
        'la aplicación predeterminada.',
      );
    }

    final existingSecondaryApps = Firebase.apps.where(
      (app) => app.name == secondaryApplicationName,
    );

    final FirebaseApp secondaryApp;

    if (existingSecondaryApps.isNotEmpty) {
      secondaryApp = existingSecondaryApps.first;
    } else {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryApplicationName,
        options: primaryApp.options,
      );
    }

    // Ambas aplicaciones deben apuntar al mismo proyecto
    // y a la misma aplicación Firebase registrada.
    //
    // Lo que se separa son las sesiones locales, no
    // los proyectos, colecciones ni bases de datos.
    if (secondaryApp.name == primaryApp.name ||
        secondaryApp.options.projectId != primaryApp.options.projectId ||
        secondaryApp.options.appId != primaryApp.options.appId ||
        secondaryApp.options.apiKey != primaryApp.options.apiKey) {
      throw StateError(
        'Las aplicaciones Firebase no tienen '
        'una configuración compatible.',
      );
    }

    FirebaseAccountContext createContext(FirebaseApp app) {
      return FirebaseAccountContext._(
        app: app,
        auth: FirebaseAuth.instanceFor(app: app),
        firestore: FirebaseFirestore.instanceFor(app: app),
      );
    }

    final primaryContext = createContext(primaryApp);
    final secondaryContext = createContext(secondaryApp);

    if (primaryContext.applicationName == secondaryContext.applicationName) {
      throw StateError('Los contextos Firebase no son independientes.');
    }

    return FirebaseAccountContextManager._(
      primary: primaryContext,
      secondary: secondaryContext,
    );
  }

  /// Identifica la ubicación actual de un UID.
  ///
  /// Este método solo inspecciona las identidades locales.
  /// Su resultado no demuestra que Firebase haya validado
  /// recientemente una sesión ni que se haya verificado
  /// la biometría.
  FirebaseAccountMatch locateUserId(String expectedUserId) {
    return FirebaseAccountIdentityPolicy.locate(
      expectedUserId: expectedUserId,
      primaryUserId: primary.currentUserId,
      secondaryUserId: secondary.currentUserId,
    );
  }
}
