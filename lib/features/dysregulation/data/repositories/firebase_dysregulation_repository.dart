import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/dysregulation_failure.dart';
import '../../domain/models/dysregulation_record.dart';
import '../../domain/repositories/dysregulation_management_repository.dart';
import '../services/dysregulation_remote_service.dart';

class FirebaseDysregulationRepository
    implements DysregulationManagementRepository {
  FirebaseDysregulationRepository(this._remoteService);

  final DysregulationManagementRemoteService _remoteService;

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {
    try {
      await _remoteService.saveDysregulation(record);
    } on StateError {
      throw const DysregulationFailure(
        'Debes iniciar sesión antes de guardar '
        'un episodio de desregulación.',
      );
    } on FirebaseException catch (error) {
      throw DysregulationFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const DysregulationFailure(
        'No fue posible guardar el episodio '
        'de desregulación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverDysregulations(
        anonymousId: anonymousId,
      );
    } on StateError {
      throw const DysregulationFailure(
        'Debes iniciar sesión antes de cargar '
        'los registros de desregulación.',
      );
    } on FirebaseException catch (error) {
      throw DysregulationFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const DysregulationFailure(
        'No fue posible cargar los registros '
        'de desregulación. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const DysregulationFailure(
        'No fue posible cargar los registros '
        'de desregulación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {
    try {
      await _remoteService.updateDysregulation(record);
    } on StateError {
      throw const DysregulationFailure(
        'Debes iniciar sesión antes de actualizar '
        'un registro de desregulación.',
      );
    } on FirebaseException catch (error) {
      throw DysregulationFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const DysregulationFailure(
        'No fue posible actualizar el registro '
        'de desregulación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteDysregulation(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const DysregulationFailure(
        'Debes iniciar sesión antes de eliminar '
        'un registro de desregulación.',
      );
    } on FirebaseException catch (error) {
      throw DysregulationFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const DysregulationFailure(
        'No fue posible eliminar el registro '
        'de desregulación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar '
            'este episodio de desregulación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar el episodio '
            'de desregulación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar el episodio '
            'de desregulación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar '
            'estos registros de desregulación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros '
            'de desregulación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros '
            'de desregulación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar '
            'este registro de desregulación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar el registro '
            'de desregulación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar el registro '
            'de desregulación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar '
            'este registro de desregulación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar el registro '
            'de desregulación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar el registro '
            'de desregulación. '
            'Inténtalo nuevamente.';
    }
  }
}
