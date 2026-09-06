import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/routine.dart';
import '../mappers/routine_mapper.dart';
import 'routine_remote_service.dart';

class FirestoreRoutineService implements RoutineRemoteService {
  FirestoreRoutineService(this._firestore, this._firebaseAuth);

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

    routines.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

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
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.routineDocument(
      uid: uid,
      anonymousId: anonymousId,
      routineId: routineId,
    );

    await _firestore.doc(path).update({'activa': false});

    await _firestore.waitForPendingWrites();
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
