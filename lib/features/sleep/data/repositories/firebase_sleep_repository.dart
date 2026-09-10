import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/sleep_failure.dart';
import '../../domain/models/sleep_record.dart';
import '../../domain/repositories/sleep_repository.dart';
import '../services/sleep_remote_service.dart';

class FirebaseSleepRepository implements SleepRepository {
  FirebaseSleepRepository(this._remoteService);

  final SleepRemoteService _remoteService;

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
}
