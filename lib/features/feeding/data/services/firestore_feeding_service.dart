import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/feeding_record.dart';
import '../mappers/feeding_record_mapper.dart';
import 'feeding_remote_service.dart';

class FirestoreFeedingService implements FeedingRemoteService {
  FirestoreFeedingService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.trackingRecordDocument(
      uid: uid,
      anonymousId: record.anonymousId,
      recordId: record.recordId,
    );

    await _firestore
        .doc(path)
        .set(
          FeedingRecordMapper.toFirestore(record: record, operationUid: uid),
        );

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .where('tipoRegistro', isEqualTo: FeedingRecordMapper.recordType)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => FeedingRecordMapper.fromFirestore(
            recordId: document.id,
            anonymousId: anonymousId,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing feeding records.',
      );
    }

    return user.uid;
  }
}
