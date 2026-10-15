import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/services/tracking_observation_snapshot_policy.dart';

void main() {
  group('TrackingObservationSnapshotPolicy', () {
    test('acepta datos del servidor sin escrituras pendientes', () {
      final result = TrackingObservationSnapshotPolicy.shouldEmit(
        isFromCache: false,
        hasPendingWrites: false,
      );

      expect(result, isTrue);
    });

    test('descarta datos de caché sin escrituras pendientes', () {
      final result = TrackingObservationSnapshotPolicy.shouldEmit(
        isFromCache: true,
        hasPendingWrites: false,
      );

      expect(result, isFalse);
    });

    test('descarta datos con escrituras locales pendientes', () {
      final result = TrackingObservationSnapshotPolicy.shouldEmit(
        isFromCache: false,
        hasPendingWrites: true,
      );

      expect(result, isFalse);
    });

    test('descarta datos de caché con escrituras pendientes', () {
      final result = TrackingObservationSnapshotPolicy.shouldEmit(
        isFromCache: true,
        hasPendingWrites: true,
      );

      expect(result, isFalse);
    });
  });
}
