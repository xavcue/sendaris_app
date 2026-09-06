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

  static String trackingRecordsCollection({
    required String uid,
    required String anonymousId,
  }) {
    return '${anonymousTrackingDocument(uid: uid, anonymousId: anonymousId)}/registros';
  }

  static String trackingRecordDocument({
    required String uid,
    required String anonymousId,
    required String recordId,
  }) {
    _validateSegment(recordId, 'recordId');

    return '${trackingRecordsCollection(uid: uid, anonymousId: anonymousId)}/$recordId';
  }

  static String routinesCollection({
    required String uid,
    required String anonymousId,
  }) {
    return '${anonymousTrackingDocument(uid: uid, anonymousId: anonymousId)}/rutinas';
  }

  static String routineDocument({
    required String uid,
    required String anonymousId,
    required String routineId,
  }) {
    _validateSegment(routineId, 'routineId');

    return '${routinesCollection(uid: uid, anonymousId: anonymousId)}/$routineId';
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
