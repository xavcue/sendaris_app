import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/feeding_failure.dart';
import '../../domain/models/feeding_record.dart';
import '../../domain/repositories/feeding_repository.dart';
import '../services/feeding_remote_service.dart';

class FirebaseFeedingRepository implements FeedingRepository {
  FirebaseFeedingRepository(this._remoteService);

  final FeedingRemoteService _remoteService;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    try {
      await _remoteService.saveFeeding(record);
    } on StateError {
      throw const FeedingFailure(
        'Debes iniciar sesión antes de guardar un registro de alimentación.',
      );
    } on FirebaseException catch (error) {
      throw FeedingFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const FeedingFailure(
        'No fue posible guardar el registro de alimentación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverFeedingRecords(
        anonymousId: anonymousId,
      );
    } on StateError {
      throw const FeedingFailure(
        'Debes iniciar sesión antes de cargar los registros de alimentación.',
      );
    } on FirebaseException catch (error) {
      throw FeedingFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const FeedingFailure(
        'No fue posible cargar los registros de alimentación. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const FeedingFailure(
        'No fue posible cargar los registros de alimentación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar este registro de alimentación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar el registro de alimentación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar el registro de alimentación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar estos registros de alimentación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros de alimentación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros de alimentación. '
            'Inténtalo nuevamente.';
    }
  }
}
