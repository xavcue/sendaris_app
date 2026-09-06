import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/firestore/tracking_firestore_paths.dart';

void main() {
  group('TrackingFirestorePaths - rutinas', () {
    test('construye la colección de rutinas según OE2', () {
      final path = TrackingFirestorePaths.routinesCollection(
        uid: 'usuario-a',
        anonymousId: 'anonimo-1',
      );

      expect(path, 'usuarios/usuario-a/seguimientos/anonimo-1/rutinas');
    });

    test('construye el documento de rutina', () {
      final path = TrackingFirestorePaths.routineDocument(
        uid: 'usuario-a',
        anonymousId: 'anonimo-1',
        routineId: 'rutina-1',
      );

      expect(
        path,
        'usuarios/usuario-a/seguimientos/anonimo-1/rutinas/rutina-1',
      );
    });

    test('rechaza un identificador de rutina inválido', () {
      expect(
        () => TrackingFirestorePaths.routineDocument(
          uid: 'usuario-a',
          anonymousId: 'anonimo-1',
          routineId: 'rutinas/invalida',
        ),
        throwsArgumentError,
      );
    });
  });
}
