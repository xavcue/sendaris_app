abstract final class TrackingObservationSnapshotPolicy {
  static bool shouldEmit({
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    // Las instantáneas de caché pueden estar desactualizadas.
    // Las escrituras pendientes todavía no están confirmadas.
    return !isFromCache && !hasPendingWrites;
  }
}
