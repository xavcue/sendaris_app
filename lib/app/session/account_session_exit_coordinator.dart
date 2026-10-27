import '../../features/auth/domain/repositories/auth_repository.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';

/// Operaciones necesarias para cerrar una sesion convencional.
///
/// El objetivo debe pertenecer al contexto Firebase
/// autorizado y proteger signOut frente a cambios de
/// identidad.
abstract interface class AccountSessionExitTarget {
  String? get currentUserId;

  Future<void> signOut();
}

/// Adaptador para los repositorios Firebase de Sendaris.
///
/// Utiliza el signOut del repositorio existente.
final class FirebaseAccountSessionExitTarget
    implements AccountSessionExitTarget {
  FirebaseAccountSessionExitTarget(AuthRepository repository)
    : _repository = repository {
    if (repository is! AuthIdentityRepository) {
      throw ArgumentError('El repositorio debe exponer la identidad Firebase.');
    }
  }

  final AuthRepository _repository;

  @override
  String? get currentUserId =>
      (_repository as AuthIdentityRepository).currentUserId;

  @override
  Future<void> signOut() => _repository.signOut();
}

/// Operacion opcional para invalidar la persistencia
/// antes de completar un cierre de sesion.
///
/// Debe terminar solamente cuando la eliminacion
/// haya sido confirmada por el almacenamiento.
///
/// Si falla, debe lanzar una excepcion.
/// El coordinador mantendra bloqueado el acceso
/// privado y no desconectara otra identidad.
typedef AccountSessionBeforeExit = Future<void> Function(
  FirebaseAccountSlot slot,
  String userId,
);

/// Gestiona el cierre de la cuenta actualmente
/// autorizada para mostrar contenido privado.
///
/// Cuenta vinculada:
/// - Revoca el acceso privado.
/// - Elimina su restauracion persistente, si se configura.
/// - Conserva la sesion Firebase.
/// - Conserva la vinculacion de Android.
///
/// Cuenta convencional:
/// - Revoca el acceso privado.
/// - Elimina su restauracion persistente, si se configura.
/// - Desconecta solamente su contexto Firebase.
///
/// Ninguna operacion elimina seguimientos, documentos
/// Firestore ni vinculaciones de huella o reconocimiento
/// facial.
///
/// Las comprobaciones de identidad se realizan tanto
/// antes como despues de la invalidacion persistente.
final class AccountSessionExitCoordinator {
  /// Conserva la compatibilidad con los consumidores
  /// anteriores y permite incorporar la persistencia
  /// de AUTH-03 mediante un callback opcional.
  factory AccountSessionExitCoordinator({
    required AccountSessionSelectionController selection,
    required FirebaseAccountSlot? linkedSlot,
    required AccountSessionExitTarget primary,
    required AccountSessionExitTarget secondary,
    AccountSessionBeforeExit? beforeExit,
  }) {
    return AccountSessionExitCoordinator._(
      selection,
      linkedSlot,
      primary,
      secondary,
      beforeExit,
    );
  }

  AccountSessionExitCoordinator._(
    this.selection,
    this._linkedSlot,
    this.primary,
    this.secondary,
    this._beforeExit,
  );

  final AccountSessionSelectionController selection;
  final AccountSessionExitTarget primary;
  final AccountSessionExitTarget secondary;

  final AccountSessionBeforeExit? _beforeExit;

  FirebaseAccountSlot? _linkedSlot;

  bool _busy = false;
  bool _disposed = false;

  bool get isBusy => !_disposed && _busy;

  FirebaseAccountSlot? get linkedSlot => _linkedSlot;

  /// Actualiza la cuenta reservada sin revocar
  /// la autorizacion vigente.
  ///
  /// Solo debe invocarlo la raiz despues de comprobar
  /// la identidad Firebase y el estado persistido
  /// de Android Keystore.
  ///
  /// No puede realizarse durante un cierre en curso.
  void configureLinkedSlot(FirebaseAccountSlot? linkedSlot) {
    if (_disposed || _busy) {
      throw StateError(
        'No se puede modificar la vinculacion '
        'durante un cierre de sesion.',
      );
    }

    _linkedSlot = linkedSlot;
  }

  AccountSessionExitTarget _targetFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primary,
      FirebaseAccountSlot.secondary => secondary,
    };
  }

  bool _validUid(String? userId) {
    return userId != null && userId.isNotEmpty && userId.trim() == userId;
  }

  /// Cierra la identidad privada actualmente seleccionada.
  ///
  /// Orden obligatorio:
  ///
  /// 1. Capturar contexto e identidad autorizados.
  /// 2. Bloquear inmediatamente el acceso privado.
  /// 3. Confirmar que Firebase sigue identificando
  ///    exactamente al usuario capturado.
  /// 4. Invalidar la persistencia, si esta configurada.
  /// 5. Volver a comprobar la identidad.
  /// 6. Conservar Firebase para A vinculada o ejecutar
  ///    signOut para la cuenta convencional.
  ///
  /// El callback beforeExit debe utilizar una cola
  /// serializada que incluya escrituras anteriores.
  ///
  /// Si la invalidacion persistente falla, el metodo
  /// no informa un cierre exitoso.
  Future<bool> closeActiveSession() async {
    if (_disposed || _busy) {
      return false;
    }

    final slot = selection.selectedSlot;
    final expectedUserId = selection.selectedUserId;

    if (!selection.value || slot == null || !_validUid(expectedUserId)) {
      selection.lock();
      return false;
    }

    final target = _targetFor(slot);

    // La vinculacion no puede cambiar durante
    // esta operacion de cierre.
    final linkedSlotAtStart = _linkedSlot;

    _busy = true;

    // Revocacion sincrona antes de cualquier await.
    // El contenido privado debe desmontarse de inmediato.
    selection.lock();

    try {
      if (_disposed || target.currentUserId != expectedUserId) {
        return false;
      }

      final beforeExit = _beforeExit;

      if (beforeExit != null) {
        // AccountSessionPersistenceJournal.revoke()
        // mantiene el orden respecto de escrituras
        // de sesion anteriores.
        await beforeExit(slot, expectedUserId!);
      }

      // La identidad podria cambiar mientras se
      // espera una operacion de almacenamiento.
      //
      // Nunca desconectar una identidad diferente
      // de la que solicito cerrar sesion.
      if (_disposed || target.currentUserId != expectedUserId) {
        return false;
      }

      if (slot == linkedSlotAtStart) {
        // La cuenta vinculada conserva Firebase.
        // El cierre afecta solo al acceso privado
        // y a la vigencia persistida.
        return true;
      }

      // La cuenta convencional desconecta
      // exclusivamente su propio contexto Firebase.
      await target.signOut();

      if (_disposed) {
        return false;
      }

      return target.currentUserId == null;
    } catch (_) {
      // Una falla en almacenamiento o Firebase
      // nunca devuelve el permiso privado.
      //
      // La pantalla permanece bloqueada.
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Bloquea el acceso privado sin ejecutar
  /// operaciones Firebase.
  ///
  /// No equivale al cierre persistente completo:
  /// el componente raiz debe revocar tambien
  /// los registros cuando corresponda.
  void lock() {
    if (_disposed) {
      return;
    }

    selection.lock();
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    selection.lock();
  }
}
