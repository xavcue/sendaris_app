import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/dysregulation_failure.dart';
import '../../domain/models/dysregulation_record.dart';
import '../../domain/repositories/dysregulation_repository.dart';
import '../services/dysregulation_remote_service.dart';

class FirebaseDysregulationRepository implements DysregulationRepository {
  FirebaseDysregulationRepository(this._remoteService);

  final DysregulationRemoteService _remoteService;

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
}
