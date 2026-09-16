import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/history_failure.dart';
import '../../domain/models/history_record.dart';
import '../../domain/repositories/history_repository.dart';
import '../services/history_remote_service.dart';

class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository(this._remoteService);

  final HistoryRemoteService _remoteService;

  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverHistory(anonymousId: anonymousId);
    } on StateError {
      throw const HistoryFailure(
        'Debes iniciar sesión antes de consultar el historial.',
      );
    } on ArgumentError {
      throw const HistoryFailure('El perfil seleccionado no es válido.');
    } on FirebaseException catch (error) {
      throw HistoryFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const HistoryFailure(
        'No fue posible cargar el historial. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const HistoryFailure(
        'No fue posible cargar el historial. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar este historial.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar el historial. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar el historial. '
            'Inténtalo nuevamente.';
    }
  }
}
