import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../bootstrap/sendaris_account_dependencies.dart';
import '../bootstrap/sendaris_account_private_host.dart';
import '../theme/app_theme.dart';
import '../theme/sendaris_theme_preference.dart';
import '../widgets/sendaris_animated_launch.dart';
import 'account_active_session_checkpoint.dart';
import 'account_biometric_access_coordinator.dart';
import 'account_biometric_settings_controller.dart';
import 'account_conventional_access_coordinator.dart';
import 'account_conventional_session_persistence_sync.dart';
import 'account_conventional_session_restore_coordinator.dart';
import 'account_duplicate_session_release.dart';
import 'account_linked_continuity_revocation.dart';
import 'account_linked_session_continuity_assessment.dart';
import 'account_linked_session_persistence_sync.dart';
import 'account_linked_session_recovery_coordinator.dart';
import 'account_linked_session_recovery_policy.dart';
import 'account_linked_session_recovery_screen.dart';
import 'account_linked_session_restore_coordinator.dart';
import 'account_scoped_session_timeout_store.dart';
import 'account_session_exit_coordinator.dart';
import 'account_session_persistence_journal.dart';
import 'account_session_selection_controller.dart';
import 'account_session_startup_assessment.dart';
import 'acknowledged_session_timeout_store.dart';
import 'android_linked_continuity_gateway.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';
import 'firebase_account_contexts.dart';
import 'linked_account_session_lifecycle_controller.dart';
import 'session_timeout_guard.dart';
import 'session_timeout_policy.dart';

/// Distribucion de sesiones Firebase.
///
/// El contexto vinculado conserva A y el convencional
/// permite utilizar sucesivamente otras cuentas.
final class SendarisAccountSessionConfiguration {
  const SendarisAccountSessionConfiguration({
    required this.conventionalSlot,
    required this.linkedSlot,
  });

  final FirebaseAccountSlot conventionalSlot;
  final FirebaseAccountSlot? linkedSlot;
}

/// Raiz de los dos contextos de Sendaris.
///
/// - Restaura A solo tras verificar Firebase, Keystore y vigencia.
/// - Preserva la fecha original de la sesion de A.
/// - Evalua B antes de desconectarla al arrancar.
/// - Confirma su identidad y vigencia con Firebase.
/// - Entrega el registro convencional a SessionTimeoutGuard.
/// - No monta datos privados antes de confirmar el acceso.
/// - Mantiene A bloqueada si falla la continuidad.
/// - Conserva los cierres manuales independientes.
/// - Utiliza el logo animado durante la preparacion.
/// - Respeta la apariencia seleccionada en Sendaris.
///
/// Un registro guardado nunca constituye por si solo
/// una autorizacion de acceso.
final class SendarisDualAccountRoot extends StatefulWidget {
  const SendarisDualAccountRoot({
    required this.contexts,
    required this.store,
    required this.gateway,
    super.key,
  });

  final FirebaseAccountContextManager contexts;
  final AcknowledgedSessionTimeoutStore store;
  final BiometricVaultGateway gateway;

  @override
  State<SendarisDualAccountRoot> createState() =>
      _SendarisDualAccountRootState();
}

