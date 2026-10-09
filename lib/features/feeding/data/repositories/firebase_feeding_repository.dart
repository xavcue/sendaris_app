import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/feeding_failure.dart';
import '../../domain/models/feeding_record.dart';
import '../../domain/repositories/feeding_management_repository.dart';
import '../services/feeding_remote_service.dart';

class FirebaseFeedingRepository implements FeedingManagementRepository {
  FirebaseFeedingRepository(this._remoteService);

  final FeedingManagementRemoteService _remoteService;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    try {
      await _remoteService.saveFeeding(record);
    } on StateError {
      throw const FeedingFailure(
        'Debes iniciar sesión antes de guardar '
        'un registro de alimentación.',
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
        'Debes iniciar sesión antes de cargar '
        'los registros de alimentación.',
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

  @override
  Future<void> updateFeeding(FeedingRecord record) async {
    try {
      await _remoteService.updateFeeding(record);
    } on StateError {
      throw const FeedingFailure(
        'Debes iniciar sesión antes de actualizar '
        'un registro de alimentación.',
      );
    } on FirebaseException catch (error) {
      throw FeedingFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const FeedingFailure(
        'No fue posible actualizar el registro de alimentación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteFeeding(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const FeedingFailure(
        'Debes iniciar sesión antes de eliminar '
        'un registro de alimentación.',
      );
    } on FirebaseException catch (error) {
      throw FeedingFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const FeedingFailure(
        'No fue posible eliminar el registro de alimentación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar '
            'este registro de alimentación.';

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
        return 'No tienes autorización para consultar '
            'estos registros de alimentación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros de alimentación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros de alimentación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar '
            'este registro de alimentación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar el registro de alimentación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar el registro de alimentación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar '
            'este registro de alimentación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar el registro de alimentación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar el registro de alimentación. '
            'Inténtalo nuevamente.';
    }
  }
}
