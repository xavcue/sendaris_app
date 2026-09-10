import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/data/repositories/firebase_sleep_repository.dart';
import 'package:sendaris/features/sleep/data/services/sleep_remote_service.dart';
import 'package:sendaris/features/sleep/domain/exceptions/sleep_failure.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';

void main() {
  group('FirebaseSleepRepository', () {
    late _FakeSleepRemoteService service;

    late FirebaseSleepRepository repository;

    setUp(() {
      service = _FakeSleepRemoteService();

      repository = FirebaseSleepRepository(service);
    });

    test('guarda un registro de sueño mediante el servicio', () async {
      final record = _createRecord();

      await repository.saveSleep(record);

      expect(service.savedRecords, [record]);
    });

    test('recupera registros de sueño sin alterar los datos', () async {
      final record = _createRecord();

      service.recordsToRecover = [record];

      final recovered = await repository.recoverSleepRecords(
        anonymousId: 'anonimo-1',
      );

      expect(recovered.length, 1);

      expect(recovered.first.recordId, record.recordId);

      expect(recovered.first.durationMinutes, 480);
    });

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.saveSleep(_createRecord()),
        throwsA(
          isA<SleepFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Debes iniciar sesión'),
          ),
        ),
      );
    });

    test('no expone permission-denied de Firebase', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        () => repository.saveSleep(_createRecord()),
        throwsA(
          isA<SleepFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para guardar este registro de sueño.',
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
        () => repository.saveSleep(_createRecord()),
        throwsA(
          isA<SleepFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });
  });
}

SleepRecord _createRecord() {
  return SleepRecord(
    recordId: 'registro-sueno-1',
    anonymousId: 'anonimo-1',
    date: DateTime(2026, 9, 9),
    startTime: '22:00',
    endTime: '06:00',
    durationMinutes: 480,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 10, 10),
    updatedAt: DateTime.utc(2026, 9, 10, 10),
  );
}

class _FakeSleepRemoteService implements SleepRemoteService {
  final List<SleepRecord> savedRecords = [];

  List<SleepRecord> recordsToRecover = [];

  Object? error;

  @override
  Future<void> saveSleep(SleepRecord record) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(recordsToRecover);
  }
}
