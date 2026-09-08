import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/tracking_failure.dart';
import '../../domain/models/anonymous_tracking_profile.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../services/tracking_remote_service.dart';

class FirebaseTrackingRepository implements TrackingRepository {
  FirebaseTrackingRepository(this._remoteService);

  final TrackingRemoteService _remoteService;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    try {
      await _remoteService.persistProfile(profile);
    } on StateError {
      throw const TrackingFailure(
        'Debes iniciar sesión antes de guardar información.',
      );
    } on FirebaseException catch (error) {
      throw TrackingFailure(_safePersistenceMessage(error.code));
    } catch (_) {
      throw const TrackingFailure(
        'No fue posible guardar la información. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    try {
      return await _remoteService.recoverProfiles();
    } on StateError {
      throw const TrackingFailure(
        'Debes iniciar sesión antes de cargar la información.',
      );
    } on FirebaseException catch (error) {
      throw TrackingFailure(_safeRecoveryMessage(error.code));
    } catch (_) {
      throw const TrackingFailure(
        'No fue posible cargar la información. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safePersistenceMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar '
            'esta información.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar la información. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar la información. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar '
            'esta información.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar la información. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar la información. '
            'Inténtalo nuevamente.';
    }
  }
}
