import 'package:flutter/foundation.dart';

import '../../domain/exceptions/tracking_failure.dart';
import '../../domain/models/anonymous_tracking_profile.dart';
import '../../domain/repositories/tracking_deletion_repository.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../../domain/services/anonymous_tracking_profile_factory.dart';

class TrackingViewModel extends ChangeNotifier {
  TrackingViewModel(TrackingRepository repository, this._profileFactory)
    : _repository = repository,
      _deletionRepository = repository is TrackingDeletionRepository
          ? repository as TrackingDeletionRepository
          : null;

  final TrackingRepository _repository;
  final TrackingDeletionRepository? _deletionRepository;
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

  List<AnonymousTrackingProfile> get profiles {
    return List.unmodifiable(_profiles);
  }

  List<AnonymousTrackingProfile> get orderedProfiles {
    return List.unmodifiable(_sortProfiles(_profiles));
  }

  List<AnonymousTrackingProfile> get activeProfiles {
    return List.unmodifiable(
      orderedProfiles.where((profile) => profile.isActive),
    );
  }

  AnonymousTrackingProfile? get activeProfile => _activeProfile;

  String? get activeAnonymousId => _activeProfile?.anonymousId;

  bool get hasActiveProfile {
    return _activeProfile != null && _activeProfile!.isActive;
  }

  bool get hasProfiles => activeProfiles.isNotEmpty;

