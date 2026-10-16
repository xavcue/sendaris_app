import 'package:flutter/foundation.dart';

class SessionTimeoutPolicy {
  const SessionTimeoutPolicy._();

  // Solo habilitado en Debug cuando se proporciona expresamente
  // SENDARIS_SESSION_FAST_TEST=true.
  //
  // En Profile y Release siempre se aplican los límites normales.
  static const bool acceleratedDebug =
      kDebugMode &&
      bool.fromEnvironment('SENDARIS_SESSION_FAST_TEST', defaultValue: false);

  static const Duration foregroundIdle = acceleratedDebug
      ? Duration(seconds: 45)
      : Duration(minutes: 60);

  static const Duration background = acceleratedDebug
      ? Duration(minutes: 2)
      : Duration(hours: 2);

  static const Duration absolute = acceleratedDebug
      ? Duration(minutes: 5)
      : Duration(hours: 24);
}

class SessionTimeoutRecord {
  const SessionTimeoutRecord({
    required this.userId,
    required this.startedAt,
    required this.lastActivityAt,
    this.backgroundAt,
  });

  final String userId;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final DateTime? backgroundAt;

  SessionTimeoutRecord activity(DateTime now) {
    // Al volver al primer plano, se elimina la marca anterior
    // de segundo plano y se inicia un nuevo periodo de actividad.
    //
    // La fecha original de inicio NO se modifica.
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt,
      lastActivityAt: now.toUtc(),
    );
  }

  SessionTimeoutRecord backgrounded(DateTime now) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt,
      lastActivityAt: lastActivityAt,
      backgroundAt: now.toUtc(),
    );
  }

  bool isExpired(DateTime now, {bool restoring = false}) {
    final instant = now.toUtc();
    final start = startedAt.toUtc();
    final activity = lastActivityAt.toUtc();
    final background = backgroundAt?.toUtc();

    if (userId.isEmpty ||
        activity.isBefore(start) ||
        instant.isBefore(start) ||
        instant.isBefore(activity) ||
        (background != null &&
            (background.isBefore(start) || instant.isBefore(background))) ||
        (background != null && background.isBefore(activity))) {
      return true;
    }

    if (instant.difference(start) >= SessionTimeoutPolicy.absolute) {
      return true;
    }

    if (background != null) {
      return instant.difference(background) >= SessionTimeoutPolicy.background;
    }

    return instant.difference(activity) >=
        (restoring
            ? SessionTimeoutPolicy.background
            : SessionTimeoutPolicy.foregroundIdle);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'userId': userId,
    'startedAt': startedAt.toUtc().millisecondsSinceEpoch,
    'lastActivityAt': lastActivityAt.toUtc().millisecondsSinceEpoch,
    'backgroundAt': backgroundAt?.toUtc().millisecondsSinceEpoch,
  };

  factory SessionTimeoutRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['userId'] is! String ||
        json['startedAt'] is! int ||
        json['lastActivityAt'] is! int ||
        (json['backgroundAt'] != null && json['backgroundAt'] is! int)) {
      throw const FormatException('Metadatos de sesión inválidos.');
    }

    return SessionTimeoutRecord(
      userId: json['userId'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        json['startedAt'] as int,
        isUtc: true,
      ),
      lastActivityAt: DateTime.fromMillisecondsSinceEpoch(
        json['lastActivityAt'] as int,
        isUtc: true,
      ),
      backgroundAt: json['backgroundAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['backgroundAt'] as int,
              isUtc: true,
            ),
    );
  }
}
