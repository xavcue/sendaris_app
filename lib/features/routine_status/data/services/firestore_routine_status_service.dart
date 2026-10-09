import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/routine_status_record.dart';
import '../mappers/routine_status_record_mapper.dart';
import 'routine_status_remote_service.dart';

class FirestoreRoutineStatusService
    implements RoutineStatusManagementRemoteService {
  FirestoreRoutineStatusService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    await _writeRoutineStatus(record);
  }

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {
    await _writeRoutineStatus(record);
  }

  Future<void> _writeRoutineStatus(RoutineStatusRecord record) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.trackingRecordDocument(
      uid: uid,
      anonymousId: record.anonymousId,
      recordId: record.recordId,
    );

    await _firestore
        .doc(path)
        .set(
          RoutineStatusRecordMapper.toFirestore(
            record: record,
            operationUid: uid,
          ),
        );

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .where('tipoRegistro', isEqualTo: RoutineStatusRecordMapper.recordType)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => RoutineStatusRecordMapper.fromFirestore(
            recordId: document.id,
            anonymousId: anonymousId,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.trackingRecordDocument(
      uid: uid,
      anonymousId: anonymousId,
      recordId: recordId,
    );

    await _firestore.doc(path).delete();

    await _firestore.waitForPendingWrites();
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing routine status records.',
      );
    }

    return user.uid;
  }
}
