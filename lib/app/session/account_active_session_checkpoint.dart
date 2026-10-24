import 'dart:convert';

import 'account_scoped_session_timeout_store.dart';
import 'biometric_binding_policy.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Identifica la ultima cuenta privada seleccionada
/// antes de que terminara el proceso de Sendaris.
///
/// No contiene contrasenas, tokens ni autorizaciones.
final class AccountActiveSessionCheckpoint {
  const AccountActiveSessionCheckpoint({
    required this.slot,
    required this.userId,
  });

  final FirebaseAccountSlot slot;
  final String userId;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'slot': slot.name,
    'userId': userId,
  };

  factory AccountActiveSessionCheckpoint.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['slot'] is! String ||
        json['userId'] is! String) {
      throw const FormatException('Punto de restauracion invalido.');
    }

    final slot = switch (json['slot']) {
      'primary' => FirebaseAccountSlot.primary,
      'secondary' => FirebaseAccountSlot.secondary,
      _ => throw const FormatException('Contexto Firebase desconocido.'),
    };

    final userId = json['userId'] as String;

    if (userId.isEmpty || userId.trim() != userId) {
      throw const FormatException('Identidad de restauracion invalida.');
    }

    return AccountActiveSessionCheckpoint(slot: slot, userId: userId);
  }
}

/// Guarda solamente la identidad de la ultima
/// cuenta activa en esta instalacion.
///
/// Las claves temporales de A y B se mantienen
/// independientes mediante AccountScopedSessionTimeoutStore.
///
/// El cierre manual debera borrar este punto de
/// restauracion antes de considerar completado
/// el cierre de acceso.
///
/// Ningun resultado de read() autoriza rutas privadas.
final class AccountActiveSessionCheckpointStore {
  AccountActiveSessionCheckpointStore({AccountSessionKeyValueStorage? storage})
    : _storage = storage ?? SharedPreferencesAccountSessionStorage();

  static const String _storageKey = 'sendaris.session.dual.active.v1';

  final AccountSessionKeyValueStorage _storage;

  Future<AccountActiveSessionCheckpoint?> read() async {
    final encoded = await _storage.getString(_storageKey);

    if (encoded == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return AccountActiveSessionCheckpoint.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AccountActiveSessionCheckpoint checkpoint) {
    if (checkpoint.userId.isEmpty ||
        checkpoint.userId.trim() != checkpoint.userId) {
      throw ArgumentError.value(
        checkpoint.userId,
        'checkpoint.userId',
        'La identidad activa no es valida.',
      );
    }

    return _storage.setString(_storageKey, jsonEncode(checkpoint.toJson()));
  }

  Future<void> clear() {
    return _storage.remove(_storageKey);
  }
}

/// Resultado de la evaluacion inicial del reinicio.
///
/// Ninguno de estos resultados, por si solo,
/// concede acceso privado.
///
/// restoreConventional:
/// El contexto convencional tiene metadatos
/// compatibles con una restauracion. La raiz
/// todavia debe confirmar Firebase y el timeout.
///
/// requireLinkedAuthorization:
/// Existe una cuenta vinculada coherente, pero
/// falta la autorizacion segura correspondiente.
///
/// requireSignIn:
/// No hay un candidato valido para continuar.
///
/// denyAccess:
/// Se detecto una configuracion ambigua o insegura.
enum AccountSessionResumeDecision {
  requireSignIn,
  restoreConventional,
  requireLinkedAuthorization,
  denyAccess,
}

/// Evalua los metadatos de restauracion de A y B.
///
/// No crea sesiones, no ejecuta operaciones
/// de Firebase, no solicita huellas y no cambia
/// AccountSessionSelectionController.
///
/// La autorizacion final siempre corresponde
/// a los coordinadores de autenticacion.
abstract final class AccountActiveSessionRestorationPolicy {
  static bool _validUserId(String? value) {
    return value != null && value.isNotEmpty && value.trim() == value;
  }

