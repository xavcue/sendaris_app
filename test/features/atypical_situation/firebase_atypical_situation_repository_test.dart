import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/data/repositories/firebase_atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/data/services/atypical_situation_remote_service.dart';
import 'package:sendaris/features/atypical_situation/domain/exceptions/atypical_situation_failure.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';

void main() {
  group('FirebaseAtypicalSituationRepository', () {
    final record = AtypicalSituationRecord(
      recordId: 'registro-test',
      anonymousId: 'anonimo-test',
      date: DateTime(2026, 9, 6),
      category: AtypicalSituationCategory.unexpectedEvent,
      observation: 'Se suspendió una actividad programada.',
      createdAt: DateTime.utc(2026, 9, 6),
      updatedAt: DateTime.utc(2026, 9, 6),
    );

    test('delega el guardado al servicio remoto', () async {
      final service = _FakeAtypicalSituationManagementRemoteService();

      final repository = FirebaseAtypicalSituationRepository(service);

      await repository.saveAtypicalSituation(record);

      expect(service.savedRecord, same(record));
    });

    test('recupera situaciones del servicio remoto', () async {
      final service = _FakeAtypicalSituationManagementRemoteService(
        recoveredRecords: [record],
      );

      final repository = FirebaseAtypicalSituationRepository(service);

      final result = await repository.recoverAtypicalSituations(
        anonymousId: 'anonimo-test',
      );

      expect(result, hasLength(1));

      expect(result.single, same(record));
    });

    test('envía el identificador del seguimiento en la recuperación', () async {
      final service = _FakeAtypicalSituationManagementRemoteService();

      final repository = FirebaseAtypicalSituationRepository(service);

      await repository.recoverAtypicalSituations(anonymousId: 'anonimo-test');

      expect(service.recoveredAnonymousId, 'anonimo-test');
    });

    test('delega la actualización al servicio remoto', () async {
      final service = _FakeAtypicalSituationManagementRemoteService();

      final repository = FirebaseAtypicalSituationRepository(service);

      await repository.updateAtypicalSituation(record);

      expect(service.updatedRecord, same(record));
    });

    test(
      'delega la eliminación con seguimiento y registro correctos',
      () async {
        final service = _FakeAtypicalSituationManagementRemoteService();

        final repository = FirebaseAtypicalSituationRepository(service);

        await repository.deleteAtypicalSituation(
          anonymousId: 'anonimo-test',
          recordId: 'registro-test',
        );

        expect(service.deletedAnonymousId, 'anonimo-test');

        expect(service.deletedRecordId, 'registro-test');
      },
    );

    test('presenta un error controlado al actualizar sin sesión', () async {
      final service = _FakeAtypicalSituationManagementRemoteService()
        ..updateError = StateError('sin sesión');

      final repository = FirebaseAtypicalSituationRepository(service);

      expect(
        () => repository.updateAtypicalSituation(record),
        throwsA(
          isA<AtypicalSituationFailure>().having(
            (failure) => failure.message,
            'message',
            'Debes iniciar sesión antes de actualizar la situación.',
          ),
        ),
      );
    });

    test('presenta un error controlado al eliminar sin sesión', () async {
      final service = _FakeAtypicalSituationManagementRemoteService()
        ..deleteError = StateError('sin sesión');

      final repository = FirebaseAtypicalSituationRepository(service);

      expect(
        () => repository.deleteAtypicalSituation(
          anonymousId: 'anonimo-test',
          recordId: 'registro-test',
        ),
        throwsA(
          isA<AtypicalSituationFailure>().having(
            (failure) => failure.message,
            'message',
            'Debes iniciar sesión antes de eliminar la situación.',
          ),
        ),
      );
    });

    test('traduce permission-denied al actualizar', () async {
      final service = _FakeAtypicalSituationManagementRemoteService()
        ..updateError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );

      final repository = FirebaseAtypicalSituationRepository(service);

      expect(
        () => repository.updateAtypicalSituation(record),
        throwsA(
          isA<AtypicalSituationFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para actualizar esta situación.',
          ),
        ),
      );
    });

    test('traduce unavailable al eliminar', () async {
      final service = _FakeAtypicalSituationManagementRemoteService()
        ..deleteError = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );

      final repository = FirebaseAtypicalSituationRepository(service);

      expect(
        () => repository.deleteAtypicalSituation(
          anonymousId: 'anonimo-test',
          recordId: 'registro-test',
        ),
        throwsA(
          isA<AtypicalSituationFailure>().having(
            (failure) => failure.message,
            'message',
            'No fue posible eliminar la situación. '
                'Verifica tu conexión.',
          ),
        ),
      );
    });

    test(
      'presenta un mensaje genérico ante un error inesperado de eliminación',
      () async {
        final service = _FakeAtypicalSituationManagementRemoteService()
          ..deleteError = Exception('error inesperado');

        final repository = FirebaseAtypicalSituationRepository(service);

        expect(
          () => repository.deleteAtypicalSituation(
            anonymousId: 'anonimo-test',
            recordId: 'registro-test',
          ),
          throwsA(
            isA<AtypicalSituationFailure>().having(
              (failure) => failure.message,
              'message',
              'No fue posible eliminar la situación. '
                  'Inténtalo nuevamente.',
            ),
          ),
        );
      },
    );
  });
}

class _FakeAtypicalSituationManagementRemoteService
    implements AtypicalSituationManagementRemoteService {
  _FakeAtypicalSituationManagementRemoteService({
    this.recoveredRecords = const [],
  });

  final List<AtypicalSituationRecord> recoveredRecords;

  AtypicalSituationRecord? savedRecord;
  AtypicalSituationRecord? updatedRecord;

  String? recoveredAnonymousId;

  String? deletedAnonymousId;
  String? deletedRecordId;

  Object? saveError;
  Object? recoveryError;
  Object? updateError;
  Object? deleteError;

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    final error = saveError;

    if (error != null) {
      throw error;
    }

    savedRecord = record;
  }

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    final error = recoveryError;

    if (error != null) {
      throw error;
    }

    recoveredAnonymousId = anonymousId;

    return recoveredRecords;
  }

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {
    final error = updateError;

    if (error != null) {
      throw error;
    }

    updatedRecord = record;
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {
    final error = deleteError;

    if (error != null) {
      throw error;
    }

    deletedAnonymousId = anonymousId;
    deletedRecordId = recordId;
  }
}
