import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/tracking/data/services/firestore_tracking_service.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';

void main() {
  late _TestFirestore firestore;
  late _TestFirebaseAuth auth;
  late FirestoreTrackingService service;

  setUp(() {
    firestore = _TestFirestore();
    auth = _TestFirebaseAuth('uid-a');

    service = FirestoreTrackingService(firestore, auth);
  });

  tearDown(() async {
    await firestore.dispose();
    await auth.dispose();
  });

  group('FirestoreTrackingService - observación', () {
    test('descarta caché y escrituras pendientes', () async {
      final received = <List<AnonymousTrackingProfile>>[];
      final firstAccepted = Completer<void>();

      final subscription = service.watchProfiles().listen((profiles) {
        received.add(profiles);

        if (!firstAccepted.isCompleted) {
          firstAccepted.complete();
        }
      });

      try {
        expect(firestore.requestedPath, 'usuarios/uid-a/seguimientos');

        expect(firestore.testCollection.orderedField, 'fechaCreacion');

        expect(firestore.query.includeMetadataChanges, isTrue);

        firestore.query.emit(
          ids: ['perfil-cache'],
          isFromCache: true,
          hasPendingWrites: false,
        );

        firestore.query.emit(
          ids: ['perfil-pendiente'],
          isFromCache: false,
          hasPendingWrites: true,
        );

        firestore.query.emit(
          ids: ['perfil-cache-pendiente'],
          isFromCache: true,
          hasPendingWrites: true,
        );

        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);

        firestore.query.emit(
          ids: ['perfil-confirmado'],
          isFromCache: false,
          hasPendingWrites: false,
        );

        await firstAccepted.future.timeout(const Duration(seconds: 3));

        expect(received, hasLength(1));

        expect(received.single.single.anonymousId, 'perfil-confirmado');
      } finally {
        await subscription.cancel();
      }
    });

    test('recibe cambios y eliminaciones confirmadas', () async {
      final received = <List<AnonymousTrackingProfile>>[];
      final threeEventsReceived = Completer<void>();

      final subscription = service.watchProfiles().listen((profiles) {
        received.add(profiles);

        if (received.length == 3 && !threeEventsReceived.isCompleted) {
          threeEventsReceived.complete();
        }
      });

      try {
        firestore.query.emit(
          ids: ['perfil-1'],
          isFromCache: false,
          hasPendingWrites: false,
        );

        firestore.query.emit(
          ids: ['perfil-1', 'perfil-2'],
          isFromCache: false,
          hasPendingWrites: false,
        );

        firestore.query.emit(
          ids: [],
          isFromCache: false,
          hasPendingWrites: false,
        );

        await threeEventsReceived.future.timeout(const Duration(seconds: 3));

        expect(received, hasLength(3));
        expect(received[0], hasLength(1));
        expect(received[1], hasLength(2));
        expect(received[2], isEmpty);

        expect(received[0].single.anonymousId, 'perfil-1');

        expect(
          received[1].map((profile) => profile.anonymousId),
          containsAll(['perfil-1', 'perfil-2']),
        );
      } finally {
        await subscription.cancel();
      }
    });

    test('invalida permanentemente la escucha al cambiar A-B-A', () async {
      final received = <List<AnonymousTrackingProfile>>[];
      final errors = <Object>[];

      final firstReceived = Completer<void>();
      final completed = Completer<void>();

      final subscription = service.watchProfiles().listen(
        (profiles) {
          received.add(profiles);

          if (!firstReceived.isCompleted) {
            firstReceived.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          errors.add(error);
        },
        onDone: () {
          if (!completed.isCompleted) {
            completed.complete();
          }
        },
      );

      try {
        firestore.query.emit(
          ids: ['perfil-a'],
          isFromCache: false,
          hasPendingWrites: false,
        );

        await firstReceived.future.timeout(const Duration(seconds: 3));

        expect(received, hasLength(1));

        expect(received.single.single.anonymousId, 'perfil-a');

        auth.changeUid('uid-b');
        auth.changeUid('uid-a');

        await completed.future.timeout(const Duration(seconds: 3));

        firestore.query.emit(
          ids: ['perfil-antiguo'],
          isFromCache: false,
          hasPendingWrites: false,
        );

        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.single, isA<StateError>());

        expect(received, hasLength(1));

        expect(received.single.single.anonymousId, 'perfil-a');

        expect(firestore.query.hasListener, isFalse);
      } finally {
        await subscription.cancel();
      }
    });

    test('libera la escucha de Firestore al cancelar', () async {
      final subscription = service.watchProfiles().listen((_) {});

      expect(firestore.query.hasListener, isTrue);

      await subscription.cancel();

      expect(firestore.query.hasListener, isFalse);
    });

    test('no permite observar sin una cuenta autenticada', () {
      auth.changeUid(null);

      expect(() => service.watchProfiles(), throwsStateError);

      expect(firestore.requestedPath, isNull);
    });
  });
}

