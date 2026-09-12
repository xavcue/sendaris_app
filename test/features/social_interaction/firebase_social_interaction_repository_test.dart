import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/data/repositories/firebase_social_interaction_repository.dart';
import 'package:sendaris/features/social_interaction/data/services/social_interaction_remote_service.dart';
import 'package:sendaris/features/social_interaction/domain/exceptions/social_interaction_failure.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';

void main() {
  group('FirebaseSocialInteractionRepository', () {
    late _FakeSocialInteractionRemoteService service;

    late FirebaseSocialInteractionRepository repository;

    setUp(() {
      service = _FakeSocialInteractionRemoteService();

      repository = FirebaseSocialInteractionRepository(service);
    });

    test('guarda un registro mediante el servicio', () async {
      final record = _createRecord();

      await repository.saveSocialInteraction(record);

      expect(service.savedRecords, [record]);
    });

    test('recupera registros sin alterar sus datos', () async {
      final record = _createRecord();

      service.recordsToRecover = [record];

      final recovered = await repository.recoverSocialInteractions(
        anonymousId: 'anonimo-1',
      );

      expect(recovered, hasLength(1));

      expect(recovered.single.recordId, 'interaccion-1');

      expect(
        recovered.single.category,
        SocialInteractionCategory.socialExchange,
      );

      expect(recovered.single.context, 'Actividad recreativa');
    });

    test('convierte falta de sesión en error controlado', () async {
      service.error = StateError('Internal auth error');

      expect(
        () => repository.saveSocialInteraction(_createRecord()),
        throwsA(
          isA<SocialInteractionFailure>().having(
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
        () => repository.saveSocialInteraction(_createRecord()),
        throwsA(
          isA<SocialInteractionFailure>().having(
            (failure) => failure.message,
            'message',
            'No tienes autorización para guardar este registro de interacción social.',
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
        () => repository.saveSocialInteraction(_createRecord()),
        throwsA(
          isA<SocialInteractionFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Verifica tu conexión'),
          ),
        ),
      );
    });
  });
}

SocialInteractionRecord _createRecord() {
  return SocialInteractionRecord(
    recordId: 'interaccion-1',
    anonymousId: 'anonimo-1',
    date: DateTime(2026, 9, 11),
    category: SocialInteractionCategory.socialExchange,
    context: 'Actividad recreativa',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 11, 20),
    updatedAt: DateTime.utc(2026, 9, 11, 20),
  );
}

class _FakeSocialInteractionRemoteService
    implements SocialInteractionRemoteService {
  final List<SocialInteractionRecord> savedRecords = [];

  List<SocialInteractionRecord> recordsToRecover = [];

  Object? error;

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    savedRecords.add(record);
  }

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(recordsToRecover);
  }
}
