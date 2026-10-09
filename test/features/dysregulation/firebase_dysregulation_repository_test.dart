import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/data/repositories/firebase_dysregulation_repository.dart';
import 'package:sendaris/features/dysregulation/data/services/dysregulation_remote_service.dart';
import 'package:sendaris/features/dysregulation/domain/exceptions/dysregulation_failure.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';

void main() {
  group('FirebaseDysregulationRepository', () {
    late _FakeDysregulationManagementRemoteService service;

    late FirebaseDysregulationRepository repository;

    setUp(() {
      service = _FakeDysregulationManagementRemoteService();

      repository = FirebaseDysregulationRepository(service);
    });

    test('guarda un episodio mediante el servicio', () async {
      final record = _createRecord();

      await repository.saveDysregulation(record);

      expect(service.savedRecords, [record]);
    });

    test('recupera registros sin alterar sus datos', () async {
      final record = _createRecord();

      service.recordsToRecover = [record];

      final recovered = await repository.recoverDysregulations(
        anonymousId: 'anonimo-1',
      );

      expect(recovered, hasLength(1));

      expect(recovered.single.recordId, 'desregulacion-1');

      expect(recovered.single.intensity, DysregulationIntensity.medium);

      expect(recovered.single.context, 'Actividad cotidiana');
    });

    test('actualiza un registro mediante el servicio', () async {
      final record = _createRecord(updatedAt: DateTime.utc(2026, 9, 16, 20));

      await repository.updateDysregulation(record);

      expect(service.updatedRecords, [record]);
    });

    test('elimina un registro mediante el servicio', () async {
      await repository.deleteDysregulation(
        anonymousId: 'anonimo-1',
        recordId: 'desregulacion-1',
      );

      expect(service.deletedRecords, [
        (anonymousId: 'anonimo-1', recordId: 'desregulacion-1'),
      ]);
    });

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.saveDysregulation(_createRecord()),
        throwsA(
          isA<DysregulationFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Debes iniciar sesión'),
          ),
        ),
      );
    });

    test('no expone permission-denied de Firebase al guardar', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.saveDysregulation(_createRecord()),
        throwsA(
          isA<DysregulationFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para guardar '
                'este episodio de desregulación.',
          ),
        ),
      );
    });

    test('un error de red no se presenta como guardado exitoso', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(
        () => repository.saveDysregulation(_createRecord()),
        throwsA(
          isA<DysregulationFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });

    test(
      'permission-denied al actualizar se presenta como error controlado',
      () async {
        service.error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );

        expect(
          () => repository.updateDysregulation(_createRecord()),
          throwsA(
            isA<DysregulationFailure>().having(
              (failure) => failure.message,
              'message',
              'No tienes autorización para actualizar '
                  'este registro de desregulación.',
            ),
          ),
        );
      },
    );

    test(
      'un error de red al eliminar se presenta como error controlado',
      () async {
        service.error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );

        expect(
          () => repository.deleteDysregulation(
            anonymousId: 'anonimo-1',
            recordId: 'desregulacion-1',
          ),
          throwsA(
            isA<DysregulationFailure>().having(
              (failure) => failure.message,
              'message',
              'No fue posible eliminar el registro '
                  'de desregulación. '
                  'Verifica tu conexión.',
            ),
          ),
        );
      },
    );

    test(
      'un documento inválido al recuperar se presenta como error controlado',
      () async {
        service.error = const FormatException('Documento inválido');

        expect(
          () => repository.recoverDysregulations(anonymousId: 'anonimo-1'),
          throwsA(
            isA<DysregulationFailure>().having(
              (failure) => failure.message,
              'message',
              contains('No fue posible cargar'),
            ),
          ),
        );
      },
    );
  });
}

DysregulationRecord _createRecord({DateTime? updatedAt}) {
  return DysregulationRecord(
    recordId: 'desregulacion-1',
    anonymousId: 'anonimo-1',
    date: DateTime(2026, 9, 15),
    time: '14:30',
    durationMinutes: 12,
    intensity: DysregulationIntensity.medium,
    context: 'Actividad cotidiana',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 15, 20),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 15, 20),
  );
}

class _FakeDysregulationManagementRemoteService
    implements DysregulationManagementRemoteService {
  final List<DysregulationRecord> savedRecords = [];

  final List<DysregulationRecord> updatedRecords = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  List<DysregulationRecord> recordsToRecover = [];

  Object? error;

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(recordsToRecover);
  }

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));
  }
}
