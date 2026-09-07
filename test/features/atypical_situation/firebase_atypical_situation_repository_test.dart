import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/data/repositories/firebase_atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/data/services/atypical_situation_remote_service.dart';
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
      final service = _FakeAtypicalSituationRemoteService();

      final repository = FirebaseAtypicalSituationRepository(service);

      await repository.saveAtypicalSituation(record);

      expect(service.savedRecord, same(record));
    });

    test('recupera situaciones del servicio remoto', () async {
      final service = _FakeAtypicalSituationRemoteService(
        recoveredRecords: [record],
      );

      final repository = FirebaseAtypicalSituationRepository(service);

      final result = await repository.recoverAtypicalSituations(
        anonymousId: 'anonimo-test',
      );

      expect(result, hasLength(1));

      expect(result.single, same(record));
    });

    test('envía el identificador del perfil en la recuperación', () async {
      final service = _FakeAtypicalSituationRemoteService();

      final repository = FirebaseAtypicalSituationRepository(service);

      await repository.recoverAtypicalSituations(anonymousId: 'anonimo-test');

      expect(service.recoveredAnonymousId, 'anonimo-test');
    });
  });
}

class _FakeAtypicalSituationRemoteService
    implements AtypicalSituationRemoteService {
  _FakeAtypicalSituationRemoteService({this.recoveredRecords = const []});

  final List<AtypicalSituationRecord> recoveredRecords;

  AtypicalSituationRecord? savedRecord;

  String? recoveredAnonymousId;

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecord = record;
  }

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    recoveredAnonymousId = anonymousId;

    return recoveredRecords;
  }
}
