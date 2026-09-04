import 'package:flutter/foundation.dart';

import '../../domain/exceptions/tracking_failure.dart';
import '../../domain/models/anonymous_tracking_profile.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/services/anonymous_tracking_profile_factory.dart';

class TrackingViewModel extends ChangeNotifier {
  TrackingViewModel(this._repository, this._profileFactory);

  final TrackingRepository _repository;
  final AnonymousTrackingProfileFactory _profileFactory;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<AnonymousTrackingProfile> _profiles = [];

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  List<AnonymousTrackingProfile> get profiles => List.unmodifiable(_profiles);

  Future<bool> createAndPersistProfile() async {
    _setLoading(true);
    _clearMessages();

    try {
      final profile = _profileFactory.create();

      await _repository.persistProfile(profile);

      _profiles = [
        profile,
        ..._profiles.where(
          (existing) => existing.anonymousId != profile.anonymousId,
        ),
      ];

      _successMessage = 'Perfil anónimo guardado de forma segura.';
      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'No fue posible guardar la información de forma segura.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recoverProfiles() async {
    _setLoading(true);
    _clearMessages();

    try {
      final recoveredProfiles = await _repository.recoverProfiles();

      _profiles = recoveredProfiles;

      _successMessage = recoveredProfiles.isEmpty
          ? 'No existen perfiles anónimos almacenados.'
          : 'Información recuperada correctamente desde Firestore.';

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible recuperar la información de forma segura.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }
}
