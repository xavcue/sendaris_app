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
  bool _isDisposed = false;

  String? _errorMessage;
  String? _successMessage;

  List<AnonymousTrackingProfile> _profiles = [];

  AnonymousTrackingProfile? _activeProfile;

  // Permite invalidar resultados de operaciones asincronicas
  // iniciadas durante un contexto de autenticacion anterior.
  int _authenticationGeneration = 0;

  // El contexto se configura desde la aplicacion.
  // Mientras no este configurado, se conserva la compatibilidad
  // con los repositorios simulados de las pruebas existentes.
  bool _hasAuthenticationContext = false;

  String? _authenticatedUserId;

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

  /// Sincroniza la identidad responsable de los seguimientos.
  ///
  /// Si cambia el UID, descarta el estado local de la cuenta
  /// anterior e invalida las operaciones asincronicas pendientes.
  ///
  /// Un UID nulo representa una sesion sin cuenta autenticada.
  /// No debe utilizarse como identificador de seguimiento.
  void synchronizeAuthenticationContext(String? userId) {
    if (_isDisposed) {
      return;
    }

    if (_hasAuthenticationContext && _authenticatedUserId == userId) {
      return;
    }

    _hasAuthenticationContext = true;
    _authenticatedUserId = userId;

    _invalidateAuthenticationGeneration();
    _resetTrackingState();
  }

  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    final generation = _authenticationGeneration;

    if (!_isRequestCurrent(generation)) {
      return false;
    }

    _setLoading(true);
    _clearMessages();

    try {
      final recoveredProfiles = await _repository.recoverProfiles();

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      final normalizedProfiles = await _ensureTrackingNumbers(
        recoveredProfiles,
        generation: generation,
      );

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _profiles = normalizedProfiles;
      _activeProfile = _findActiveProfile(_profiles);
      _isInitialized = true;

      return true;
    } on TrackingFailure catch (error) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage = error.message;

      return false;
    } catch (_) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage =
          'No fue posible preparar los seguimientos. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      if (_isRequestCurrent(generation)) {
        _setLoading(false);
      }
    }
  }

  Future<bool> createAndPersistProfile() async {
    final generation = _authenticationGeneration;

    if (!_isRequestCurrent(generation)) {
      return false;
    }

    _setLoading(true);
    _clearMessages();

    try {
      final profile = _profileFactory.create(
        trackingNumber: _nextTrackingNumber(),
      );

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      await _repository.persistProfile(profile);

      if (!_isRequestCurrent(generation)) {
        return false;
      }

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
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage = error.message;

      return false;
    } catch (_) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage =
          'No fue posible crear el seguimiento. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      if (_isRequestCurrent(generation)) {
        _setLoading(false);
      }
    }
  }

  Future<bool> recoverProfiles() async {
    final generation = _authenticationGeneration;

    if (!_isRequestCurrent(generation)) {
      return false;
    }

    _setLoading(true);
    _clearMessages();

    try {
      final previousActiveId = _activeProfile?.anonymousId;

      final recoveredProfiles = await _repository.recoverProfiles();

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      final normalizedProfiles = await _ensureTrackingNumbers(
        recoveredProfiles,
        generation: generation,
      );

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _profiles = normalizedProfiles;

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
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage = error.message;

      return false;
    } catch (_) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage =
          'No fue posible cargar los seguimientos. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      if (_isRequestCurrent(generation)) {
        _setLoading(false);
      }
    }
  }

  bool selectProfile(AnonymousTrackingProfile profile) {
    if (!_isRequestCurrent(_authenticationGeneration)) {
      return false;
    }

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
    final generation = _authenticationGeneration;

    if (!_isRequestCurrent(generation) || anonymousIds.isEmpty || _isLoading) {
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
        if (!_isRequestCurrent(generation)) {
          return false;
        }

        try {
          await deletionRepository.deleteProfile(profile.anonymousId);

          if (!_isRequestCurrent(generation)) {
            return false;
          }

          deletedIds.add(profile.anonymousId);
        } on TrackingFailure catch (error) {
          if (!_isRequestCurrent(generation)) {
            return false;
          }

          failureMessage ??= error.message;
        } catch (_) {
          if (!_isRequestCurrent(generation)) {
            return false;
          }

          failureMessage ??= 'No fue posible eliminar uno de los seguimientos.';
        }
      }

      if (!_isRequestCurrent(generation)) {
        return false;
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
      if (_isRequestCurrent(generation)) {
        _setLoading(false);
      }
    }
  }

  Future<bool> deleteAllProfilesForAccount() async {
    final generation = _authenticationGeneration;

    if (!_isRequestCurrent(generation) || _isLoading) {
      return false;
    }

    final deletionRepository = _deletionRepository;

    if (deletionRepository == null) {
      _errorMessage =
          'No fue posible eliminar los datos de la cuenta. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    _setLoading(true);
    _clearMessages();

    final deletedIds = <String>{};

    try {
      final recoveredProfiles = await _repository.recoverProfiles();

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      for (final profile in recoveredProfiles) {
        if (!_isRequestCurrent(generation)) {
          return false;
        }

        try {
          await deletionRepository.deleteProfile(profile.anonymousId);

          if (!_isRequestCurrent(generation)) {
            return false;
          }

          deletedIds.add(profile.anonymousId);
        } on TrackingFailure catch (error) {
          if (!_isRequestCurrent(generation)) {
            return false;
          }

          if (deletedIds.isNotEmpty) {
            _applyDeletedProfiles(deletedIds);
          }

          _errorMessage = error.message;

          return false;
        } catch (_) {
          if (!_isRequestCurrent(generation)) {
            return false;
          }

          if (deletedIds.isNotEmpty) {
            _applyDeletedProfiles(deletedIds);
          }

          _errorMessage =
              'No fue posible eliminar todos '
              'los datos de la cuenta.';

          return false;
        }
      }

      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _profiles = [];
      _activeProfile = null;
      _isInitialized = true;

      _successMessage = 'Datos de la cuenta eliminados correctamente.';

      return true;
    } on TrackingFailure catch (error) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage = error.message;

      return false;
    } catch (_) {
      if (!_isRequestCurrent(generation)) {
        return false;
      }

      _errorMessage =
          'No fue posible eliminar los datos de la cuenta. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      if (_isRequestCurrent(generation)) {
        _setLoading(false);
      }
    }
  }

  void clearAuthenticationState() {
    if (_isDisposed) {
      return;
    }

    _authenticatedUserId = null;

    _invalidateAuthenticationGeneration();
    _resetTrackingState();
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
    Iterable<AnonymousTrackingProfile> profiles, {
    required int generation,
  }) async {
    if (!_isRequestCurrent(generation)) {
      return const [];
    }

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
      if (!_isRequestCurrent(generation)) {
        return const [];
      }

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

      // No inicia una nueva escritura si el contexto ya cambio.
      if (!_isRequestCurrent(generation)) {
        return const [];
      }

      await _repository.persistProfile(numberedProfile);

      if (!_isRequestCurrent(generation)) {
        return const [];
      }

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

  void _invalidateAuthenticationGeneration() {
    _authenticationGeneration++;
  }

  bool _isRequestCurrent(int generation) {
    if (_isDisposed) {
      return false;
    }

    if (generation != _authenticationGeneration) {
      return false;
    }

    // Una vez configurada la identidad, no se permite acceder
    // a los seguimientos sin una cuenta autenticada.
    if (_hasAuthenticationContext && _authenticatedUserId == null) {
      return false;
    }

    return true;
  }

  void _resetTrackingState() {
    final changed =
        _isLoading ||
        _isInitialized ||
        _profiles.isNotEmpty ||
        _activeProfile != null ||
        _errorMessage != null ||
        _successMessage != null;

    _isLoading = false;
    _isInitialized = false;

    _profiles = [];
    _activeProfile = null;

    _clearMessages();

    if (changed && !_isDisposed) {
      notifyListeners();
    }
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void _setLoading(bool value) {
    if (_isDisposed || _isLoading == value) {
      return;
    }

    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _invalidateAuthenticationGeneration();

    super.dispose();
  }
}
