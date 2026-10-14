// Los dobles de prueba implementan interfaces restringidas
// del SDK de Firestore exclusivamente para simular consultas
// controladas, sin conectarse a un proyecto real.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/tracking/data/services/firestore_tracking_service.dart';

void main() {
  group('FirestoreTrackingService - aislamiento de eliminaciones', () {
    late _FakeFirestore firestore;
    late _FakeFirebaseAuth auth;
    late FirestoreTrackingService service;

    setUp(() {
      firestore = _FakeFirestore();
      auth = _FakeFirebaseAuth();

      service = FirestoreTrackingService(firestore, auth);
    });

    tearDown(() async {
      await auth.dispose();
    });

    test(
      'una eliminacion vigente procesa sus colecciones y documento',
      () async {
        await service.deleteProfile('seguimiento-a');

        expect(firestore.readPaths, [
          'usuarios/uid-a/seguimientos/'
              'seguimiento-a/registros',
          'usuarios/uid-a/seguimientos/'
              'seguimiento-a/rutinas',
        ]);

        expect(firestore.deletedPaths, [
          'usuarios/uid-a/seguimientos/seguimiento-a',
        ]);
      },
    );

    test('cambiar a B durante la consulta de A '
        'detiene las operaciones restantes', () async {
      firestore.firstReadGate = Completer<void>();

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstReadStarted.future;

      expect(firestore.readPaths.length, 1);

      auth.changeUser('uid-b');

      firestore.firstReadGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(
        firestore.readPaths.length,
        1,
        reason:
            'No deben iniciarse nuevas consultas '
            'de eliminacion despues del cambio de UID.',
      );

      expect(
        firestore.deletedPaths,
        isEmpty,
        reason:
            'El documento principal no debe eliminarse '
            'desde una operacion obsoleta.',
      );

      expect(auth.currentUser?.uid, 'uid-b');
    });

    test('A a B a A no reanuda una eliminacion anterior', () async {
      firestore.firstReadGate = Completer<void>();

      final originalUser = auth.currentUser;

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstReadStarted.future;

      auth.changeUser('uid-b');

      // Se reutiliza la referencia original para
      // demostrar que comparar el UID o el objeto
      // al finalizar no es suficiente.
      auth.changeToUser(originalUser);

      firestore.firstReadGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(firestore.readPaths.length, 1);

      expect(firestore.deletedPaths, isEmpty);

      expect(auth.currentUser?.uid, 'uid-a');
    });

    test('cerrar sesion durante la consulta '
        'detiene la eliminacion', () async {
      firestore.firstReadGate = Completer<void>();

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstReadStarted.future;

      auth.changeUser(null);

      firestore.firstReadGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(firestore.readPaths.length, 1);
      expect(firestore.deletedPaths, isEmpty);
      expect(auth.currentUser, isNull);
    });
  });
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final StreamController<User?> _controller = StreamController<User?>.broadcast(
    sync: true,
  );

  User? _user = _FakeUser('uid-a');

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() {
    return _controller.stream;
  }

  void changeUser(String? uid) {
    changeToUser(uid == null ? null : _FakeUser(uid));
  }

  void changeToUser(User? user) {
    _user = user;

    _controller.add(user);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final List<String> readPaths = [];
  final List<String> deletedPaths = [];

  final Completer<void> firstReadStarted = Completer<void>();

  Completer<void>? firstReadGate;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCollectionReference(
      database: this,
      collectionPath: collectionPath,
    );
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String documentPath) {
    return _FakeDocumentReference(database: this, documentPath: documentPath);
  }

  @override
  Future<void> waitForPendingWrites() async {}
}

class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference({
    required this.database,
    required this.collectionPath,
  });

  final _FakeFirestore database;
  final String collectionPath;

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    database.readPaths.add(collectionPath);

    if (database.readPaths.length == 1) {
      if (!database.firstReadStarted.isCompleted) {
        database.firstReadStarted.complete();
      }

      final gate = database.firstReadGate;

      if (gate != null) {
        await gate.future;
      }
    }

    return _FakeQuerySnapshot();
  }
}

class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs {
    return [];
  }
}

class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference({required this.database, required this.documentPath});

  final _FakeFirestore database;
  final String documentPath;

  @override
  Future<void> delete() async {
    database.deletedPaths.add(documentPath);
  }
}
