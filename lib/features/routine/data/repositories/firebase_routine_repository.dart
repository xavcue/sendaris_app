import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/routine_failure.dart';
import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';
import '../services/routine_remote_service.dart';

class FirebaseRoutineRepository implements RoutineRepository {
  FirebaseRoutineRepository(this._remoteService);

  final RoutineRemoteService _remoteService;

  @override
  Future<void> createRoutine(Routine routine) async {
    try {
      await _remoteService.createRoutine(routine);
    } on StateError {
      throw const RoutineFailure(
        'Debes iniciar sesión antes de crear una rutina.',
      );
    } on FirebaseException catch (error) {
      throw RoutineFailure(_safeWriteMessage(error.code));
    } catch (_) {
      throw const RoutineFailure(
        'No fue posible crear la rutina. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    try {
      return await _remoteService.recoverRoutines(anonymousId: anonymousId);
    } on StateError {
      throw const RoutineFailure(
        'Debes iniciar sesión antes de recuperar rutinas.',
      );
    } on FirebaseException catch (error) {
      throw RoutineFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const RoutineFailure(
        'No fue posible interpretar las rutinas '
        'recuperadas de forma segura.',
      );
    } catch (_) {
      throw const RoutineFailure('No fue posible recuperar las rutinas.');
    }
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    try {
      await _remoteService.updateRoutine(routine);
    } on StateError {
      throw const RoutineFailure(
        'Debes iniciar sesión antes de modificar una rutina.',
      );
    } on FirebaseException catch (error) {
      throw RoutineFailure(_safeWriteMessage(error.code));
    } catch (_) {
      throw const RoutineFailure(
        'No fue posible modificar la rutina. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    try {
      await _remoteService.deactivateRoutine(
        anonymousId: anonymousId,
        routineId: routineId,
      );
    } on StateError {
      throw const RoutineFailure(
        'Debes iniciar sesión antes de desactivar una rutina.',
      );
    } on FirebaseException catch (error) {
      throw RoutineFailure(_safeWriteMessage(error.code));
    } catch (_) {
      throw const RoutineFailure(
        'No fue posible desactivar la rutina. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeWriteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para modificar esta rutina.';

      case 'not-found':
        return 'La rutina ya no se encuentra disponible.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible confirmar la operación remota. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar los cambios de la rutina.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para recuperar estas rutinas.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible recuperar las rutinas remotas. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible recuperar las rutinas.';
    }
  }
}
