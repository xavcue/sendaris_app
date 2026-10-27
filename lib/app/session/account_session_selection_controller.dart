import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_account_contexts.dart';

/// Fuente observable de la identidad de una sesión.
///
/// Permite probar los cambios de cuenta sin conectarse
/// a Firebase y utilizar FirebaseAuth en producción.
abstract interface class AccountIdentitySource {
  String? get currentUserId;

  Stream<String?> get userIdChanges;
}

/// Adaptador de la identidad de Firebase Authentication.
///
/// Los cambios de UID proceden de Firebase, no de
/// valores introducidos en la interfaz.
final class FirebaseAccountIdentitySource implements AccountIdentitySource {
  const FirebaseAccountIdentitySource(this.auth);

  final FirebaseAuth auth;

  @override
  String? get currentUserId => auth.currentUser?.uid;

  @override
  Stream<String?> get userIdChanges =>
      auth.userChanges().map((user) => user?.uid);
}

/// Controla qué contexto puede acceder a la interfaz privada.
///
/// No realiza autenticación biométrica ni concede
/// autorizaciones por sí mismo.
///
/// El callback verifyAccess deberá implementarse
/// posteriormente mediante un coordinador de confianza
/// que confirme la sesión Firebase y, cuando corresponda,
/// la operación criptográfica de Android Keystore.
///
/// La autorización se rechaza si:
/// - cambia cualquier identidad durante la verificación;
/// - las dos instancias contienen el mismo UID;
/// - se cancela o falla la comprobación;
/// - se bloquea la sesión antes de finalizar;
/// - una operación anterior termina fuera de su revisión.
///
/// El controlador no cambia cuentas, elimina sesiones
/// ni realiza operaciones sobre Firestore.
final class AccountSessionSelectionController extends ChangeNotifier
    implements ValueListenable<bool> {
  AccountSessionSelectionController({
    required AccountIdentitySource primary,
    required AccountIdentitySource secondary,
  }) : _primary = primary,
       _secondary = secondary,
       _observedPrimaryUserId = primary.currentUserId,
       _observedSecondaryUserId = secondary.currentUserId {
    _primarySubscription = _primary.userIdChanges.listen(
      (userId) => _observeIdentity(FirebaseAccountSlot.primary, userId),
      onError: (Object error, StackTrace stackTrace) {
        lock();
      },
    );

    _secondarySubscription = _secondary.userIdChanges.listen(
      (userId) => _observeIdentity(FirebaseAccountSlot.secondary, userId),
      onError: (Object error, StackTrace stackTrace) {
        lock();
      },
    );
  }

  final AccountIdentitySource _primary;
  final AccountIdentitySource _secondary;

  late final StreamSubscription<String?> _primarySubscription;
  late final StreamSubscription<String?> _secondarySubscription;

  String? _observedPrimaryUserId;
  String? _observedSecondaryUserId;

  FirebaseAccountSlot? _selectedSlot;
  String? _selectedUserId;

  int _revision = 0;

  bool _verifying = false;
  bool _disposed = false;

  FirebaseAccountSlot? get selectedSlot => value ? _selectedSlot : null;

  String? get selectedUserId => value ? _selectedUserId : null;

  bool get isVerifying => !_disposed && _verifying;

  /// Un permiso previo no se conserva cuando la
  /// identidad deja de coincidir con el contexto.
  @override
  bool get value {
    if (_disposed ||
        _verifying ||
        _selectedSlot == null ||
        _selectedUserId == null) {
      return false;
    }

    return _matchesIdentity(slot: _selectedSlot!, userId: _selectedUserId!);
  }

  bool _validUserId(String? userId) {
    return userId != null && userId.isNotEmpty && userId.trim() == userId;
  }

  /// Exige que la identidad observada y la identidad
  /// actual de Firebase coincidan.
  ///
  /// No basta con que un callback asíncrono informe
  /// que la autenticación terminó correctamente.
  bool _matchesIdentity({
    required FirebaseAccountSlot slot,
    required String userId,
  }) {
    if (!_validUserId(userId)) {
      return false;
    }

    final currentPrimary = _primary.currentUserId;
    final currentSecondary = _secondary.currentUserId;

    if (_observedPrimaryUserId != currentPrimary ||
        _observedSecondaryUserId != currentSecondary) {
      return false;
    }

    final selected = slot == FirebaseAccountSlot.primary
        ? currentPrimary
        : currentSecondary;

    final other = slot == FirebaseAccountSlot.primary
        ? currentSecondary
        : currentPrimary;

    if (selected != userId) {
      return false;
    }

    // Ningún contexto ambiguo puede recibir acceso.
    if (other != null && (!_validUserId(other) || other == userId)) {
      return false;
    }

    return true;
  }

  void _invalidate() {
    _revision++;
    _selectedSlot = null;
    _selectedUserId = null;
    _verifying = false;
  }

  void _observeIdentity(FirebaseAccountSlot slot, String? userId) {
    if (_disposed) {
      return;
    }

    if (slot == FirebaseAccountSlot.primary) {
      if (_observedPrimaryUserId == userId) {
        return;
      }

      _observedPrimaryUserId = userId;
    } else {
      if (_observedSecondaryUserId == userId) {
        return;
      }

      _observedSecondaryUserId = userId;
    }

    // Una transición A -> B -> A invalida la
    // autorización desde el primer cambio.
    //
    // Recuperar posteriormente el mismo UID no
    // recupera un permiso anterior.
    _invalidate();
    notifyListeners();
  }

  /// Bloquea inmediatamente la interfaz privada.
  ///
  /// También invalida cualquier verificación
  /// que todavía esté esperando una respuesta.
  void lock() {
    if (_disposed) {
      return;
    }

    _invalidate();
    notifyListeners();
  }

  /// Solicita acceso para una identidad exacta.
  ///
  /// verifyAccess no debe provenir de un booleano
  /// controlado por la interfaz. Su implementación
  /// de producción deberá validar la autorización
  /// convencional o biométrica de la cuenta esperada.
  ///
  /// Este método no efectúa por sí mismo ninguna
  /// verificación criptográfica.
  Future<bool> select({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required Future<bool> Function() verifyAccess,
  }) async {
    if (_disposed || _verifying) {
      return false;
    }

    // Desmontar el permiso anterior antes de esperar
    // cualquier operación externa.
    _invalidate();

    if (!_matchesIdentity(slot: slot, userId: expectedUserId)) {
      notifyListeners();
      return false;
    }

    _verifying = true;

    final operationRevision = _revision;

    notifyListeners();

    var verified = false;

    try {
      verified = await verifyAccess();
    } catch (_) {
      verified = false;
    }

    // No aceptar resultados de operaciones canceladas,
    // sustituidas o completadas después de dispose().
    if (_disposed || operationRevision != _revision) {
      return false;
    }

    _verifying = false;

    if (!verified || !_matchesIdentity(slot: slot, userId: expectedUserId)) {
      notifyListeners();
      return false;
    }

    _selectedSlot = slot;
    _selectedUserId = expectedUserId;

    notifyListeners();

    return value;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _invalidate();
    _disposed = true;

    unawaited(_primarySubscription.cancel());
    unawaited(_secondarySubscription.cancel());

    super.dispose();
  }
}
