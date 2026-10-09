import 'package:firebase_core/firebase_core.dart';

import '../../domain/exceptions/behavior_failure.dart';
import '../../domain/models/behavior_record.dart';
import '../../domain/repositories/behavior_management_repository.dart';
import '../services/behavior_remote_service.dart';

class FirebaseBehaviorRepository implements BehaviorManagementRepository {
  FirebaseBehaviorRepository(this._remoteService);

  final BehaviorManagementRemoteService _remoteService;

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    try {
      await _remoteService.saveBehavior(record);
    } on StateError {
      throw const BehaviorFailure(
        'Debes iniciar sesión antes de guardar una conducta.',
      );
    } on FirebaseException catch (error) {
      throw BehaviorFailure(_safeSaveMessage(error.code));
    } catch (_) {
      throw const BehaviorFailure(
        'No fue posible guardar la conducta. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    try {
      return await _remoteService.recoverBehaviors(anonymousId: anonymousId);
    } on StateError {
      throw const BehaviorFailure(
        'Debes iniciar sesión antes de cargar las conductas.',
      );
    } on FirebaseException catch (error) {
      throw BehaviorFailure(_safeRecoveryMessage(error.code));
    } on FormatException {
      throw const BehaviorFailure(
        'No fue posible cargar las conductas. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const BehaviorFailure(
        'No fue posible cargar las conductas. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {
    try {
      await _remoteService.updateBehavior(record);
    } on StateError {
      throw const BehaviorFailure(
        'Debes iniciar sesión antes de actualizar una conducta.',
      );
    } on FirebaseException catch (error) {
      throw BehaviorFailure(_safeUpdateMessage(error.code));
    } catch (_) {
      throw const BehaviorFailure(
        'No fue posible actualizar la conducta. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    try {
      await _remoteService.deleteBehavior(
        anonymousId: anonymousId,
        recordId: recordId,
      );
    } on StateError {
      throw const BehaviorFailure(
        'Debes iniciar sesión antes de eliminar una conducta.',
      );
    } on FirebaseException catch (error) {
      throw BehaviorFailure(_safeDeleteMessage(error.code));
    } catch (_) {
      throw const BehaviorFailure(
        'No fue posible eliminar la conducta. '
        'Inténtalo nuevamente.',
      );
    }
  }

  String _safeSaveMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para guardar esta conducta.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible guardar la conducta. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible guardar la conducta. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRecoveryMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para consultar estas conductas.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible cargar las conductas. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible cargar las conductas. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeUpdateMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para actualizar esta conducta.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible actualizar la conducta. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible actualizar la conducta. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeDeleteMessage(String code) {
    switch (code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'No tienes autorización para eliminar esta conducta.';

      case 'unavailable':
      case 'network-request-failed':
        return 'No fue posible eliminar la conducta. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible eliminar la conducta. '
            'Inténtalo nuevamente.';
    }
  }
}
