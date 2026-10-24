import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';
import 'session_timeout_store.dart';

/// Contrato mínimo del almacenamiento persistente.
///
/// Permite probar la separación entre contextos
/// sin inicializar Firebase ni el almacenamiento nativo.
abstract interface class AccountSessionKeyValueStorage {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

/// Adaptador de almacenamiento local para Android.
///
/// Solo almacena metadatos de tiempo e identidad.
/// No almacena credenciales, tokens ni permisos privados.
final class SharedPreferencesAccountSessionStorage
    implements AccountSessionKeyValueStorage {
  SharedPreferencesAccountSessionStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) {
    return _preferences.getString(key);
  }

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) {
    return _preferences.remove(key);
  }
}

/// Almacena los tiempos de sesión de un contexto Firebase.
///
/// PRIMARY y SECONDARY tienen claves persistentes distintas.
/// La eliminación de una no afecta a la otra.
///
/// El componente implementa SessionTimeoutStore para poder
/// reutilizar los adaptadores de serialización y confirmación
/// existentes en Sendaris.
///
/// Las operaciones concurrentes de un mismo contexto deberán
/// compartir una instancia de AcknowledgedSessionTimeoutStore
/// que envuelva este almacenamiento.
///
/// Leer un registro NO concede acceso privado.
final class AccountScopedSessionTimeoutStore implements SessionTimeoutStore {
  AccountScopedSessionTimeoutStore({
    required this.slot,
    AccountSessionKeyValueStorage? storage,
  }) : _storage = storage ?? SharedPreferencesAccountSessionStorage();

  final FirebaseAccountSlot slot;
  final AccountSessionKeyValueStorage _storage;

  static const String _primaryKey = 'sendaris.session.dual.primary.v1';

  static const String _secondaryKey = 'sendaris.session.dual.secondary.v1';

  String get _storageKey => switch (slot) {
    FirebaseAccountSlot.primary => _primaryKey,
    FirebaseAccountSlot.secondary => _secondaryKey,
  };

  @override
  Future<SessionTimeoutRecord?> read() async {
    final encoded = await _storage.getString(_storageKey);

    if (encoded == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return SessionTimeoutRecord.fromJson(decoded);
    } catch (_) {
      // Un registro corrupto nunca permite
      // recuperar una autorización privada.
      return null;
    }
  }

  @override
  Future<void> write(SessionTimeoutRecord record) {
    final userId = record.userId;

    if (userId.isEmpty || userId.trim() != userId) {
      throw ArgumentError.value(
        userId,
        'record.userId',
        'El identificador de sesión no es válido.',
      );
    }

    return _storage.setString(_storageKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() {
    return _storage.remove(_storageKey);
  }
}

/// Evalúa exclusivamente si los metadatos temporales
/// pueden participar en un intento de restauración.
///
/// La fecha persistida NO es una autorización.
///
/// Antes de abrir contenido privado, el componente raíz
/// también debe comprobar:
///
/// - La sesión Firebase correspondiente.
/// - La identidad real y su contexto.
/// - La vinculación de huella, cuando corresponda.
/// - La autorización privada exigida por el sistema.
///
/// No utiliza el plazo ampliado de restauración cuando
/// falta backgroundAt: un registro en primer plano
/// debe respetar sus 60 minutos de inactividad.
abstract final class AccountSessionRestorationCandidatePolicy {
  static bool isEligible({
    required SessionTimeoutRecord? record,
    required String? authenticatedUserId,
    required DateTime now,
  }) {
    if (record == null ||
        authenticatedUserId == null ||
        authenticatedUserId.isEmpty ||
        authenticatedUserId.trim() != authenticatedUserId ||
        record.userId != authenticatedUserId) {
      return false;
    }

    return !record.isExpired(now.toUtc());
  }
}
