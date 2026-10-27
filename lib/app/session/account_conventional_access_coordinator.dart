import 'account_biometric_access_coordinator.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';

/// Libera una autenticacion convencional duplicada
/// sin desconectar el contexto biometrico reservado.
typedef DuplicateConventionalSessionRelease = Future<bool> Function(
  FirebaseAccountSlot slot,
  String expectedUserId,
);

/// Coordina nuevos ingresos mediante correo,
/// contrasena y Google.
///
/// No concede acceso por restauracion automatica.
/// No modifica claves biometricas.
/// No almacena contrasenas.
/// No modifica Firestore.
///
/// La seleccion privada solamente se concede
/// tras validar una autenticacion solicitada
/// expresamente por el usuario.
final class AccountConventionalAccessCoordinator {
  /// Mantiene la API publica con parametros
  /// nombrados que ya utiliza el resto de Sendaris.
  factory AccountConventionalAccessCoordinator({
    required AccountSessionSelectionController selection,
    required AccountFirebaseSessionVerifier primarySession,
    required AccountFirebaseSessionVerifier secondarySession,
    FirebaseAccountSlot? linkedSlot,
    DuplicateConventionalSessionRelease? releaseDuplicateSession,
  }) {
    return AccountConventionalAccessCoordinator._(
      selection,
      primarySession,
      secondarySession,
      linkedSlot,
      releaseDuplicateSession,
    );
  }

  /// Inicializa los campos directamente mediante
  /// initializing formals, sin modificar la API.
  AccountConventionalAccessCoordinator._(
    this.selection,
    this.primarySession,
    this.secondarySession,
    this._linkedSlot,
    this._releaseDuplicateSession,
  );

  final AccountSessionSelectionController selection;

  final AccountFirebaseSessionVerifier primarySession;
  final AccountFirebaseSessionVerifier secondarySession;

  FirebaseAccountSlot? _linkedSlot;

  DuplicateConventionalSessionRelease? _releaseDuplicateSession;

  bool _busy = false;
  bool _disposed = false;
  int _revision = 0;

  bool get isSigningIn => !_disposed && _busy;

  FirebaseAccountSlot? get linkedSlot => _linkedSlot;

  /// Permite actualizar el contexto reservado
  /// despues de activar o desactivar la biometria.
  ///
  /// No cancela la seleccion vigente ni reemplaza
  /// las sesiones Firebase.
  ///
  /// Su invocacion corresponde exclusivamente
  /// al componente raiz despues de comprobar
  /// que la transicion es valida.
  void configureLinkedAccount({
    required FirebaseAccountSlot? linkedSlot,
    DuplicateConventionalSessionRelease? releaseDuplicateSession,
  }) {
    if (_disposed || _busy) {
      throw StateError(
        'No se puede cambiar la cuenta vinculada '
        'durante una autenticacion.',
      );
    }

    _linkedSlot = linkedSlot;
    _releaseDuplicateSession = releaseDuplicateSession;
  }

  AccountFirebaseSessionVerifier _sessionFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primarySession,
      FirebaseAccountSlot.secondary => secondarySession,
    };
  }

  bool _validUid(String? uid) {
    return uid != null && uid.isNotEmpty && uid.trim() == uid;
  }

  bool _operationCurrent(int revision) {
    return !_disposed && revision == _revision;
  }

  /// Inicia una autenticacion convencional real
  /// y espera su validacion completa antes de
  /// permitir otra solicitud.
  Future<bool> signIn({
    required FirebaseAccountSlot slot,
    required Future<bool> Function() authenticate,
  }) async {
    if (_disposed || _busy) {
      return false;
    }

    _busy = true;
    final revision = ++_revision;

    selection.lock();

    final conventionalSession = _sessionFor(slot);

    try {
      // No convertir una sesion restaurada en un
      // nuevo ingreso solicitado por el usuario.
      if (conventionalSession.currentUserId != null) {
        return false;
      }

      final authenticated = await authenticate();

      if (!authenticated || !_operationCurrent(revision)) {
        return false;
      }

      final userId = conventionalSession.currentUserId;

      if (!_validUid(userId)) {
        return false;
      }

      final expectedUserId = userId!;
      final reservedSlot = _linkedSlot;

      // Acceso convencional a la misma cuenta A
      // que ya esta vinculada a la huella.
      if (reservedSlot != null && reservedSlot != slot) {
        final reservedSession = _sessionFor(reservedSlot);

        if (reservedSession.currentUserId == expectedUserId) {
          return await _authorizeLinkedAccountUsingCredentials(
            conventionalSlot: slot,
            linkedSlot: reservedSlot,
            expectedUserId: expectedUserId,
            revision: revision,
          );
        }
      }

      // B, C, D y las siguientes cuentas
      // utilizan el contexto convencional.
      return await _authorize(
        slot: slot,
        expectedUserId: expectedUserId,
        session: conventionalSession,
        revision: revision,
      );
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> _authorizeLinkedAccountUsingCredentials({
    required FirebaseAccountSlot conventionalSlot,
    required FirebaseAccountSlot linkedSlot,
    required String expectedUserId,
    required int revision,
  }) async {
    final conventionalSession = _sessionFor(conventionalSlot);

    final reservedSession = _sessionFor(linkedSlot);

    final release = _releaseDuplicateSession;

    if (release == null ||
        !_operationCurrent(revision) ||
        conventionalSession.currentUserId != expectedUserId ||
        reservedSession.currentUserId != expectedUserId) {
      return false;
    }

    final conventionalValid = await conventionalSession.validate(
      expectedUserId: expectedUserId,
    );

    if (!conventionalValid ||
        !_operationCurrent(revision) ||
        conventionalSession.currentUserId != expectedUserId ||
        reservedSession.currentUserId != expectedUserId) {
      return false;
    }

    final reservedValid = await reservedSession.validate(
      expectedUserId: expectedUserId,
    );

    if (!reservedValid ||
        !_operationCurrent(revision) ||
        conventionalSession.currentUserId != expectedUserId ||
        reservedSession.currentUserId != expectedUserId) {
      return false;
    }

    // El duplicado se cierra sin desconectar A
    // de su contexto biometrico original.
    final released = await release(conventionalSlot, expectedUserId);

    if (!released ||
        !_operationCurrent(revision) ||
        conventionalSession.currentUserId != null ||
        reservedSession.currentUserId != expectedUserId) {
      return false;
    }

    return await _authorize(
      slot: linkedSlot,
      expectedUserId: expectedUserId,
      session: reservedSession,
      revision: revision,
    );
  }

  Future<bool> _authorize({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required AccountFirebaseSessionVerifier session,
    required int revision,
  }) async {
    if (!_operationCurrent(revision) ||
        session.currentUserId != expectedUserId) {
      return false;
    }

    final granted = await selection.select(
      slot: slot,
      expectedUserId: expectedUserId,
      verifyAccess: () async {
        if (!_operationCurrent(revision) ||
            session.currentUserId != expectedUserId) {
          return false;
        }

        final valid = await session.validate(expectedUserId: expectedUserId);

        return valid &&
            _operationCurrent(revision) &&
            session.currentUserId == expectedUserId;
      },
    );

    if (!_operationCurrent(revision)) {
      // Una operacion anterior no puede conceder
      // acceso despues de una cancelacion.
      selection.lock();
      return false;
    }

    return granted &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == expectedUserId;
  }

  void cancelAndLock() {
    if (_disposed) {
      return;
    }

    _revision++;
    selection.lock();
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    cancelAndLock();
    _disposed = true;
  }
}
