import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/event_failure.dart';
import '../../domain/models/event_record.dart';
import '../../domain/repositories/event_repository.dart';
import '../services/event_remote_service.dart';

class FirebaseEventRepository implements EventRepository {
  FirebaseEventRepository(this._remoteService);

  final EventRemoteService _remoteService;

  @override
  Future<List<EventRecord>> recoverEvents({required String anonymousId}) async {
    try {
      return await _remoteService.recoverEvents(anonymousId: anonymousId);
    } on StateError {
      throw const EventFailure(
        'Debes iniciar sesión antes de consultar los eventos.',
      );
    } on ArgumentError {
      throw const EventFailure('El seguimiento seleccionado no es válido.');
    } on FirebaseException catch (error) {
      throw EventFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const EventFailure(
        'No fue posible cargar los eventos. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const EventFailure(
        'No fue posible cargar los eventos. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar estos eventos.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los eventos. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los eventos. '
            'Inténtalo nuevamente.';
    }
  }
}
