abstract final class TrackingFirestorePaths {
  static String userDocument(String uid) {
    _validateSegment(uid, 'uid');

    return 'usuarios/$uid';
  }

  static String anonymousTrackingCollection(String uid) {
    return '${userDocument(uid)}/seguimientos';
  }

  static String anonymousTrackingDocument({
    required String uid,
    required String anonymousId,
  }) {
    _validateSegment(anonymousId, 'anonymousId');

    return '${anonymousTrackingCollection(uid)}/$anonymousId';
  }

  static void _validateSegment(String value, String name) {
    if (value.trim().isEmpty || value.contains('/')) {
      throw ArgumentError.value(
        value,
        name,
        'Debe ser un segmento válido de una ruta Firestore.',
      );
    }
  }
}
