import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/sleep_record.dart';
import '../mappers/sleep_record_mapper.dart';
import 'sleep_remote_service.dart';

class FirestoreSleepService implements SleepManagementRemoteService {
  FirestoreSleepService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> saveSleep(SleepRecord record) async {
    await _writeSleep(record);
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {
    await _writeSleep(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .where('tipoRegistro', isEqualTo: SleepRecordMapper.recordType)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => SleepRecordMapper.fromFirestore(
            recordId: document.id,
            anonymousId: anonymousId,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteSleep({
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

  Future<void> _writeSleep(SleepRecord record) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.trackingRecordDocument(
      uid: uid,
      anonymousId: record.anonymousId,
      recordId: record.recordId,
    );

    await _firestore
        .doc(path)
        .set(SleepRecordMapper.toFirestore(record: record, operationUid: uid));

    await _firestore.waitForPendingWrites();
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing sleep records.',
      );
    }

    return user.uid;
  }
}