final class _SendarisDualAccountRootState extends State<SendarisDualAccountRoot>
    with WidgetsBindingObserver {
  late final SendarisAccountDependencies _primary;
  late final SendarisAccountDependencies _secondary;

  late final AccountBiometricAccessCoordinator _biometric;
  late final AccountLinkedSessionRecoveryCoordinator _linkedRecovery;
  late final LinkedAccountSessionLifecycleController _linkedLifecycle;

  late final AccountSessionPersistenceJournal _sessionJournal;
  late final AccountLinkedSessionPersistenceSync _linkedSync;
  late final AccountLinkedContinuityRevocation _linkedRevocation;

  AccountConventionalSessionPersistenceSync? _conventionalSync;

  AccountConventionalAccessCoordinator? _conventional;
  AccountDuplicateSessionRelease? _duplicateRelease;
  AccountSessionExitCoordinator? _sessionExit;
  AccountBiometricSettingsController? _settingsController;

  SendarisAccountSessionConfiguration? _configuration;

  /// Contexto de A durante la preparacion.
  ///
  /// El sincronizador necesita esta referencia antes de
  /// publicar la configuracion definitiva. No representa
  /// una autorizacion privada.
  FirebaseAccountSlot? _preparingLinkedSlot;

  /// Registro admitido por el evaluador de arranque.
  ///
  /// Solo se entrega al SessionTimeoutGuard del
  /// contexto convencional verificado.
  SessionTimeoutRecord? _initialConventionalRecord;

  FirebaseAccountSlot? _observedAuthorizedSlot;
  String? _observedAuthorizedUserId;

  int _linkedAuthorizationRevision = 0;
  bool _linkedRestorationUnavailable = false;

  bool _ready = false;
  bool _blocked = false;
  bool _disposed = false;
  bool _bindingTransitionRunning = false;
  bool _recoveryBusy = false;

  String? _recoveringLinkedUid;
  int _preparationRevision = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _primary = SendarisAccountDependencies.forContext(widget.contexts.primary);

    _secondary = SendarisAccountDependencies.forContext(
      widget.contexts.secondary,
    );

    _biometric = AccountBiometricAccessCoordinator.forFirebase(
      contexts: widget.contexts,
      gateway: widget.gateway,
    );

    _linkedRecovery = AccountLinkedSessionRecoveryCoordinator(
      linkedIdentity: FirebaseAccountIdentitySource(
        widget.contexts.primary.auth,
      ),
      otherIdentity: FirebaseAccountIdentitySource(
        widget.contexts.secondary.auth,
      ),
      linkedSession: _biometric.primarySession,
      gateway: widget.gateway,
    );

    _linkedLifecycle = LinkedAccountSessionLifecycleController(
      selection: _biometric.selection,
      linkedSlot: null,
    );

    final storage = SharedPreferencesAccountSessionStorage();

    _sessionJournal = AccountSessionPersistenceJournal(
      selection: _biometric.selection,
      primary: AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.primary,
        storage: storage,
      ),
      secondary: AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.secondary,
        storage: storage,
      ),
      active: AccountActiveSessionCheckpointStore(storage: storage),
    );

    _linkedSync = AccountLinkedSessionPersistenceSync(
      selection: _biometric.selection,
      lifecycle: _linkedLifecycle,
      journal: _sessionJournal,
      linkedSlot: () => _configuration?.linkedSlot ?? _preparingLinkedSlot,
    );

    final continuityGateway = AndroidLinkedContinuityGateway();

    _linkedRevocation = AccountLinkedContinuityRevocation(
      drainLinkedWrites: _linkedSync.waitForIdle,
      revokeNative: continuityGateway.revoke,
      revokeCheckpoint: (slot, userId) =>
          _sessionJournal.revoke(slot: slot, userId: userId),
    );

    _biometric.selection.addListener(_observeAuthorizedSelection);

    unawaited(_prepare());
  }

  SendarisAccountDependencies _dependenciesFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => _primary,
      FirebaseAccountSlot.secondary => _secondary,
    };
  }

  FirebaseAccountSlot _otherSlot(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => FirebaseAccountSlot.secondary,
      FirebaseAccountSlot.secondary => FirebaseAccountSlot.primary,
    };
  }

  Future<void> _waitForFirebaseAuthentication() async {
    await Future.wait([
      widget.contexts.primary.auth.authStateChanges().first,
      widget.contexts.secondary.auth.authStateChanges().first,
    ]);
  }

  /// Desconecta un contexto convencional cuando
  /// no ha sido autorizado para restauracion.
  ///
  /// Nunca debe llamarse sobre A vinculada.
  Future<void> _prepareConventionalContext(
    SendarisAccountDependencies services,
  ) async {
    if (services.authRepository.isAuthenticated) {
      await services.authRepository.signOut();
    }

    if (services.currentUserId != null) {
      throw StateError('La sesion convencional no se desconecto.');
    }
  }

  /// Observa escrituras confirmadas por el guard B.
  ///
  /// No crea un segundo temporizador convencional.
  void _installConventionalPersistenceSync() {
    _conventionalSync?.dispose();
    _conventionalSync = null;

    if (_disposed || !_ready || _blocked) {
      return;
    }

    final configuration = _configuration;

    if (configuration == null) {
      return;
    }

    _conventionalSync = AccountConventionalSessionPersistenceSync(
      selection: _biometric.selection,
      source: widget.store,
      journal: _sessionJournal,
      conventionalSlot: () =>
          _configuration?.conventionalSlot ?? configuration.conventionalSlot,
      onCriticalFailure: () {
        if (!_disposed && !_blocked) {
          _failClosed();
        }
      },
    );
  }

  /// Espera las escrituras de B antes de cambiar
  /// el rol convencional.
  Future<void> _stopConventionalPersistenceSync() async {
    final sync = _conventionalSync;

    if (sync == null) {
      return;
    }

    await sync.waitForIdle();

    sync.dispose();

    if (identical(_conventionalSync, sync)) {
      _conventionalSync = null;
    }
  }

  void _observeAuthorizedSelection() {
    if (_disposed) {
      return;
    }

    final selection = _biometric.selection;
    final slot = selection.selectedSlot;
    final userId = selection.selectedUserId;

    if (!selection.value || slot == null || userId == null) {
      _observedAuthorizedSlot = null;
      _observedAuthorizedUserId = null;

      _linkedAuthorizationRevision++;
      _linkedRestorationUnavailable = false;
      return;
    }

    if (!_ready || _blocked) {
      return;
    }

    if (_observedAuthorizedSlot == slot &&
        _observedAuthorizedUserId == userId) {
      return;
    }

    _observedAuthorizedSlot = slot;
    _observedAuthorizedUserId = userId;

    final revision = ++_linkedAuthorizationRevision;
    _linkedRestorationUnavailable = false;

    if (_configuration?.linkedSlot != slot) {
      // El guard B controla su propia vigencia.
      return;
    }

    unawaited(
      _persistNewLinkedAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      ),
    );
  }

  bool _isCurrentLinkedAuthorization({
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
  }) {
    final selection = _biometric.selection;

    return !_disposed &&
        _ready &&
        !_blocked &&
        revision == _linkedAuthorizationRevision &&
        _configuration?.linkedSlot == slot &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId &&
        _linkedLifecycle.hasValidLinkedAccess;
  }

  /// Un error de persistencia invalida solamente
  /// la restauracion futura de A mientras la sesion
  /// actual siga siendo valida en memoria.
  Future<void> _persistNewLinkedAuthorization({
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
  }) async {
    try {
      final saved = await _linkedSync.beginAuthorized();

      if (!saved &&
          _isCurrentLinkedAuthorization(
            slot: slot,
            userId: userId,
            revision: revision,
          )) {
        await _invalidateLinkedRestorationCandidate(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    } catch (_) {
      if (_isCurrentLinkedAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      )) {
        await _invalidateLinkedRestorationCandidate(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    }
  }

  Future<void> _invalidateLinkedRestorationCandidate({
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
  }) async {
    if (!_isCurrentLinkedAuthorization(
      slot: slot,
      userId: userId,
      revision: revision,
    )) {
      return;
    }

    _linkedRestorationUnavailable = true;

    try {
      await _sessionJournal.revoke(slot: slot, userId: userId);
    } catch (_) {
      if (_isCurrentLinkedAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      )) {
        _failClosed();
      }
    }
  }

  void _requestLinkedPersistence({required bool force}) {
    if (_disposed ||
        !_ready ||
        _blocked ||
        _bindingTransitionRunning ||
        _linkedRestorationUnavailable) {
      return;
    }

    final slot = _configuration?.linkedSlot;
    final selection = _biometric.selection;
    final userId = selection.selectedUserId;

    if (slot == null ||
        userId == null ||
        !selection.value ||
        selection.selectedSlot != slot ||
        !_linkedLifecycle.hasValidLinkedAccess) {
      return;
    }

    final revision = _linkedAuthorizationRevision;

    final operation = force
        ? _linkedSync.persistTransition()
        : _linkedSync.persistActivity();

    unawaited(
      _completeLinkedPersistence(
        operation,
        slot: slot,
        userId: userId,
        revision: revision,
        force: force,
      ),
    );
  }

  Future<void> _completeLinkedPersistence(
    Future<bool> operation, {
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
    required bool force,
  }) async {
    try {
      final saved = await operation;

      if (force &&
          !saved &&
          _isCurrentLinkedAuthorization(
            slot: slot,
            userId: userId,
            revision: revision,
          )) {
        await _invalidateLinkedRestorationCandidate(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    } catch (_) {
      if (_isCurrentLinkedAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      )) {
        await _invalidateLinkedRestorationCandidate(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    }
  }

  void _registerLinkedActivity() {
    if (_disposed || !_ready || _blocked) {
      return;
    }

    _linkedLifecycle.registerActivity();
    _requestLinkedPersistence(force: false);
  }

  /// El cierre de A revoca la prueba criptografica y
  /// su checkpoint, despues de esperar una emision activa.
  /// B conserva la revocacion exclusiva de su checkpoint.
  ///
  /// La seleccion ya fue bloqueada sincronicamente por
  /// AccountSessionExitCoordinator.
  Future<void> _invalidatePersistedSession(
    FirebaseAccountSlot slot,
    String userId,
  ) {
    return _linkedRevocation.revoke(
      slot: slot,
      userId: userId,
      isLinked: _configuration?.linkedSlot == slot,
    );
  }

  /// Comprueba que la vinculacion siga ocupando
  /// exactamente el contexto identificado al arrancar.
  bool _bindingMatchesConfiguration(
    BiometricBindingState binding,
    FirebaseAccountSlot? linkedSlot,
  ) {
    if (linkedSlot == null) {
      return binding is BiometricBindingDisabled;
    }

    if (binding is! BiometricBindingEnabled) {
      return false;
    }

    return _dependenciesFor(linkedSlot).currentUserId == binding.userId;
  }

  Future<void> _prepare() async {
    final revision = ++_preparationRevision;
    _preparingLinkedSlot = null;

    try {
      await _waitForFirebaseAuthentication();

      if (_disposed || revision != _preparationRevision) {
        return;
      }

      final biometricGateway = widget.gateway;

      final BiometricUnlinkGateway? unlinkGateway =
          biometricGateway is BiometricUnlinkGateway
          ? biometricGateway as BiometricUnlinkGateway
          : null;

      if (unlinkGateway == null) {
        _failClosed();
        return;
      }

      final binding = await biometricGateway.readBinding();

      if (_disposed || revision != _preparationRevision) {
        return;
      }

      FirebaseAccountSlot? linkedSlot;

      if (binding is BiometricBindingUnavailable) {
        _failClosed();
        return;
      }

      if (binding is BiometricBindingEnabled) {
        final match = widget.contexts.locateUserId(binding.userId);

        linkedSlot = switch (match) {
          FirebaseAccountMatch.primary => FirebaseAccountSlot.primary,
          FirebaseAccountMatch.secondary => FirebaseAccountSlot.secondary,
          _ => null,
        };

        if (linkedSlot == null) {
          if (AccountLinkedSessionRecoveryPolicy.canOffer(
            binding: binding,
            primaryUserId: _primary.currentUserId,
            secondaryUserId: _secondary.currentUserId,
          )) {
            _enterLinkedRecovery(binding.userId);
          } else {
            _failClosed();
          }

          return;
        }
      } else if (binding is! BiometricBindingDisabled) {
        _failClosed();
        return;
      }

      final conventionalSlot = linkedSlot == null
          ? FirebaseAccountSlot.primary
          : _otherSlot(linkedSlot);

      final conventionalServices = _dependenciesFor(conventionalSlot);

      // Toda preparacion comienza sin permiso privado.
      // No se reutilizan autorizaciones de otro proceso.
      _biometric.lock();

      _linkedLifecycle.configureLinkedSlot(linkedSlot);

      // La clave convencional heredada es distinta
      // del almacenamiento nuevo de A y B.
      //
      // El guard confirmara nuevamente el registro
      // restaurado antes de mostrar datos privados.
      await widget.store.clear();

      if (_disposed || revision != _preparationRevision) {
        return;
      }

      final confirmedBinding = await biometricGateway.readBinding();

      if (_disposed || revision != _preparationRevision) {
        return;
      }

      if (!_bindingMatchesConfiguration(confirmedBinding, linkedSlot)) {
        _failClosed();
        return;
      }

      // El sincronizador necesita conocer el slot vinculado
      // ANTES de publicar _configuration. Solo se utiliza
      // mientras el acceso privado permanece bloqueado.
      _preparingLinkedSlot = linkedSlot;

      // Cuando A era la ultima cuenta activa, B puede
      // conservar una autenticacion Firebase anterior.
      //
      // Debe desconectarse ANTES de seleccionar A:
      // cambiar la identidad de B despues invalidaria
      // la seleccion vinculada recien restaurada.
      //
      // El checkpoint por si mismo no autoriza acceso.
      final pendingSnapshot = await _sessionJournal.readSnapshot();

      if (_disposed || revision != _preparationRevision) {
        _biometric.lock();
        return;
      }

      if (linkedSlot != null &&
          pendingSnapshot.active?.slot == linkedSlot &&
          conventionalServices.currentUserId != null) {
        await _prepareConventionalContext(conventionalServices);
      }

      if (_disposed || revision != _preparationRevision) {
        _biometric.lock();
        return;
      }

      // Este evaluador comprueba Firebase, la vinculacion,
      // el checkpoint, la identidad y los limites temporales.
      //
      // Puede utilizarse para A o B, pero nunca concede
      // acceso privado directamente.
      final assessment = AccountSessionStartupAssessment(
        readSnapshot: _sessionJournal.readSnapshot,
        readBinding: biometricGateway.readBinding,
        primarySession: _biometric.primarySession,
        secondarySession: _biometric.secondarySession,
      );

      AccountLinkedSessionRestoration? restoredLinked;
      AccountConventionalSessionRestoration? restored;

      // Solo A vinculada puede solicitar prueba nativa.
      //
      // Android Keystore verifica la credencial ya emitida.
      // No se solicita una segunda huella mientras esa
      // credencial siga autorizada por Android.
      if (linkedSlot != null &&
          _dependenciesFor(linkedSlot).currentUserId != null) {
        final continuity = AccountLinkedSessionContinuityAssessment(
          startup: assessment,
          proof: AndroidLinkedContinuityGateway(),
        );

        final linkedRestore = AccountLinkedSessionRestoreCoordinator(
          selection: _biometric.selection,
          continuity: continuity,
          linkedSlot: linkedSlot,
        );

        restoredLinked = await linkedRestore.restoreLinked();

        if (_disposed || revision != _preparationRevision) {
          _biometric.lock();
          return;
        }

        if (restoredLinked != null) {
          final candidate = restoredLinked;
          final selected = _biometric.selection;
          final linkedServices = _dependenciesFor(linkedSlot);

          final matches =
              candidate.slot == linkedSlot &&
              candidate.userId == linkedServices.currentUserId &&
              selected.value &&
              selected.selectedSlot == linkedSlot &&
              selected.selectedUserId == candidate.userId &&
              conventionalServices.currentUserId == null &&
              !candidate.record.isExpired(
                DateTime.now().toUtc(),
                restoring: true,
              );

          // La seleccion inicia provisionalmente el
          // temporizador. Sustituirlo por el ORIGINAL
          // antes de publicar la interfaz privada.
          //
          // No reiniciar las 24 horas absolutas.
          if (!matches ||
              !_linkedLifecycle.restoreAuthorized(
                slot: candidate.slot,
                expectedUserId: candidate.userId,
                record: candidate.record,
              )) {
            _biometric.lock();
            restoredLinked = null;
          } else {
            // Persistir la reanudacion antes de mostrar
            // Inicio. No volver a emitir otra credencial
            // ni solicitar una nueva huella.
            final saved = await _linkedSync.persistRestored();

            if (_disposed || revision != _preparationRevision) {
              _biometric.lock();
              return;
            }

            if (!saved) {
              _biometric.lock();
              restoredLinked = null;
            }
          }
        }
      }

      // Si A no pudo restaurarse, B puede intentar
      // su evaluacion independiente.
      //
      // Nunca conceder acceso a A utilizando solamente
      // su sesion Firebase.
      if (restoredLinked == null) {
        _biometric.lock();

        if (conventionalServices.currentUserId != null) {
          final conventionalRestore =
              AccountConventionalSessionRestoreCoordinator(
                selection: _biometric.selection,
                assessment: assessment,
              );

          restored = await conventionalRestore.restoreConventional();
        }
      }

      if (_disposed || revision != _preparationRevision) {
        _biometric.lock();
        return;
      }

      // Rechazar candidatos convencionales de otro
      // contexto o vencidos durante la validacion.
      if (restored != null &&
          (restored.slot != conventionalSlot ||
              restored.userId != conventionalServices.currentUserId ||
              !_biometric.selection.value ||
              _biometric.selection.selectedSlot != conventionalSlot ||
              _biometric.selection.selectedUserId != restored.userId ||
              restored.record.isExpired(
                DateTime.now().toUtc(),
                restoring: true,
              ))) {
        _biometric.lock();
        restored = null;
      }

      if (restoredLinked == null && restored == null) {
        // Sin candidato autorizado, exigir Login.
        //
        // Conservar la sesion Firebase de A vinculada
        // para permitir su acceso posterior con huella.
        _biometric.lock();

        await _prepareConventionalContext(conventionalServices);

        if (linkedSlot == null) {
          await _prepareConventionalContext(_secondary);
        }
      } else if (restoredLinked != null) {
        // B debio quedar desconectada ANTES de
        // seleccionar A. Si una identidad aparece
        // durante los awaits, bloquear el arranque.
        if (conventionalServices.currentUserId != null) {
          _failClosed();
          return;
        }
      } else if (linkedSlot == null && _secondary.currentUserId != null) {
        // Sin vinculacion, SECONDARY no puede
        // conservar otra identidad adicional.
        _failClosed();
        return;
      }

      if (_disposed || revision != _preparationRevision) {
        _biometric.lock();
        return;
      }

      // Verificar nuevamente la vinculacion tras
      // las operaciones de autenticacion.
      final finalBinding = await biometricGateway.readBinding();

      if (_disposed || revision != _preparationRevision) {
        _biometric.lock();
        return;
      }

      if (!_bindingMatchesConfiguration(finalBinding, linkedSlot)) {
        _failClosed();
        return;
      }

      if (restoredLinked != null) {
        final selected = _biometric.selection;
        final currentRecord = _linkedLifecycle.record;

        // Ultima barrera antes de montar Inicio de A.
        //
        // Exigir el mismo UID, contexto Firebase,
        // inicio original y vigencia.
        if (!selected.value ||
            selected.selectedSlot != restoredLinked.slot ||
            selected.selectedUserId != restoredLinked.userId ||
            _dependenciesFor(restoredLinked.slot).currentUserId !=
                restoredLinked.userId ||
            conventionalServices.currentUserId != null ||
            !_linkedLifecycle.hasValidLinkedAccess ||
            currentRecord == null ||
            currentRecord.userId != restoredLinked.userId ||
            currentRecord.startedAt.millisecondsSinceEpoch !=
                restoredLinked.record.startedAt.millisecondsSinceEpoch ||
            currentRecord.isExpired(DateTime.now().toUtc())) {
          _failClosed();
          return;
        }
      } else if (restored == null) {
        if (conventionalServices.currentUserId != null) {
          _failClosed();
          return;
        }
      } else if (!_biometric.selection.value ||
          _biometric.selection.selectedSlot != conventionalSlot ||
          _biometric.selection.selectedUserId != restored.userId ||
          conventionalServices.currentUserId != restored.userId ||
          restored.record.isExpired(DateTime.now().toUtc(), restoring: true)) {
        _failClosed();
        return;
      }

      final primaryExitTarget = FirebaseAccountSessionExitTarget(
        _primary.authRepository,
      );

      final secondaryExitTarget = FirebaseAccountSessionExitTarget(
        _secondary.authRepository,
      );

      final exit = AccountSessionExitCoordinator(
        selection: _biometric.selection,
        linkedSlot: linkedSlot,
        primary: primaryExitTarget,
        secondary: secondaryExitTarget,
        beforeExit: _invalidatePersistedSession,
      );

      final duplicateRelease = linkedSlot == null
          ? null
          : AccountDuplicateSessionRelease(
              selection: _biometric.selection,
              linkedSlot: linkedSlot,
              primary: primaryExitTarget,
              secondary: secondaryExitTarget,
            );

      final conventional = AccountConventionalAccessCoordinator(
        selection: _biometric.selection,
        primarySession: _biometric.primarySession,
        secondarySession: _biometric.secondarySession,
        linkedSlot: linkedSlot,
        releaseDuplicateSession: duplicateRelease?.release,
      );

      final settings = AccountBiometricSettingsController(
        selection: _biometric.selection,
        primarySession: _biometric.primarySession,
        secondarySession: _biometric.secondarySession,
        gateway: biometricGateway,
        unlinkGateway: unlinkGateway,
        onBindingChanged: _applyBindingChange,
      );

      if (_disposed || revision != _preparationRevision) {
        settings.dispose();
        conventional.dispose();
        duplicateRelease?.dispose();
        exit.dispose();
        _biometric.lock();
        return;
      }

      _conventionalSync?.dispose();
      _conventionalSync = null;

      _settingsController?.dispose();
      _conventional?.dispose();
      _duplicateRelease?.dispose();
      _sessionExit?.dispose();

      _settingsController = settings;
      _conventional = conventional;
      _duplicateRelease = duplicateRelease;
      _sessionExit = exit;

      // Debe establecerse antes de montar el guard:
      // SessionTimeoutGuard consume initialRecord
      // durante su inicializacion.
      _initialConventionalRecord = restored?.record;

      // El selector notifico la restauracion mientras
      // _ready era false. No generar otra sesion ni
      // emitir otra credencial al publicar Inicio.
      _observedAuthorizedSlot = restoredLinked?.slot;
      _observedAuthorizedUserId = restoredLinked?.userId;

      setState(() {
        _configuration = SendarisAccountSessionConfiguration(
          conventionalSlot: conventionalSlot,
          linkedSlot: linkedSlot,
        );

        _ready = true;
        _blocked = false;
        _recoveringLinkedUid = null;
      });

      _preparingLinkedSlot = null;
      _installConventionalPersistenceSync();
    } catch (_) {
      if (!_disposed && revision == _preparationRevision) {
        _failClosed();
      }
    }
  }

  void _enterLinkedRecovery(String expectedUserId) {
    if (_disposed) {
      return;
    }

    _conventionalSync?.dispose();
    _conventionalSync = null;

    _initialConventionalRecord = null;
    _preparingLinkedSlot = null;

    _linkedLifecycle.configureLinkedSlot(null);
    _biometric.lock();

    setState(() {
      _configuration = null;
      _ready = false;
      _blocked = false;
      _recoveringLinkedUid = expectedUserId;
    });
  }

  Future<bool> _clearUnexpectedRecoveryUser(String expectedUserId) async {
    final wrongUserId = _primary.currentUserId;

    if (wrongUserId == null) {
      return true;
    }

    if (wrongUserId == expectedUserId || _secondary.currentUserId != null) {
      return false;
    }

    final binding = await widget.gateway.readBinding();

    if (binding is! BiometricBindingEnabled ||
        binding.userId != expectedUserId ||
        _primary.currentUserId != wrongUserId ||
        _secondary.currentUserId != null) {
      return false;
    }

    try {
      await _primary.authRepository.signOut();
    } catch (_) {
      return false;
    }

    return _primary.currentUserId == null && _secondary.currentUserId == null;
  }

  Future<AccountLinkedRecoveryResult> _recoverLinkedSession(
    Future<bool> Function() authenticate,
  ) async {
    final expectedUserId = _recoveringLinkedUid;

    if (_disposed || expectedUserId == null || _blocked) {
      return AccountLinkedRecoveryResult.unavailable;
    }

    if (_recoveryBusy) {
      return AccountLinkedRecoveryResult.busy;
    }

    _recoveryBusy = true;

    try {
      if (_secondary.currentUserId != null) {
        _failClosed();
        return AccountLinkedRecoveryResult.otherContextOccupied;
      }

      final currentUserId = _primary.currentUserId;

      if (currentUserId == expectedUserId) {
        final binding = await widget.gateway.readBinding();

        if (_disposed || _recoveringLinkedUid != expectedUserId) {
          return AccountLinkedRecoveryResult.unavailable;
        }

        if (binding is! BiometricBindingEnabled ||
            binding.userId != expectedUserId) {
          _failClosed();
          return AccountLinkedRecoveryResult.bindingChanged;
        }

        final valid = await _biometric.primarySession.validate(
          expectedUserId: expectedUserId,
        );

        if (_disposed ||
            _recoveringLinkedUid != expectedUserId ||
            _primary.currentUserId != expectedUserId ||
            _secondary.currentUserId != null) {
          _failClosed();
          return AccountLinkedRecoveryResult.identityChanged;
        }

        if (!valid) {
          return AccountLinkedRecoveryResult.sessionInvalid;
        }

        final confirmedBinding = await widget.gateway.readBinding();

        if (_disposed ||
            _recoveringLinkedUid != expectedUserId ||
            _primary.currentUserId != expectedUserId ||
            _secondary.currentUserId != null ||
            confirmedBinding is! BiometricBindingEnabled ||
            confirmedBinding.userId != expectedUserId) {
          _failClosed();
          return AccountLinkedRecoveryResult.bindingChanged;
        }

        return AccountLinkedRecoveryResult.recovered;
      }

      if (currentUserId != null) {
        final cleared = await _clearUnexpectedRecoveryUser(expectedUserId);

        if (!cleared) {
          _failClosed();
          return AccountLinkedRecoveryResult.unavailable;
        }
      }

      final result = await _linkedRecovery.recover(authenticate: authenticate);

      if (_disposed || _recoveringLinkedUid != expectedUserId) {
        return AccountLinkedRecoveryResult.unavailable;
      }

      if (result == AccountLinkedRecoveryResult.recovered) {
        if (_primary.currentUserId != expectedUserId ||
            _secondary.currentUserId != null) {
          _failClosed();
          return AccountLinkedRecoveryResult.identityChanged;
        }

        return result;
      }

      if (_secondary.currentUserId != null) {
        _failClosed();
        return AccountLinkedRecoveryResult.otherContextOccupied;
      }

      if (_primary.currentUserId != null &&
          _primary.currentUserId != expectedUserId) {
        final cleared = await _clearUnexpectedRecoveryUser(expectedUserId);

        if (!cleared) {
          _failClosed();
          return AccountLinkedRecoveryResult.unavailable;
        }

        return AccountLinkedRecoveryResult.accountMismatch;
      }

      if (result == AccountLinkedRecoveryResult.bindingChanged ||
          result == AccountLinkedRecoveryResult.bindingUnavailable) {
        _failClosed();
      }

      return result;
    } catch (_) {
      return AccountLinkedRecoveryResult.unavailable;
    } finally {
      _recoveryBusy = false;
    }
  }

  Future<AccountLinkedRecoveryResult> _recoverLinkedPassword(
    String email,
    String password,
  ) {
    return _recoverLinkedSession(() async {
      await _primary.authRepository.signIn(email: email, password: password);

      return true;
    });
  }

  Future<AccountLinkedRecoveryResult> _recoverLinkedGoogle() {
    return _recoverLinkedSession(() async {
      final userId = await _primary.authRepository.signInWithGoogleObserved(
        onExecutionStarted: () {},
      );

      return userId != null;
    });
  }

  void _afterLinkedSessionRecovered() {
    if (_disposed || _recoveringLinkedUid == null || _recoveryBusy) {
      return;
    }

    _conventionalSync?.dispose();
    _conventionalSync = null;

    _initialConventionalRecord = null;

    _linkedLifecycle.closeLinkedAccess();
    _biometric.lock();

    setState(() {
      _recoveringLinkedUid = null;
      _configuration = null;
      _ready = false;
      _blocked = false;
    });

    unawaited(_prepare());
  }

  Future<bool> _applyBindingChange(AccountBiometricBindingChange change) async {
    if (_disposed || !_ready || _blocked || _bindingTransitionRunning) {
      return false;
    }

    final previous = _configuration;
    final conventional = _conventional;
    final exit = _sessionExit;
    final settings = _settingsController;

    if (previous == null ||
        conventional == null ||
        exit == null ||
        settings == null) {
      _failClosed();
      return false;
    }

    _bindingTransitionRunning = true;

    try {
      final selection = _biometric.selection;

      if (!selection.value ||
          selection.selectedSlot != change.slot ||
          selection.selectedUserId != change.userId ||
          _dependenciesFor(change.slot).currentUserId != change.userId) {
        _failClosed();
        return false;
      }

      if (conventional.isSigningIn || exit.isBusy) {
        _failClosed();
        return false;
      }

      final otherSlot = _otherSlot(change.slot);

      if (_dependenciesFor(otherSlot).currentUserId != null) {
        _failClosed();
        return false;
      }

      if (change.operation == AccountBiometricBindingOperation.activation) {
        if (previous.linkedSlot != null ||
            previous.conventionalSlot != change.slot) {
          _failClosed();
          return false;
        }
      } else {
        if (previous.linkedSlot != change.slot) {
          _failClosed();
          return false;
        }
      }

      final binding = await widget.gateway.readBinding();

      if (_disposed || !_ready || _blocked) {
        return false;
      }

      if (!selection.value ||
          selection.selectedSlot != change.slot ||
          selection.selectedUserId != change.userId ||
          _dependenciesFor(change.slot).currentUserId != change.userId ||
          _dependenciesFor(otherSlot).currentUserId != null) {
        _failClosed();
        return false;
      }

      final nextLinkedSlot = change.enabled ? change.slot : null;

      if (change.enabled) {
        if (binding is! BiometricBindingEnabled ||
            binding.userId != change.userId) {
          _failClosed();
          return false;
        }
      } else if (binding is! BiometricBindingDisabled) {
        _failClosed();
        return false;
      }

      await _stopConventionalPersistenceSync();

      if (_disposed ||
          !_ready ||
          _blocked ||
          !selection.value ||
          selection.selectedSlot != change.slot ||
          selection.selectedUserId != change.userId ||
          _dependenciesFor(change.slot).currentUserId != change.userId ||
          _dependenciesFor(otherSlot).currentUserId != null) {
        _failClosed();
        return false;
      }

      // La desactivacion ya fue confirmada por el vault
      // original. No conservar una prueba de continuidad
      // asociada a la antigua vinculacion.
      //
      // Una activacion desde una cuenta convencional
      // solamente revoca su checkpoint anterior.
      //
      // Ante un error, el coordinador intenta ambas
      // revocaciones y esta raiz bloquea el acceso.
      await _linkedRevocation.revoke(
        slot: change.slot,
        userId: change.userId,
        isLinked: previous.linkedSlot == change.slot,
      );

      if (_disposed ||
          !_ready ||
          _blocked ||
          !selection.value ||
          selection.selectedSlot != change.slot ||
          selection.selectedUserId != change.userId ||
          _dependenciesFor(change.slot).currentUserId != change.userId) {
        _failClosed();
        return false;
      }

      final nextConventionalSlot = nextLinkedSlot == null
          ? change.slot
          : otherSlot;

      final primaryExitTarget = FirebaseAccountSessionExitTarget(
        _primary.authRepository,
      );

      final secondaryExitTarget = FirebaseAccountSessionExitTarget(
        _secondary.authRepository,
      );

      final nextDuplicateRelease = nextLinkedSlot == null
          ? null
          : AccountDuplicateSessionRelease(
              selection: selection,
              linkedSlot: nextLinkedSlot,
              primary: primaryExitTarget,
              secondary: secondaryExitTarget,
            );

      exit.configureLinkedSlot(nextLinkedSlot);

      conventional.configureLinkedAccount(
        linkedSlot: nextLinkedSlot,
        releaseDuplicateSession: nextDuplicateRelease?.release,
      );

      final oldDuplicateRelease = _duplicateRelease;
      _duplicateRelease = nextDuplicateRelease;

      // Una reconfiguracion invalida cualquier registro
      // de arranque perteneciente al rol anterior.
      _initialConventionalRecord = null;

      setState(() {
        _configuration = SendarisAccountSessionConfiguration(
          conventionalSlot: nextConventionalSlot,
          linkedSlot: nextLinkedSlot,
        );
      });

      _linkedLifecycle.configureLinkedSlot(nextLinkedSlot);

      _linkedAuthorizationRevision++;
      _linkedRestorationUnavailable = false;
      _observedAuthorizedSlot = null;
      _observedAuthorizedUserId = null;

      _observeAuthorizedSelection();

      _installConventionalPersistenceSync();

      oldDuplicateRelease?.dispose();

      return true;
    } catch (_) {
      _failClosed();
      return false;
    } finally {
      _bindingTransitionRunning = false;
    }
  }

  void _failClosed() {
    if (_disposed) {
      return;
    }

    _linkedAuthorizationRevision++;
    _linkedRestorationUnavailable = true;

    _initialConventionalRecord = null;
    _preparingLinkedSlot = null;

    _conventionalSync?.dispose();
    _conventionalSync = null;

    _linkedLifecycle.configureLinkedSlot(null);
    _biometric.lock();

    setState(() {
      _configuration = null;
      _ready = false;
      _blocked = true;
      _recoveringLinkedUid = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_disposed) {
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final wasBackgrounded = _linkedLifecycle.isBackgrounded;

      _linkedLifecycle.enterBackground();

      if (!wasBackgrounded && _linkedLifecycle.isBackgrounded) {
        _requestLinkedPersistence(force: true);
      }
    } else if (state == AppLifecycleState.resumed) {
      final wasBackgrounded = _linkedLifecycle.isBackgrounded;

      _linkedLifecycle.resume();

      if (wasBackgrounded && !_linkedLifecycle.isBackgrounded) {
        _requestLinkedPersistence(force: true);
      }
    }
  }

  Widget _application(SendarisAccountDependencies services) {
    return SendarisApp(
      authRepository: services.authRepository,
      privateAccessPermission: _biometric.selection,
      trackingRepository: services.trackingRepository,
      trackingProfileFactory: services.trackingProfileFactory,
      behaviorRepository: services.behaviorRepository,
      behaviorRecordFactory: services.behaviorRecordFactory,
      sleepRepository: services.sleepRepository,
      sleepRecordFactory: services.sleepRecordFactory,
      feedingRepository: services.feedingRepository,
      feedingRecordFactory: services.feedingRecordFactory,
      socialInteractionRepository: services.socialInteractionRepository,
      socialInteractionRecordFactory: services.socialInteractionRecordFactory,
      dysregulationRepository: services.dysregulationRepository,
      dysregulationRecordFactory: services.dysregulationRecordFactory,
      durationRepository: services.durationRepository,
      routineRepository: services.routineRepository,
      routineFactory: services.routineFactory,
      routineStatusRepository: services.routineStatusRepository,
      routineStatusRecordFactory: services.routineStatusRecordFactory,
      routineComplianceRepository: services.routineComplianceRepository,
      atypicalSituationRepository: services.atypicalSituationRepository,
      atypicalSituationRecordFactory: services.atypicalSituationRecordFactory,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _preparationRevision++;
    _linkedAuthorizationRevision++;
    _preparingLinkedSlot = null;

    WidgetsBinding.instance.removeObserver(this);

    _biometric.selection.removeListener(_observeAuthorizedSelection);

    _conventionalSync?.dispose();
    _conventionalSync = null;

    _settingsController?.dispose();
    _conventional?.dispose();
    _duplicateRelease?.dispose();
    _sessionExit?.dispose();

    _linkedSync.dispose();
    _linkedLifecycle.dispose();
    _sessionJournal.dispose();

    _linkedRecovery.dispose();
    _biometric.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkedRecoveryUid = _recoveringLinkedUid;

    if (linkedRecoveryUid != null && !_blocked) {
      return MaterialApp(
        title: 'Sendaris',
        debugShowCheckedModeBanner: false,
        home: AccountLinkedSessionRecoveryScreen(
          key: const ValueKey<String>('dual-linked-recovery'),
          onPasswordRecovery: _recoverLinkedPassword,
          onGoogleRecovery: _recoverLinkedGoogle,
          onSessionRecovered: _afterLinkedSessionRecovered,
        ),
      );
    }

    if (_blocked) {
      // Conservar un estado explicito de error de seguridad.
      // Nunca sustituirlo por Login o Inicio sin validacion.
      return const _SessionAccessBlockedScreen();
    }

    final configuration = _configuration;
    final conventional = _conventional;
    final exit = _sessionExit;
    final settings = _settingsController;

    if (!_ready ||
        configuration == null ||
        conventional == null ||
        exit == null ||
        settings == null) {
      // Reemplazo definitivo del indicador de preparacion.
      //
      // El logo se anima exclusivamente mientras Firebase,
      // Android Keystore y el diario siguen comprobando
      // la autorizacion. No concede acceso privado.
      return const SendarisAnimatedLaunch(
        key: ValueKey<String>('sendaris-animated-launch'),
      );
    }

    final conventionalServices = _dependenciesFor(
      configuration.conventionalSlot,
    );

    return MultiProvider(
      providers: [
        Provider<AccountBiometricAccessCoordinator>.value(value: _biometric),
        Provider<AccountConventionalAccessCoordinator>.value(
          value: conventional,
        ),
        Provider<AccountSessionExitCoordinator>.value(value: exit),
        ChangeNotifierProvider<AccountBiometricSettingsController>.value(
          value: settings,
        ),
        Provider<SendarisAccountSessionConfiguration>.value(
          value: configuration,
        ),
      ],
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          _registerLinkedActivity();
        },
        onPointerSignal: (_) {
          _registerLinkedActivity();
        },
        child: SessionTimeoutGuard(
          key: const ValueKey<String>('sendaris-conventional-timeout'),
          authRepository: conventionalServices.authRepository,
          store: widget.store,

          // Nunca fabricar un inicio nuevo para
          // una cuenta convencional restaurada.
          //
          // El guard comprueba la vigencia del registro
          // antes de construir contenido privado de B.
          initialRecord: _initialConventionalRecord,

          accessSelection: _biometric.selection,
          conventionalSlot: configuration.conventionalSlot,
          child: SendarisAccountPrivateHost(
            selection: _biometric.selection,
            primary: _primary,
            secondary: _secondary,
            lockedBuilder: (_) {
              return _application(conventionalServices);
            },
          ),
        ),
      ),
    );
  }
}

/// Pantalla reservada para una falla real de seguridad.
///
/// No es una pantalla de carga. No contiene spinner,
/// animacion de preparacion ni datos de cuentas.
///
/// Conserva el bloqueo explicito que ya utilizaba
/// la raiz dual, respetando el tema elegido.
final class _SessionAccessBlockedScreen extends StatelessWidget {
  const _SessionAccessBlockedScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sendaris',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: SendarisThemePreference.selectedMode,
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 52,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Acceso protegido',
                        key: const ValueKey<String>(
                          'dual-account-root-blocked',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudo confirmar de forma '
                        'segura la identidad vinculada. '
                        'El acceso privado permanece bloqueado.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
