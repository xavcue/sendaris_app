import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/firestore/tracking_firestore_paths.dart';

void main() {
  group('TrackingFirestorePaths', () {
    test('construye la ruta del perfil anónimo según el diseño OE2', () {
      const uid = 'usuarioFirebase123';
      const anonymousId = '550e8400-e29b-41d4-a716-446655440000';

      final path = TrackingFirestorePaths.anonymousTrackingDocument(
        uid: uid,
        anonymousId: anonymousId,
      );

      expect(path, 'usuarios/$uid/seguimientos/$anonymousId');
    });

    test('rechaza un identificador anónimo vacío', () {
      expect(
        () => TrackingFirestorePaths.anonymousTrackingDocument(
          uid: 'usuarioFirebase123',
          anonymousId: '',
        ),
        throwsArgumentError,
      );
    });

    test('rechaza segmentos que alteren la ruta Firestore', () {
      expect(
        () => TrackingFirestorePaths.anonymousTrackingDocument(
          uid: 'usuarioFirebase123',
          anonymousId: 'perfil/otro',
        ),
        throwsArgumentError,
      );
    });
  });
}
