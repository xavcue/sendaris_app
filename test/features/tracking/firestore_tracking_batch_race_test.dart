// Los dobles implementan interfaces restringidas del SDK
// exclusivamente para pruebas sin conexion a Firebase.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/tracking/data/services/firestore_tracking_service.dart';

void main() {
  group('FirestoreTrackingService - concurrencia en lotes', () {
    const root = 'usuarios/uid-a/seguimientos/seguimiento-a';

    const records = '$root/registros';
    const routines = '$root/rutinas';

    late _BatchFirestore firestore;
    late _SessionAuth auth;
    late FirestoreTrackingService service;

    setUp(() {
      firestore = _BatchFirestore();
      auth = _SessionAuth();

      service = FirestoreTrackingService(firestore, auth);
    });

    tearDown(() async {
      await auth.dispose();
    });

    test('una eliminacion normal confirma lote y documento', () async {
      await service.deleteProfile('seguimiento-a');

      expect(firestore.readPaths, [records, routines]);

      expect(firestore.commitCalls, 1);

      expect(firestore.committedBatchPaths, ['$records/registro-0']);

      expect(firestore.deletedRootPaths, [root]);
      expect(firestore.pendingWritesCalls, 1);
    });

    test('un lote completo de 400 documentos termina correctamente', () async {
      firestore.recordsCount = 400;

      await service.deleteProfile('seguimiento-a');

      expect(firestore.readPaths, [records, records, routines]);

      expect(firestore.commitCalls, 1);
      expect(firestore.committedBatchPaths.length, 400);
      expect(firestore.deletedRootPaths, [root]);
    });

    test('cambiar a B durante commit impide nuevas operaciones', () async {
      firestore.recordsCount = 400;
      firestore.firstCommitGate = Completer<void>();

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstCommitStarted.future;

      expect(firestore.commitCalls, 1);
      expect(firestore.readPaths, [records]);

      auth.changeUser('uid-b');

      firestore.firstCommitGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(
        firestore.commitCalls,
        1,
        reason: 'El lote iniciado no debe repetirse.',
      );

      expect(
        firestore.readPaths,
        [records],
        reason:
            'La operacion antigua no debe iniciar '
            'la siguiente consulta.',
      );

      expect(firestore.deletedRootPaths, isEmpty);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test('A a B a A durante commit no reanuda la eliminacion', () async {
      firestore.recordsCount = 400;
      firestore.firstCommitGate = Completer<void>();

      final originalUser = auth.currentUser;

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstCommitStarted.future;

      auth.changeUser('uid-b');
      auth.changeToUser(originalUser);

      firestore.firstCommitGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      expect(firestore.commitCalls, 1);
      expect(firestore.readPaths, [records]);
      expect(firestore.deletedRootPaths, isEmpty);
      expect(auth.currentUser?.uid, 'uid-a');
    });

    test('cambiar a B durante el borrado principal '
        'no continua con operaciones posteriores', () async {
      firestore.rootDeleteGate = Completer<void>();

      final operation = service.deleteProfile('seguimiento-a');

      await firestore.firstRootDeleteStarted.future;

      expect(firestore.deletedRootPaths, [root]);

      auth.changeUser('uid-b');

      firestore.rootDeleteGate!.complete();

      await expectLater(operation, throwsA(isA<StateError>()));

      // El borrado principal ya habia comenzado.
      // No es posible deshacerlo desde el cliente.
      expect(firestore.deletedRootPaths, [root]);

      // No deben ejecutarse operaciones posteriores
      // pertenecientes a la sesion anterior.
      expect(firestore.pendingWritesCalls, 0);

      expect(auth.currentUser?.uid, 'uid-b');
    });
  });
}

class _SessionAuth extends Fake implements FirebaseAuth {
  final StreamController<User?> _controller = StreamController<User?>.broadcast(
    sync: true,
  );

  User? _current = _SessionUser('uid-a');

  @override
  User? get currentUser => _current;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  void changeUser(String? uid) {
    changeToUser(uid == null ? null : _SessionUser(uid));
  }

  void changeToUser(User? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() => _controller.close();
}

class _SessionUser extends Fake implements User {
  _SessionUser(this.uid);

  @override
  final String uid;
}

class _BatchFirestore extends Fake implements FirebaseFirestore {
  int recordsCount = 1;
  int commitCalls = 0;
  int pendingWritesCalls = 0;

  bool _recordsRead = false;

  final readPaths = <String>[];
  final committedBatchPaths = <String>[];
  final deletedRootPaths = <String>[];

  final firstCommitStarted = Completer<void>();
  final firstRootDeleteStarted = Completer<void>();

  Completer<void>? firstCommitGate;
  Completer<void>? rootDeleteGate;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _BatchCollection(database: this, collectionPath: path);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return _BatchDocument(database: this, documentPath: path);
  }

  @override
  WriteBatch batch() {
    return _ControlledWriteBatch(this);
  }

  @override
  Future<void> waitForPendingWrites() async {
    pendingWritesCalls++;
  }
}

class _BatchCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _BatchCollection({required this.database, required this.collectionPath});

  final _BatchFirestore database;
  final String collectionPath;

  @override
  Query<Map<String, dynamic>> limit(int limit) => this;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    database.readPaths.add(collectionPath);

    if (collectionPath.endsWith('/registros') && !database._recordsRead) {
      database._recordsRead = true;

      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.generate(
        database.recordsCount,
        (index) => _BatchDocumentSnapshot(
          _BatchDocument(
            database: database,
            documentPath: '$collectionPath/registro-$index',
          ),
        ),
      );

      return _BatchQuerySnapshot(docs);
    }

    return _BatchQuerySnapshot(const []);
  }
}

class _BatchQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _BatchQuerySnapshot(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
}

class _BatchDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _BatchDocumentSnapshot(this._reference);

  final DocumentReference<Map<String, dynamic>> _reference;

  @override
  DocumentReference<Map<String, dynamic>> get reference => _reference;
}

class _BatchDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _BatchDocument({required this.database, required this.documentPath});

  final _BatchFirestore database;
  final String documentPath;

  @override
  String get path => documentPath;

  @override
  Future<void> delete() async {
    database.deletedRootPaths.add(documentPath);

    if (!database.firstRootDeleteStarted.isCompleted) {
      database.firstRootDeleteStarted.complete();
    }

    final gate = database.rootDeleteGate;

    if (gate != null) {
      await gate.future;
    }
  }
}

class _ControlledWriteBatch extends Fake implements WriteBatch {
  _ControlledWriteBatch(this.database);

  final _BatchFirestore database;
  final List<String> _queuedPaths = [];

  @override
  void delete(DocumentReference<Object?> document) {
    _queuedPaths.add(document.path);
  }

  @override
  Future<void> commit() async {
    database.commitCalls++;

    if (!database.firstCommitStarted.isCompleted) {
      database.firstCommitStarted.complete();
    }

    final gate = database.firstCommitGate;

    if (gate != null) {
      await gate.future;
    }

    // Representa un lote que ya se confirmo.
    // Un cambio posterior de sesion no lo revierte.
    database.committedBatchPaths.addAll(_queuedPaths);
  }
}