  String? get activeTrackingLabel {
    final profile = _activeProfile;

    if (profile == null) {
      return null;
    }

    return trackingLabelFor(profile);
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    _setLoading(true);
    _clearMessages();

    try {
      final recoveredProfiles = await _repository.recoverProfiles();

      _profiles = await _ensureTrackingNumbers(recoveredProfiles);

      _activeProfile = _findActiveProfile(_profiles);

      _isInitialized = true;

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible preparar los seguimientos. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAndPersistProfile() async {
    _setLoading(true);
    _clearMessages();

    try {
      final profile = _profileFactory.create(
        trackingNumber: _nextTrackingNumber(),
      );

      await _repository.persistProfile(profile);

      _profiles = _sortProfiles([
        ..._profiles.where(
          (existing) => existing.anonymousId != profile.anonymousId,
        ),
        profile,
      ]);

      _activeProfile = profile;

      _isInitialized = true;

      _successMessage = 'Seguimiento creado correctamente.';

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible crear el seguimiento. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recoverProfiles() async {
    _setLoading(true);
    _clearMessages();

    try {
      final previousActiveId = _activeProfile?.anonymousId;

      final recoveredProfiles = await _repository.recoverProfiles();

      _profiles = await _ensureTrackingNumbers(recoveredProfiles);

      _activeProfile =
          _findActiveProfileById(
            profiles: _profiles,
            anonymousId: previousActiveId,
          ) ??
          _findActiveProfile(_profiles);

      _isInitialized = true;

      _successMessage = _profiles.isEmpty
          ? 'No hay seguimientos disponibles.'
          : 'Seguimientos cargados correctamente.';

      return true;
    } on TrackingFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cargar los seguimientos. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  bool selectProfile(AnonymousTrackingProfile profile) {
    if (!profile.isActive) {
      return false;
    }

    AnonymousTrackingProfile? recoveredProfile;

    for (final candidate in _profiles) {
      if (candidate.anonymousId == profile.anonymousId) {
        recoveredProfile = candidate;
        break;
      }
    }

    if (recoveredProfile == null || !recoveredProfile.isActive) {
      return false;
    }

    _activeProfile = recoveredProfile;

    _clearMessages();

    notifyListeners();

    return true;
  }

  Future<bool> deleteProfiles(Set<String> anonymousIds) async {
    if (anonymousIds.isEmpty || _isLoading) {
      return false;
    }

    final deletionRepository = _deletionRepository;

    if (deletionRepository == null) {
      _errorMessage =
          'No fue posible eliminar los seguimientos. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final targets = _profiles
        .where((profile) => anonymousIds.contains(profile.anonymousId))
        .toList(growable: false);

    if (targets.isEmpty) {
      return false;
    }

    _setLoading(true);
    _clearMessages();

    final deletedIds = <String>{};
    String? failureMessage;

    try {
      for (final profile in targets) {
        try {
          await deletionRepository.deleteProfile(profile.anonymousId);

          deletedIds.add(profile.anonymousId);
        } on TrackingFailure catch (error) {
          failureMessage ??= error.message;
        } catch (_) {
          failureMessage ??= 'No fue posible eliminar uno de los seguimientos.';
        }
      }

      if (deletedIds.isNotEmpty) {
        _applyDeletedProfiles(deletedIds);
      }

      if (failureMessage != null) {
        if (deletedIds.isEmpty) {
          _errorMessage = failureMessage;
        } else {
          _errorMessage =
              'Se eliminaron ${deletedIds.length} '
              '${deletedIds.length == 1 ? 'seguimiento' : 'seguimientos'}, '
              'pero no fue posible completar toda la operación.';
        }

        return false;
      }

      _successMessage = deletedIds.length == 1
          ? 'Seguimiento eliminado definitivamente.'
          : '${deletedIds.length} seguimientos '
                'eliminados definitivamente.';

      return true;
    } finally {
      _setLoading(false);
    }
  }

  int? trackingNumberFor(AnonymousTrackingProfile profile) {
    final persistedNumber = profile.trackingNumber;

    if (persistedNumber != null) {
      return persistedNumber;
    }

    final ordered = _sortProfiles(_profiles);

    for (var index = 0; index < ordered.length; index++) {
      if (ordered[index].anonymousId == profile.anonymousId) {
        return index + 1;
      }
    }

    return null;
  }

  String trackingLabelFor(AnonymousTrackingProfile profile) {
    final number = trackingNumberFor(profile);

    if (number == null) {
      return 'Seguimiento';
    }

    return 'Seguimiento $number';
  }

  Future<List<AnonymousTrackingProfile>> _ensureTrackingNumbers(
    Iterable<AnonymousTrackingProfile> profiles,
  ) async {
    final ordered = _sortProfiles(profiles);

    if (ordered.isEmpty) {
      return const [];
    }

    final usedNumbers = ordered
        .map((profile) => profile.trackingNumber)
        .whereType<int>()
        .toSet();

    var candidateNumber = 1;

    final normalized = <AnonymousTrackingProfile>[];

    for (final profile in ordered) {
      final existingNumber = profile.trackingNumber;

      if (existingNumber != null) {
        normalized.add(profile);
        continue;
      }

      while (usedNumbers.contains(candidateNumber)) {
        candidateNumber++;
      }

      final numberedProfile = AnonymousTrackingProfile(
        anonymousId: profile.anonymousId,
        createdAt: profile.createdAt,
        trackingNumber: candidateNumber,
        isActive: profile.isActive,
      );

      await _repository.persistProfile(numberedProfile);

      normalized.add(numberedProfile);

      usedNumbers.add(candidateNumber);

      candidateNumber++;
    }

    return _sortProfiles(normalized);
  }

  int _nextTrackingNumber() {
    var maximum = 0;

    for (final profile in _profiles) {
      final number = trackingNumberFor(profile);

      if (number != null && number > maximum) {
        maximum = number;
      }
    }

    return maximum + 1;
  }

  void _applyDeletedProfiles(Set<String> deletedIds) {
    _profiles = _sortProfiles(
      _profiles.where((profile) => !deletedIds.contains(profile.anonymousId)),
    );

    final currentActiveId = _activeProfile?.anonymousId;

    if (currentActiveId != null && deletedIds.contains(currentActiveId)) {
      _activeProfile = _findActiveProfile(_profiles);
    }
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

  AnonymousTrackingProfile? _findActiveProfileById({
    required List<AnonymousTrackingProfile> profiles,
    required String? anonymousId,
  }) {
    if (anonymousId == null) {
      return null;
    }

    for (final profile in profiles) {
      if (profile.anonymousId == anonymousId && profile.isActive) {
        return profile;
      }
    }

    return null;
  }

  List<AnonymousTrackingProfile> _sortProfiles(
    Iterable<AnonymousTrackingProfile> profiles,
  ) {
    final ordered = profiles.toList(growable: false);

    ordered.sort((first, second) {
      final dateComparison = first.createdAt.compareTo(second.createdAt);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return first.anonymousId.compareTo(second.anonymousId);
    });

    return ordered;
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
