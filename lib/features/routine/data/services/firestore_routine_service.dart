import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/routine.dart';
import '../mappers/routine_mapper.dart';
import 'routine_remote_service.dart';

class FirestoreRoutineService implements RoutineRemoteService {
  FirestoreRoutineService(this._firestore, this._firebaseAuth);

  static const String _routineStatusRecordType = 'estadoRutina';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> createRoutine(Routine routine) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.routineDocument(
      uid: uid,
      anonymousId: routine.anonymousId,
      routineId: routine.routineId,
    );

    await _firestore.doc(path).set(RoutineMapper.toFirestore(routine));

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.routinesCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .get(const GetOptions(source: Source.server));

    final routines = snapshot.docs
        .map(
          (document) => RoutineMapper.fromFirestore(
            routineId: document.id,
            anonymousId: anonymousId,
            data: document.data(),
          ),
        )
        .toList();

    routines.sort(
      (first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );

    return List.unmodifiable(routines);
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.routineDocument(
      uid: uid,
      anonymousId: routine.anonymousId,
      routineId: routine.routineId,
    );

    await _firestore.doc(path).set(RoutineMapper.toFirestore(routine));

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final routineReference = _firestore.doc(
      TrackingFirestorePaths.routineDocument(
        uid: uid,
        anonymousId: anonymousId,
        routineId: routineId,
      ),
    );

    final recordsCollection = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final statusSnapshot = await _firestore
        .collection(recordsCollection)
        .where('tipoRegistro', isEqualTo: _routineStatusRecordType)
        .where('datos.idRutina', isEqualTo: routineId)
        .get(const GetOptions(source: Source.server));

    final statusReferences = statusSnapshot.docs
        .map((document) => document.reference)
        .toList(growable: false);

    await _deleteRoutineWithStatuses(
      routineReference: routineReference,
      statusReferences: statusReferences,
    );

    await _firestore.waitForPendingWrites();
  }

  Future<void> _deleteRoutineWithStatuses({
    required DocumentReference<Map<String, dynamic>> routineReference,
    required List<DocumentReference<Map<String, dynamic>>> statusReferences,
  }) async {
    const maximumStatusWritesPerBatch = 450;

    var start = 0;

    while (statusReferences.length - start > maximumStatusWritesPerBatch) {
      final batch = _firestore.batch();

      final end = start + maximumStatusWritesPerBatch;

      for (final reference in statusReferences.sublist(start, end)) {
        batch.delete(reference);
      }

      await batch.commit();

      start = end;
    }

    final finalBatch = _firestore.batch();

    for (final reference in statusReferences.sublist(start)) {
      finalBatch.delete(reference);
    }

    finalBatch.delete(routineReference);

    await finalBatch.commit();
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing routines.',
      );
    }

    return user.uid;
  }
}
