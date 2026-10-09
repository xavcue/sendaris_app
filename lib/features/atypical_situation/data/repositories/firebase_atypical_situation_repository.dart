import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/atypical_situation_failure.dart';
import '../../domain/models/atypical_situation_record.dart';
import '../../domain/repositories/atypical_situation_management_repository.dart';
import '../services/atypical_situation_remote_service.dart';

class FirebaseAtypicalSituationRepository
    implements AtypicalSituationManagementRepository {
  FirebaseAtypicalSituationRepository(this._remoteService);

  final AtypicalSituationManagementRemoteService _remoteService;

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    try {
      await _remoteService.saveAtypicalSituation(record);
    } on StateError {
      throw const AtypicalSituationFailure(
        'Debes iniciar sesión antes de guardar la situación.',
      );
    } on FirebaseException catch (error) {
      throw AtypicalSituationFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const AtypicalSituationFailure(
        'No fue posible guardar la situación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverAtypicalSituations(
        anonymousId: anonymousId,
      );
    } on StateError {
      throw const AtypicalSituationFailure(
        'Debes iniciar sesión antes de '
        'cargar las situaciones guardadas.',
      );
    } on FirebaseException catch (error) {
      throw AtypicalSituationFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const AtypicalSituationFailure(
        'No fue posible cargar las situaciones guardadas. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const AtypicalSituationFailure(
        'No fue posible cargar las situaciones guardadas. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {
    try {
      await _remoteService.updateAtypicalSituation(record);
    } on StateError {
      throw const AtypicalSituationFailure(
        'Debes iniciar sesión antes de actualizar la situación.',
      );
    } on FirebaseException catch (error) {
      throw AtypicalSituationFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const AtypicalSituationFailure(
        'No fue posible actualizar la situación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteAtypicalSituation(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const AtypicalSituationFailure(
        'Debes iniciar sesión antes de eliminar la situación.',
      );
    } on FirebaseException catch (error) {
      throw AtypicalSituationFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const AtypicalSituationFailure(
        'No fue posible eliminar la situación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar esta situación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar la situación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar la situación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar '
            'estas situaciones.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar las situaciones. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar las situaciones guardadas. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar esta situación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar la situación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar la situación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar esta situación.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar la situación. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar la situación. '
            'Inténtalo nuevamente.';
    }
  }
}
