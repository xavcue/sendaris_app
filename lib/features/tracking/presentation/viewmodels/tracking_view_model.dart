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
  bool _isInitialized = false;

  String? _errorMessage;
  String? _successMessage;

  List<AnonymousTrackingProfile> _profiles = [];

  AnonymousTrackingProfile? _activeProfile;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  List<AnonymousTrackingProfile> get profiles => List.unmodifiable(_profiles);

  AnonymousTrackingProfile? get activeProfile => _activeProfile;

  String? get activeAnonymousId => _activeProfile?.anonymousId;

  bool get hasActiveProfile =>
      _activeProfile != null && _activeProfile!.isActive;

  Future<bool> initialize() async {
    if (_isInitialized) {
      return hasActiveProfile;
    }

    _setLoading(true);
    _clearMessages();

    try {
      final recoveredProfiles = await _repository.recoverProfiles();

      _profiles = recoveredProfiles;

      _activeProfile = _findActiveProfile(recoveredProfiles);

      if (_activeProfile == null) {
        final newProfile = _profileFactory.create();

        await _repository.persistProfile(newProfile);

        _profiles = [newProfile, ..._profiles];

        _activeProfile = newProfile;
      }

      _isInitialized = true;

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible preparar el seguimiento '
          'de forma segura.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

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

      _activeProfile = profile;
      _isInitialized = true;

      _successMessage = 'Seguimiento anónimo preparado correctamente.';

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar la información '
          'de forma segura.';

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

      _activeProfile = _findActiveProfile(recoveredProfiles);

      _isInitialized = true;

      _successMessage = recoveredProfiles.isEmpty
          ? 'No existen seguimientos anónimos almacenados.'
          : 'Información recuperada correctamente.';

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible recuperar la información '
          'de forma segura.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  void selectProfile(AnonymousTrackingProfile profile) {
    if (!profile.isActive) {
      return;
    }

    final belongsToRecoveredProfiles = _profiles.any(
      (candidate) => candidate.anonymousId == profile.anonymousId,
    );

    if (!belongsToRecoveredProfiles) {
      return;
    }

    _activeProfile = profile;

    _clearMessages();

    notifyListeners();
  }

  AnonymousTrackingProfile? _findActiveProfile(
    List<AnonymousTrackingProfile> profiles,
  ) {
    for (final profile in profiles) {
      if (profile.isActive) {
        return profile;
      }
    }

    return null;
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
