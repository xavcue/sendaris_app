import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/data/repositories/firebase_behavior_repository.dart';
import 'package:sendaris/features/behavior/data/services/behavior_remote_service.dart';
import 'package:sendaris/features/behavior/domain/exceptions/behavior_failure.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';

void main() {
  group('FirebaseBehaviorRepository', () {
    late _FakeBehaviorRemoteService service;

    late FirebaseBehaviorRepository repository;

    setUp(() {
      service = _FakeBehaviorRemoteService();

      repository = FirebaseBehaviorRepository(service);
    });

    test('guarda una conducta mediante el servicio remoto', () async {
      final record = _createRecord();

      await repository.saveBehavior(record);

      expect(service.savedRecords, [record]);
    });

    test('recupera conductas sin alterar los datos', () async {
      final record = _createRecord();

      service.recordsToRecover = [record];

      final recovered = await repository.recoverBehaviors(
        anonymousId: 'anonimo-1',
      );

      expect(recovered.length, 1);

      expect(recovered.first.recordId, record.recordId);

      expect(recovered.first.category, record.category);
    });

    test('actualiza una conducta mediante el servicio remoto', () async {
      final record = _createRecord(updatedAt: DateTime.utc(2026, 9, 6, 18));

      await repository.updateBehavior(record);

      expect(service.updatedRecords, [record]);
    });

    test(
      'elimina la conducta solicitada mediante el servicio remoto',
      () async {
        await repository.deleteBehavior(
          anonymousId: 'anonimo-1',
          recordId: 'registro-1',
        );

        expect(service.deletedRecords, [
          (anonymousId: 'anonimo-1', recordId: 'registro-1'),
        ]);
      },
    );

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.saveBehavior(_createRecord()),
        throwsA(
          isA<BehaviorFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Debes iniciar sesión'),
          ),
        ),
      );
    });

    test('no expone permission-denied al guardar', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.saveBehavior(_createRecord()),
        throwsA(
          isA<BehaviorFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para guardar esta conducta.',
          ),
        ),
      );
    });

    test('no expone permission-denied al actualizar', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.updateBehavior(_createRecord()),
        throwsA(
          isA<BehaviorFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para actualizar esta conducta.',
          ),
        ),
      );
    });

    test('no expone permission-denied al eliminar', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.deleteBehavior(
          anonymousId: 'anonimo-1',
          recordId: 'registro-1',
        ),
        throwsA(
          isA<BehaviorFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para eliminar esta conducta.',
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
        () => repository.saveBehavior(_createRecord()),
        throwsA(
          isA<BehaviorFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });
  });
}

BehaviorRecord _createRecord({DateTime? updatedAt}) {
  return BehaviorRecord(
    recordId: 'registro-1',
    anonymousId: 'anonimo-1',
    date: DateTime(2026, 9, 5),
    category: BehaviorCategory.repetitiveBehavior,
    createdAt: DateTime.utc(2026, 9, 5, 18),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 5, 18),
  );
}

class _FakeBehaviorRemoteService implements BehaviorManagementRemoteService {
  final List<BehaviorRecord> savedRecords = [];

  final List<BehaviorRecord> updatedRecords = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  List<BehaviorRecord> recordsToRecover = [];

  Object? error;

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    _throwIfNeeded();

    savedRecords.add(record);
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    _throwIfNeeded();

    return List.unmodifiable(recordsToRecover);
  }

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {
    _throwIfNeeded();

    updatedRecords.add(record);
  }

  @override
  Future<void> deleteBehavior({
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
