import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/anonymous_tracking_profile.dart';

abstract final class AnonymousTrackingProfileMapper {
  static const Set<String> allowedFields = {'fechaCreacion', 'activo'};

  static Map<String, dynamic> toFirestore(AnonymousTrackingProfile profile) {
    return {
      'fechaCreacion': Timestamp.fromDate(profile.createdAt.toUtc()),
      'activo': profile.isActive,
    };
  }

  static AnonymousTrackingProfile fromFirestore({
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final createdAt = data['fechaCreacion'];
    final isActive = data['activo'];

    if (createdAt is! Timestamp) {
      throw const FormatException(
        'El perfil anónimo no contiene una fecha de creación válida.',
      );
    }

    if (isActive is! bool) {
      throw const FormatException(
        'El perfil anónimo no contiene un estado válido.',
      );
    }

    return AnonymousTrackingProfile(
      anonymousId: anonymousId,
      createdAt: createdAt.toDate().toUtc(),
      isActive: isActive,
    );
  }
}
