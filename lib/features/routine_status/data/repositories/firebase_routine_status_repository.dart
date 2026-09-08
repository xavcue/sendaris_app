import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/routine_status_failure.dart';
import '../../domain/models/routine_status_record.dart';
import '../../domain/repositories/routine_status_repository.dart';
import '../services/routine_status_remote_service.dart';

class FirebaseRoutineStatusRepository implements RoutineStatusRepository {
  FirebaseRoutineStatusRepository(this._remoteService);

  final RoutineStatusRemoteService _remoteService;

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    try {
      await _remoteService.saveRoutineStatus(record);
    } on StateError {
      throw const RoutineStatusFailure(
        'Debes iniciar sesión antes de '
        'guardar el estado de una rutina.',
      );
    } on FirebaseException catch (error) {
      throw RoutineStatusFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const RoutineStatusFailure(
        'No fue posible guardar el estado '
        'de la rutina. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverRoutineStatuses(
        anonymousId: anonymousId,
      );
    } on StateError {
      throw const RoutineStatusFailure(
        'Debes iniciar sesión antes de '
        'cargar los estados de las rutinas.',
      );
    } on FirebaseException catch (error) {
      throw RoutineStatusFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const RoutineStatusFailure(
        'No fue posible cargar los estados '
        'de las rutinas. Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const RoutineStatusFailure(
        'No fue posible cargar los estados '
        'de las rutinas. Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para '
            'guardar este estado de rutina.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar el estado '
            'de la rutina. Verifica tu conexión.';

      default:
        return 'No fue posible guardar el estado '
            'de la rutina. Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para '
            'consultar estos estados de rutinas.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los estados '
            'de las rutinas. Verifica tu conexión.';

      default:
        return 'No fue posible cargar los estados '
            'de las rutinas. Inténtalo nuevamente.';
    }
  }
}
