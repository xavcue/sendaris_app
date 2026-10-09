import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/events/data/repositories/firebase_event_repository.dart';
import 'package:sendaris/features/events/data/services/event_remote_service.dart';
import 'package:sendaris/features/events/domain/exceptions/event_failure.dart';
import 'package:sendaris/features/events/domain/models/event_record.dart';
import 'package:sendaris/features/events/domain/models/event_record_type.dart';

void main() {
  group('FirebaseEventRepository', () {
    late _FakeEventRemoteService service;

    late FirebaseEventRepository repository;

    setUp(() {
      service = _FakeEventRemoteService();

      repository = FirebaseEventRepository(service);
    });

    test('recupera los eventos del seguimiento solicitado', () async {
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

      final recovered = await repository.recoverEvents(
        anonymousId: 'anonimo-1',
      );

      expect(service.requestedAnonymousIds, ['anonimo-1']);

      expect(recovered, hasLength(2));

      expect(recovered[0].recordId, 'registro-2');

      expect(recovered[1].recordId, 'registro-1');
    });

    test('permite recuperar una lista de eventos vacía', () async {
      final recovered = await repository.recoverEvents(
        anonymousId: 'anonimo-1',
      );

      expect(recovered, isEmpty);
    });

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.recoverEvents(anonymousId: 'anonimo-1'),
        throwsA(
          isA<EventFailure>().having(
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
        () => repository.recoverEvents(anonymousId: 'anonimo-1'),
        throwsA(
          isA<EventFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para consultar estos eventos.',
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
        () => repository.recoverEvents(anonymousId: 'anonimo-1'),
        throwsA(
          isA<EventFailure>().having(
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
        () => repository.recoverEvents(anonymousId: 'anonimo-1'),
        throwsA(
          isA<EventFailure>().having(
            (failure) => failure.message,
            'message',
            contains('No fue posible cargar los eventos'),
          ),
        ),
      );
    });

    test('un error inesperado no expone detalles internos', () async {
      service.error = Exception('Internal implementation error');

      expect(
        () => repository.recoverEvents(anonymousId: 'anonimo-1'),
        throwsA(
          isA<EventFailure>().having(
            (failure) => failure.message,
            'message',
            'No fue posible cargar los eventos. '
                'Inténtalo nuevamente.',
          ),
        ),
      );
    });
  });
}

EventRecord _createRecord({
  required String recordId,
  required DateTime eventDate,
}) {
  return EventRecord(
    recordId: recordId,
    anonymousId: 'anonimo-1',
    type: EventRecordType.behavior,
    eventDate: eventDate,
  );
}

class _FakeEventRemoteService implements EventRemoteService {
  List<EventRecord> recordsToRecover = [];

  final List<String> requestedAnonymousIds = [];

  Object? error;

  @override
  Future<List<EventRecord>> recoverEvents({required String anonymousId}) async {
    requestedAnonymousIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(recordsToRecover);
  }
}
