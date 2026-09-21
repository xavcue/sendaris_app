import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/anonymous_tracking_profile.dart';

abstract final class AnonymousTrackingProfileMapper {
  static const Set<String> allowedFields = {
    'fechaCreacion',
    'activo',
    'numeroSeguimiento',
  };

  static Map<String, dynamic> toFirestore(AnonymousTrackingProfile profile) {
    final data = <String, dynamic>{
      'fechaCreacion': Timestamp.fromDate(profile.createdAt.toUtc()),
      'activo': profile.isActive,
    };

    final trackingNumber = profile.trackingNumber;

    if (trackingNumber != null) {
      data['numeroSeguimiento'] = trackingNumber;
    }

    return data;
  }

  static AnonymousTrackingProfile fromFirestore({
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final createdAt = data['fechaCreacion'];
    final isActive = data['activo'];
    final trackingNumber = data['numeroSeguimiento'];

    if (createdAt is! Timestamp) {
      throw const FormatException(
        'El seguimiento anónimo no contiene una fecha de creación válida.',
      );
    }

    if (isActive is! bool) {
      throw const FormatException(
        'El seguimiento anónimo no contiene un estado válido.',
      );
    }

    if (trackingNumber != null &&
        (trackingNumber is! int || trackingNumber <= 0)) {
      throw const FormatException(
        'El seguimiento anónimo contiene un número inválido.',
      );
    }

    return AnonymousTrackingProfile(
      anonymousId: anonymousId,
      createdAt: createdAt.toDate().toUtc(),
      trackingNumber: trackingNumber as int?,
      isActive: isActive,
    );
  }
}
