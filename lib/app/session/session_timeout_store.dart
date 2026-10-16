import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'session_timeout_policy.dart';

abstract interface class SessionTimeoutStore {
  Future<SessionTimeoutRecord?> read();

  Future<void> write(SessionTimeoutRecord record);

  Future<void> clear();
}

class PreferencesSessionTimeoutStore implements SessionTimeoutStore {
  PreferencesSessionTimeoutStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'sendaris.session.timeout.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<SessionTimeoutRecord?> read() async {
    final encoded = await _preferences.getString(_storageKey);

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
      // Los metadatos corruptos nunca habilitan una sesión.
      return null;
    }
  }

  @override
  Future<void> write(SessionTimeoutRecord record) {
    return _preferences.setString(_storageKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_storageKey);
  }
}

class SessionTimeoutBootstrap {
  const SessionTimeoutBootstrap._();

  static Future<SessionTimeoutRecord?> prepare({
    required AuthRepository repository,
    required SessionTimeoutStore store,
    DateTime Function()? now,
  }) async {
    final currentTime = (now ?? DateTime.now)();

    if (!repository.isAuthenticated) {
      await store.clear();
      return null;
    }

    // AuthRepository no define currentUserId.
    // La identidad es una capacidad adicional.
    final String? userId;

    if (repository is AuthIdentityRepository) {
      final identityRepository = repository as AuthIdentityRepository;
      userId = identityRepository.currentUserId;
    } else {
      userId = null;
    }

    final record = await store.read();

    final valid =
        userId != null &&
        userId.isNotEmpty &&
        record != null &&
        record.userId == userId &&
        !record.isExpired(currentTime, restoring: true);

    if (!valid) {
      // No se crea una sesión temporal artificial para cuentas
      // restauradas que carecen de metadatos fiables.
      //
      // Si falla el cierre, se propaga el error para impedir
      // que la aplicación construya una interfaz privada.
      await repository.signOut();
      await store.clear();
      return null;
    }

    return record;
  }
}
