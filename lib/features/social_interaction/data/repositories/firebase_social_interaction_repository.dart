import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/social_interaction_failure.dart';
import '../../domain/models/social_interaction_record.dart';
import '../../domain/repositories/social_interaction_management_repository.dart';
import '../services/social_interaction_remote_service.dart';

class FirebaseSocialInteractionRepository
    implements SocialInteractionManagementRepository {
  FirebaseSocialInteractionRepository(this._remoteService);

  final SocialInteractionManagementRemoteService _remoteService;

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    try {
      await _remoteService.saveSocialInteraction(record);
    } on StateError {
      throw const SocialInteractionFailure(
        'Debes iniciar sesión antes de guardar '
        'un registro de interacción social.',
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
        'Debes iniciar sesión antes de cargar '
        'los registros de interacción social.',
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

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {
    try {
      await _remoteService.updateSocialInteraction(record);
    } on StateError {
      throw const SocialInteractionFailure(
        'Debes iniciar sesión antes de actualizar '
        'un registro de interacción social.',
      );
    } on FirebaseException catch (error) {
      throw SocialInteractionFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const SocialInteractionFailure(
        'No fue posible actualizar el registro de interacción social. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteSocialInteraction(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const SocialInteractionFailure(
        'Debes iniciar sesión antes de eliminar '
        'un registro de interacción social.',
      );
    } on FirebaseException catch (error) {
      throw SocialInteractionFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const SocialInteractionFailure(
        'No fue posible eliminar el registro de interacción social. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar '
            'este registro de interacción social.';

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
        return 'No tienes autorización para consultar '
            'estos registros de interacción social.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar los registros de interacción social. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar los registros de interacción social. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar '
            'este registro de interacción social.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar el registro de interacción social. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar el registro de interacción social. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar '
            'este registro de interacción social.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar el registro de interacción social. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar el registro de interacción social. '
            'Inténtalo nuevamente.';
    }
  }
}