class _TestFirebaseAuth implements FirebaseAuth {
  _TestFirebaseAuth(String initialUid) : _user = _TestUser(initialUid);

  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() {
    return _changes.stream;
  }

  void changeUid(String? uid) {
    _user = uid == null ? null : _TestUser(uid);
    _changes.add(_user);
  }

  Future<void> dispose() async {
    await _changes.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestUser implements User {
  _TestUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestFirestore implements FirebaseFirestore {
  final _TestQuery query = _TestQuery();

  late final _TestCollection testCollection;

  String? requestedPath;

  _TestFirestore() {
    testCollection = _TestCollection(query);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    requestedPath = collectionPath;
    return testCollection;
  }

  Future<void> dispose() async {
    await query.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Este doble implementa una interfaz sealed de Firebase.
// La excepción se limita a esta clase del entorno de pruebas.
// ignore: subtype_of_sealed_class
class _TestCollection implements CollectionReference<Map<String, dynamic>> {
  _TestCollection(this.query);

  final _TestQuery query;

  final List<String> _orderedFields = [];

  String? get orderedField {
    if (_orderedFields.isEmpty) {
      return null;
    }

    return _orderedFields.last;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #orderBy) {
      final field = invocation.positionalArguments.first as String;

      _orderedFields.add(field);

      return query;
    }

    return super.noSuchMethod(invocation);
  }
}

// Doble aislado para comprobar la entrega de instantáneas.
// ignore: subtype_of_sealed_class
class _TestQuery implements Query<Map<String, dynamic>> {
  final StreamController<QuerySnapshot<Map<String, dynamic>>> _snapshots =
      StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast(
        sync: true,
      );

  final List<bool> _metadataOptions = [];

  bool get includeMetadataChanges {
    if (_metadataOptions.isEmpty) {
      return false;
    }

    return _metadataOptions.last;
  }

  bool get hasListener => _snapshots.hasListener;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #snapshots) {
      final requestedMetadata =
          invocation.namedArguments[#includeMetadataChanges] == true;

      _metadataOptions.add(requestedMetadata);

      return _snapshots.stream;
    }

    return super.noSuchMethod(invocation);
  }

  void emit({
    required List<String> ids,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    final documents = ids
        .map<QueryDocumentSnapshot<Map<String, dynamic>>>(
          (id) => _TestDocument(id),
        )
        .toList(growable: false);

    _snapshots.add(
      _TestQuerySnapshot(
        documents,
        _TestMetadata(
          isFromCache: isFromCache,
          hasPendingWrites: hasPendingWrites,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _snapshots.close();
  }
}

class _TestQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _TestQuerySnapshot(this.docs, this.metadata);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  final SnapshotMetadata metadata;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// El SDK declara DocumentSnapshot y QueryDocumentSnapshot
// como sealed. Esta implementación solo existe en las pruebas.
// ignore: subtype_of_sealed_class
class _TestDocument implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _TestDocument(this.id);

  @override
  final String id;

  @override
  Map<String, dynamic> data() {
    return {
      'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
      'activo': true,
      'numeroSeguimiento': 1,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _TestMetadata implements SnapshotMetadata {
  _TestMetadata({required this.isFromCache, required this.hasPendingWrites});

  @override
  final bool isFromCache;

  @override
  final bool hasPendingWrites;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
