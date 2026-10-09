import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/sleep_failure.dart';
import '../../domain/models/sleep_record.dart';
import '../../domain/repositories/sleep_management_repository.dart';
import '../services/sleep_remote_service.dart';

class FirebaseSleepRepository implements SleepManagementRepository {
  FirebaseSleepRepository(this._remoteService);

  final SleepManagementRemoteService _remoteService;

  @override
  Future<void> saveSleep(SleepRecord record) async {
    try {
      await _remoteService.saveSleep(record);
    } on StateError {
      throw const SleepFailure(
        'Debes iniciar sesión antes de guardar un registro de sueño.',
      );
    } on FirebaseException catch (error) {
      throw SleepFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const SleepFailure(
        'No fue posible guardar el registro de sueño. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverSleepRecords(anonymousId: anonymousId);
    } on StateError {
      throw const SleepFailure(
        'Debes iniciar sesión antes de cargar los registros de sueño.',
      );
    } on FirebaseException catch (error) {
      throw SleepFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const SleepFailure(
        'No fue posible cargar los registros de sueño. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const SleepFailure(
        'No fue posible cargar los registros de sueño. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {
    try {
      await _remoteService.updateSleep(record);
    } on StateError {
      throw const SleepFailure(
        'Debes iniciar sesión antes de actualizar un registro de sueño.',
      );
    } on FirebaseException catch (error) {
      throw SleepFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const SleepFailure(
        'No fue posible actualizar el registro de sueño. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteSleep(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const SleepFailure(
        'Debes iniciar sesión antes de eliminar un registro de sueño.',
      );
    } on FirebaseException catch (error) {
      throw SleepFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const SleepFailure(
        'No fue posible eliminar el registro de sueño. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar este registro de sueño.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar el registro de sueño. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar el registro de sueño. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar estos registros de sueño.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros de sueño. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros de sueño. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar este registro de sueño.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar el registro de sueño. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar el registro de sueño. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar este registro de sueño.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar el registro de sueño. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar el registro de sueño. '
            'Inténtalo nuevamente.';
    }
  }
}
