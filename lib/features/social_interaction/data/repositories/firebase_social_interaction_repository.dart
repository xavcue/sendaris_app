import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/social_interaction_failure.dart';
import '../../domain/models/social_interaction_record.dart';
import '../../domain/repositories/social_interaction_repository.dart';
import '../services/social_interaction_remote_service.dart';

class FirebaseSocialInteractionRepository
    implements SocialInteractionRepository {
  FirebaseSocialInteractionRepository(this._remoteService);

  final SocialInteractionRemoteService _remoteService;

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    try {
      await _remoteService.saveSocialInteraction(record);
    } on StateError {
      throw const SocialInteractionFailure(
        'Debes iniciar sesión antes de guardar un registro de interacción social.',
      );
    } on FirebaseException catch (error) {
      throw SocialInteractionFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const SocialInteractionFailure(
        'No fue posible guardar el registro de interacción social. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverSocialInteractions(
        anonymousId: anonymousId,
      );
    } on StateError {
      throw const SocialInteractionFailure(
        'Debes iniciar sesión antes de cargar los registros de interacción social.',
      );
    } on FirebaseException catch (error) {
      throw SocialInteractionFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const SocialInteractionFailure(
        'No fue posible cargar los registros de interacción social. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const SocialInteractionFailure(
        'No fue posible cargar los registros de interacción social. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar este registro de interacción social.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar el registro de interacción social. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar el registro de interacción social. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar estos registros de interacción social.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros de interacción social. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros de interacción social. '
            'Inténtalo nuevamente.';
    }
  }
}
