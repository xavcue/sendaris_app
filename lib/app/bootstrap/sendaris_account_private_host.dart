import 'package:flutter/material.dart';

import '../app.dart';
import '../session/account_private_content_host.dart';
import '../session/account_session_selection_controller.dart';
import '../session/firebase_account_contexts.dart';
import 'sendaris_account_dependencies.dart';

/// Comprueba la correspondencia entre una autorización,
/// la sesión Firebase y los servicios de datos.
///
/// No autentica usuarios ni concede permisos.
/// Es una segunda barrera antes de construir SendarisApp.
///
/// El permiso original debe haber sido concedido por
/// AccountSessionSelectionController.
abstract final class AccountPrivateContextPolicy {
  static bool permits({
    required String authorizedUserId,
    required String? contextUserId,
    required String selectedAppName,
    required String authAppName,
    required String firestoreAppName,
    required String otherAppName,
    required String projectId,
    required String otherProjectId,
    required String firebaseAppId,
    required String otherFirebaseAppId,
    required String apiKey,
    required String otherApiKey,
  }) {
    if (!_valid(authorizedUserId) ||
        !_valid(contextUserId) ||
        authorizedUserId != contextUserId) {
      return false;
    }

    if (!_valid(selectedAppName) ||
        !_valid(authAppName) ||
        !_valid(firestoreAppName) ||
        !_valid(otherAppName)) {
      return false;
    }

    // Autenticación y Firestore deben pertenecer
    // a la aplicación Firebase seleccionada.
    if (selectedAppName != authAppName || selectedAppName != firestoreAppName) {
      return false;
    }

    // No admitir dos contextos con el mismo nombre.
    if (selectedAppName == otherAppName) {
      return false;
    }

    // Los contextos corresponden al mismo proyecto
    // Firebase registrado. La independencia se
    // encuentra en sus sesiones locales.
    if (!_valid(projectId) ||
        !_valid(otherProjectId) ||
        projectId != otherProjectId) {
      return false;
    }

    if (!_valid(firebaseAppId) ||
        !_valid(otherFirebaseAppId) ||
        firebaseAppId != otherFirebaseAppId) {
      return false;
    }

    if (!_valid(apiKey) || !_valid(otherApiKey) || apiKey != otherApiKey) {
      return false;
    }

    return true;
  }

  static bool _valid(String? value) {
    return value != null && value.isNotEmpty && value.trim() == value;
  }
}

/// Construye el contenido privado de la cuenta seleccionada.
///
/// La selección efectiva se obtiene del controlador de
/// seguridad y nunca de un UID recibido desde el login.
///
/// Cuando no existe autorización, utiliza lockedBuilder.
/// La integración definitiva conectará ese constructor
/// con el login original de Sendaris.
///
/// Todos los repositorios se obtienen de una sola
/// instancia SendarisAccountDependencies.
///
/// No crea sesiones Firebase, no cambia cuentas y
/// no interactúa con Android Keystore.
///
/// La activación de App Check y las políticas de cierre
/// de sesión deben completarse en el componente raíz
/// antes de habilitar este host en producción.
final class SendarisAccountPrivateHost extends StatelessWidget {
  const SendarisAccountPrivateHost({
    required this.selection,
    required this.primary,
    required this.secondary,
    required this.lockedBuilder,
    super.key,
  });

  final AccountSessionSelectionController selection;
  final SendarisAccountDependencies primary;
  final SendarisAccountDependencies secondary;
  final WidgetBuilder lockedBuilder;

  bool _canMount({
    required SendarisAccountDependencies selected,
    required SendarisAccountDependencies other,
    required String userId,
  }) {
    return AccountPrivateContextPolicy.permits(
      authorizedUserId: userId,
      contextUserId: selected.currentUserId,
      selectedAppName: selected.applicationName,
      authAppName: selected.auth.app.name,
      firestoreAppName: selected.firestore.app.name,
      otherAppName: other.applicationName,
      projectId: selected.app.options.projectId,
      otherProjectId: other.app.options.projectId,
      firebaseAppId: selected.app.options.appId,
      otherFirebaseAppId: other.app.options.appId,
      apiKey: selected.app.options.apiKey,
      otherApiKey: other.app.options.apiKey,
    );
  }

  Widget _buildPrivateApplication(
    BuildContext context,
    FirebaseAccountSlot slot,
    String userId,
  ) {
    final selected = slot == FirebaseAccountSlot.primary ? primary : secondary;

    final other = slot == FirebaseAccountSlot.primary ? secondary : primary;

    // Una selección antigua o una identidad distinta
    // nunca debe construir pantallas privadas.
    if (!selection.value ||
        selection.selectedSlot != slot ||
        selection.selectedUserId != userId ||
        !_canMount(selected: selected, other: other, userId: userId)) {
      return Builder(builder: lockedBuilder);
    }

    // La aplicación se monta únicamente después
    // de que AccountPrivateContentHost haya
    // comprobado el permiso vigente.
    //
    // Su árbol completo será desmontado durante
    // una revocación o un cambio de cuenta.
    return SendarisApp(
      authRepository: selected.authRepository,
      privateAccessPermission: selection,
      trackingRepository: selected.trackingRepository,
      trackingProfileFactory: selected.trackingProfileFactory,
      behaviorRepository: selected.behaviorRepository,
      behaviorRecordFactory: selected.behaviorRecordFactory,
      sleepRepository: selected.sleepRepository,
      sleepRecordFactory: selected.sleepRecordFactory,
      feedingRepository: selected.feedingRepository,
      feedingRecordFactory: selected.feedingRecordFactory,
      socialInteractionRepository: selected.socialInteractionRepository,
      socialInteractionRecordFactory: selected.socialInteractionRecordFactory,
      dysregulationRepository: selected.dysregulationRepository,
      dysregulationRecordFactory: selected.dysregulationRecordFactory,
      durationRepository: selected.durationRepository,
      routineRepository: selected.routineRepository,
      routineFactory: selected.routineFactory,
      routineStatusRepository: selected.routineStatusRepository,
      routineStatusRecordFactory: selected.routineStatusRecordFactory,
      routineComplianceRepository: selected.routineComplianceRepository,
      atypicalSituationRepository: selected.atypicalSituationRepository,
      atypicalSituationRecordFactory: selected.atypicalSituationRecordFactory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AccountPrivateContentHost(
      selection: selection,
      lockedBuilder: lockedBuilder,
      privateBuilder: _buildPrivateApplication,
    );
  }
}
