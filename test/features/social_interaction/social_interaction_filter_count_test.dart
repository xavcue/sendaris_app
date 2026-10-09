import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import 'package:sendaris/features/social_interaction/presentation/viewmodels/social_interaction_management_view_model.dart';

void main() {
  test(
    'el contador muestra visibles respecto del total cuando hay filtro activo',
    () async {
      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [
          _record(recordId: 'dia-20', date: DateTime(2026, 9, 20)),
          _record(recordId: 'dia-21', date: DateTime(2026, 9, 21)),
          _record(recordId: 'dia-22', date: DateTime(2026, 9, 22)),
        ];

      final viewModel = SocialInteractionManagementViewModel(
        repository,
        anonymousId: 'seguimiento-actual',
      );

      await viewModel.load();

      expect(viewModel.recordCount, 3);

      expect(viewModel.totalRecordCount, 3);

      viewModel.setPendingStartDate(DateTime(2026, 9, 21));

      viewModel.setPendingEndDate(DateTime(2026, 9, 22));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.recordCount, 2);

      expect(viewModel.totalRecordCount, 3);

      viewModel.dispose();
    },
  );
}

SocialInteractionRecord _record({
  required String recordId,
  required DateTime date,
}) {
  return SocialInteractionRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: SocialInteractionCategory.socialExchange,
    context: null,
    observation: null,
    createdAt: DateTime.utc(date.year, date.month, date.day, 18),
    updatedAt: DateTime.utc(date.year, date.month, date.day, 18),
  );
}

class _FakeSocialInteractionManagementRepository
    implements SocialInteractionManagementRepository {
  List<SocialInteractionRecord> records = [];

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return List.unmodifiable(records);
  }

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {}
}
