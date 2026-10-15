import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_observation_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  late _ObservedRepository repository;
  late TrackingViewModel viewModel;
  late bool viewModelDisposed;

  setUp(() {
    repository = _ObservedRepository();

    viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FixedIdGenerator()),
    );

    viewModelDisposed = false;
  });

  tearDown(() async {
    if (!viewModelDisposed) {
      viewModel.dispose();
      viewModelDisposed = true;
    }

    await repository.dispose();
  });

  test('sincroniza la eliminación remota de un seguimiento', () async {
    repository.recoveredProfiles = [
      _profile('seguimiento-1', 1),
      _profile('seguimiento-2', 2),
    ];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);
    expect(repository.observations.length, 1);
    expect(viewModel.profiles.length, 2);

    repository.emit(0, [_profile('seguimiento-1', 1)]);

    expect(viewModel.profiles.length, 1);
    expect(viewModel.activeAnonymousId, 'seguimiento-1');
  });

  test('cambia la selección cuando desaparece el perfil activo', () async {
    repository.recoveredProfiles = [
      _profile('seguimiento-1', 1),
      _profile('seguimiento-2', 2),
    ];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    final selected = viewModel.profiles.firstWhere(
      (profile) => profile.anonymousId == 'seguimiento-2',
    );

    expect(viewModel.selectProfile(selected), isTrue);
    expect(viewModel.activeAnonymousId, 'seguimiento-2');

    repository.emit(0, [_profile('seguimiento-1', 1)]);

    expect(viewModel.activeAnonymousId, 'seguimiento-1');
  });

  test('conserva la selección si el perfil sigue disponible', () async {
    repository.recoveredProfiles = [
      _profile('seguimiento-1', 1),
      _profile('seguimiento-2', 2),
    ];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    final selected = viewModel.profiles.last;

    expect(viewModel.selectProfile(selected), isTrue);

    repository.emit(0, [
      _profile('seguimiento-1', 1),
      _profile('seguimiento-2', 2),
      _profile('seguimiento-3', 3),
    ]);

    expect(viewModel.activeAnonymousId, 'seguimiento-2');
    expect(viewModel.profiles.length, 3);
  });

  test('sincroniza la eliminación de todos los seguimientos', () async {
    repository.recoveredProfiles = [_profile('seguimiento-1', 1)];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    repository.emit(0, []);

    expect(viewModel.profiles, isEmpty);
    expect(viewModel.activeAnonymousId, isNull);
    expect(viewModel.hasProfiles, isFalse);
  });

  test('descarta eventos de sesiones anteriores en A-B-A', () async {
    repository.recoveredProfiles = [_profile('perfil-a', 1)];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    repository.recoveredProfiles = [_profile('perfil-b', 1)];

    viewModel.synchronizeAuthenticationContext('uid-b');

    expect(await viewModel.initialize(), isTrue);

    repository.emit(0, [_profile('perfil-antiguo', 9)]);

    expect(viewModel.activeAnonymousId, 'perfil-b');

    repository.recoveredProfiles = [_profile('perfil-a-nuevo', 1)];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    repository.emit(0, [_profile('perfil-antiguo', 9)]);

    expect(viewModel.activeAnonymousId, 'perfil-a-nuevo');
    expect(repository.observations.length, 3);
  });

  test('no inicia observación sin autenticación', () async {
    viewModel.synchronizeAuthenticationContext(null);

    expect(await viewModel.initialize(), isFalse);
    expect(repository.observations, isEmpty);
  });

  test('controla errores de observación sin borrar los perfiles', () async {
    repository.recoveredProfiles = [_profile('seguimiento-1', 1)];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    repository.emitError(
      0,
      const TrackingFailure('No fue posible consultar Firestore.'),
    );

    expect(viewModel.activeAnonymousId, 'seguimiento-1');
    expect(viewModel.profiles.length, 1);
    expect(viewModel.errorMessage, 'No fue posible consultar Firestore.');
  });

  test('no modifica los perfiles después de dispose', () async {
    repository.recoveredProfiles = [_profile('seguimiento-1', 1)];

    viewModel.synchronizeAuthenticationContext('uid-a');

    expect(await viewModel.initialize(), isTrue);

    viewModel.dispose();
    viewModelDisposed = true;

    repository.emit(0, [_profile('seguimiento-2', 2)]);

    expect(viewModel.activeAnonymousId, 'seguimiento-1');
  });
}

AnonymousTrackingProfile _profile(String id, int number) {
  return AnonymousTrackingProfile(
    anonymousId: id,
    createdAt: DateTime.utc(2026, 10, number),
    trackingNumber: number,
  );
}

class _ObservedRepository
    implements TrackingRepository, TrackingObservationRepository {
  List<AnonymousTrackingProfile> recoveredProfiles = [];

  final List<StreamController<List<AnonymousTrackingProfile>>> observations =
      [];

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.from(recoveredProfiles);
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Stream<List<AnonymousTrackingProfile>> watchProfiles() {
    final controller =
        StreamController<List<AnonymousTrackingProfile>>.broadcast(sync: true);

    observations.add(controller);

    return controller.stream;
  }

  void emit(int index, List<AnonymousTrackingProfile> profiles) {
    observations[index].add(profiles);
  }

  void emitError(int index, Object error) {
    observations[index].addError(error);
  }

  Future<void> dispose() async {
    for (final controller in observations) {
      await controller.close();
    }
  }
}

class _FixedIdGenerator implements AnonymousIdGenerator {
  const _FixedIdGenerator();

  @override
  String generate() => 'nuevo-seguimiento';
}