  static AccountSessionResumeDecision decide({
    required AccountActiveSessionCheckpoint? checkpoint,
    required SessionTimeoutRecord? primaryRecord,
    required SessionTimeoutRecord? secondaryRecord,
    required String? primaryFirebaseUserId,
    required String? secondaryFirebaseUserId,
    required BiometricBindingState binding,
    required DateTime now,
  }) {
    if (binding is BiometricBindingUnavailable) {
      return AccountSessionResumeDecision.denyAccess;
    }

    if (primaryFirebaseUserId != null && !_validUserId(primaryFirebaseUserId)) {
      return AccountSessionResumeDecision.denyAccess;
    }

    if (secondaryFirebaseUserId != null &&
        !_validUserId(secondaryFirebaseUserId)) {
      return AccountSessionResumeDecision.denyAccess;
    }

    // Una misma identidad presente simultaneamente
    // en dos contextos no puede restaurarse.
    if (primaryFirebaseUserId != null &&
        primaryFirebaseUserId == secondaryFirebaseUserId) {
      return AccountSessionResumeDecision.denyAccess;
    }

    if (checkpoint == null) {
      return AccountSessionResumeDecision.requireSignIn;
    }

    if (!_validUserId(checkpoint.userId)) {
      return AccountSessionResumeDecision.denyAccess;
    }

    final selectedUserId = switch (checkpoint.slot) {
      FirebaseAccountSlot.primary => primaryFirebaseUserId,
      FirebaseAccountSlot.secondary => secondaryFirebaseUserId,
    };

    final otherUserId = switch (checkpoint.slot) {
      FirebaseAccountSlot.primary => secondaryFirebaseUserId,
      FirebaseAccountSlot.secondary => primaryFirebaseUserId,
    };

    final selectedRecord = switch (checkpoint.slot) {
      FirebaseAccountSlot.primary => primaryRecord,
      FirebaseAccountSlot.secondary => secondaryRecord,
    };

    // La cuenta activa guardada debe seguir
    // correspondiendo a la identidad Firebase
    // del mismo contexto.
    if (selectedUserId != checkpoint.userId) {
      return AccountSessionResumeDecision.requireSignIn;
    }

    // Tener un registro temporal no basta.
    // Debe coincidir el UID y mantenerse vigente.
    final eligible = AccountSessionRestorationCandidatePolicy.isEligible(
      record: selectedRecord,
      authenticatedUserId: selectedUserId,
      now: now,
    );

    if (!eligible) {
      return AccountSessionResumeDecision.requireSignIn;
    }

    // Sin vinculacion, solo PRIMARY es el contexto
    // convencional admitido por la configuracion dual.
    if (binding is BiometricBindingDisabled) {
      if (checkpoint.slot != FirebaseAccountSlot.primary ||
          otherUserId != null) {
        return AccountSessionResumeDecision.denyAccess;
      }

      return AccountSessionResumeDecision.restoreConventional;
    }

    if (binding is! BiometricBindingEnabled || !_validUserId(binding.userId)) {
      return AccountSessionResumeDecision.denyAccess;
    }

    final linkedUserId = binding.userId;

    final linkedOnPrimary = primaryFirebaseUserId == linkedUserId;

    final linkedOnSecondary = secondaryFirebaseUserId == linkedUserId;

    // No se autoriza otra cuenta mientras el
    // contexto vinculado no pueda identificarse.
    // La raiz decidira si corresponde ofrecer
    // la recuperacion segura de la cuenta A.
    if (linkedOnPrimary == linkedOnSecondary) {
      return AccountSessionResumeDecision.denyAccess;
    }

    // El ultimo acceso pertenecia a A.
    //
    // Su registro temporal puede ser valido,
    // pero no constituye una prueba criptografica.
    // La restauracion debe pasar por el mecanismo
    // seguro que se integre posteriormente.
    if (checkpoint.userId == linkedUserId) {
      return AccountSessionResumeDecision.requireLinkedAuthorization;
    }

    // El ultimo acceso era convencional.
    // El contexto opuesto debe corresponder
    // precisamente a la cuenta vinculada.
    if (otherUserId != linkedUserId) {
      return AccountSessionResumeDecision.denyAccess;
    }

    return AccountSessionResumeDecision.restoreConventional;
  }
}
