import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/data/repositories/firebase_feeding_repository.dart';
import 'package:sendaris/features/feeding/data/services/feeding_remote_service.dart';
import 'package:sendaris/features/feeding/domain/exceptions/feeding_failure.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';

void main() {
  group('FirebaseFeedingRepository', () {
    late _FakeFeedingRemoteService service;
    late FirebaseFeedingRepository repository;

    setUp(() {
      service = _FakeFeedingRemoteService();

      repository = FirebaseFeedingRepository(service);
    });

    test('guarda un registro mediante el servicio', () async {
      final record = _createRecord();

      await repository.saveFeeding(record);

      expect(service.savedRecords, [record]);
    });

    test('recupera registros sin alterar sus datos', () async {
      final record = _createRecord();

      service.recordsToRecover = [record];

      final recovered = await repository.recoverFeedingRecords(
        anonymousId: 'anonimo-1',
      );

      expect(recovered, hasLength(1));

      expect(recovered.single.recordId, 'alimentacion-1');

      expect(recovered.single.category, FeedingCategory.lunch);
    });

    test('actualiza un registro mediante el servicio', () async {
      final record = _createRecord(updatedAt: DateTime.utc(2026, 9, 11, 20));

      await repository.updateFeeding(record);

      expect(service.updatedRecords, [record]);
    });

    test(
      'elimina físicamente el registro indicado mediante el servicio',
      () async {
        await repository.deleteFeeding(
          anonymousId: 'anonimo-1',
          recordId: 'alimentacion-1',
        );

        expect(service.deletedRecords, [
          (anonymousId: 'anonimo-1', recordId: 'alimentacion-1'),
        ]);
      },
    );

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.saveFeeding(_createRecord()),
        throwsA(
          isA<FeedingFailure>().having(
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
        () => repository.saveFeeding(_createRecord()),
        throwsA(
          isA<FeedingFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para guardar '
                'este registro de alimentación.',
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
        () => repository.saveFeeding(_createRecord()),
        throwsA(
          isA<FeedingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });

    test('no expone permission-denied de Firebase al actualizar', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.updateFeeding(_createRecord()),
        throwsA(
          isA<FeedingFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para actualizar '
                'este registro de alimentación.',
          ),
        ),
      );

      expect(service.updatedRecords, isEmpty);
    });

    test('un error de red no se presenta como eliminación exitosa', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(
        () => repository.deleteFeeding(
          anonymousId: 'anonimo-1',
          recordId: 'alimentacion-1',
        ),
        throwsA(
          isA<FeedingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );

      expect(service.deletedRecords, isEmpty);
    });
  });
}

FeedingRecord _createRecord({DateTime? updatedAt}) {
  return FeedingRecord(
    recordId: 'alimentacion-1',
    anonymousId: 'anonimo-1',
    date: DateTime(2026, 9, 10),
    category: FeedingCategory.lunch,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 10, 20),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 10, 20),
  );
}

class _FakeFeedingRemoteService implements FeedingManagementRemoteService {
  final List<FeedingRecord> savedRecords = [];
  final List<FeedingRecord> updatedRecords = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  List<FeedingRecord> recordsToRecover = [];

  Object? error;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    _throwIfNeeded();

    savedRecords.add(record);
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    _throwIfNeeded();

    return List.unmodifiable(recordsToRecover);
  }

  @override
  Future<void> updateFeeding(FeedingRecord record) async {
    _throwIfNeeded();

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {
    _throwIfNeeded();

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));
  }

  void _throwIfNeeded() {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }
  }
}
