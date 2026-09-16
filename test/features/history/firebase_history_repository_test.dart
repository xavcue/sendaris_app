import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/data/repositories/firebase_history_repository.dart';
import 'package:sendaris/features/history/data/services/history_remote_service.dart';
import 'package:sendaris/features/history/domain/exceptions/history_failure.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';

void main() {
  group('FirebaseHistoryRepository', () {
    late _FakeHistoryRemoteService service;

    late FirebaseHistoryRepository repository;

    setUp(() {
      service = _FakeHistoryRemoteService();

      repository = FirebaseHistoryRepository(service);
    });

    test(
      'recupera el historial del identificador anónimo solicitado',
      () async {
        final records = [
          _createRecord(
            recordId: 'registro-2',
            eventDate: DateTime.utc(2026, 9, 15, 16),
          ),
          _createRecord(
            recordId: 'registro-1',
            eventDate: DateTime.utc(2026, 9, 15, 14),
          ),
        ];

        service.recordsToRecover = records;

        final recovered = await repository.recoverHistory(
          anonymousId: 'anonimo-1',
        );

        expect(service.requestedAnonymousIds, ['anonimo-1']);

        expect(recovered, hasLength(2));

        expect(recovered[0].recordId, 'registro-2');

        expect(recovered[1].recordId, 'registro-1');
      },
    );

    test('permite recuperar un historial vacío', () async {
      final recovered = await repository.recoverHistory(
        anonymousId: 'anonimo-1',
      );

      expect(recovered, isEmpty);
    });

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.recoverHistory(anonymousId: 'anonimo-1'),
        throwsA(
          isA<HistoryFailure>().having(
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
        () => repository.recoverHistory(anonymousId: 'anonimo-1'),
        throwsA(
          isA<HistoryFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para consultar este historial.',
          ),
        ),
      );
    });

    test('un error de red se presenta como error controlado', () async {
      service.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(
        () => repository.recoverHistory(anonymousId: 'anonimo-1'),
        throwsA(
          isA<HistoryFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });

    test('un documento inválido se presenta como error controlado', () async {
      service.error = const FormatException('Documento inválido');

      expect(
        () => repository.recoverHistory(anonymousId: 'anonimo-1'),
        throwsA(
          isA<HistoryFailure>().having(
            (failure) => failure.message,
            'message',
            contains('No fue posible cargar el historial'),
          ),
        ),
      );
    });

    test('un error inesperado no expone detalles internos', () async {
      service.error = Exception('Internal implementation error');

      expect(
        () => repository.recoverHistory(anonymousId: 'anonimo-1'),
        throwsA(
          isA<HistoryFailure>().having(
            (failure) => failure.message,
            'message',
            'No fue posible cargar el historial. '
                'Inténtalo nuevamente.',
          ),
        ),
      );
    });
  });
}

HistoryRecord _createRecord({
  required String recordId,
  required DateTime eventDate,
}) {
  return HistoryRecord(
    recordId: recordId,
    anonymousId: 'anonimo-1',
    type: HistoryRecordType.behavior,
    eventDate: eventDate,
  );
}

class _FakeHistoryRemoteService implements HistoryRemoteService {
  List<HistoryRecord> recordsToRecover = [];

  final List<String> requestedAnonymousIds = [];

  Object? error;

  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    requestedAnonymousIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(recordsToRecover);
  }
}
