import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/event_record.dart';
import '../../domain/models/event_record_type.dart';
import '../mappers/event_record_mapper.dart';
import 'event_remote_service.dart';

class FirestoreEventService implements EventRemoteService {
  FirestoreEventService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;

  final FirebaseAuth _firebaseAuth;

  static final Set<String> _eventTypeCodes = EventRecordType.values
      .map((type) => type.code)
      .toSet();

  @override
  Future<List<EventRecord>> recoverEvents({required String anonymousId}) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    final events = <EventRecord>[];

    for (final document in snapshot.docs) {
      final data = document.data();

      final rawRecordType = data['tipoRegistro'];

      if (rawRecordType is! String ||
          !_eventTypeCodes.contains(rawRecordType)) {
        continue;
      }

      events.add(
        EventRecordMapper.fromFirestore(
          recordId: document.id,
          anonymousId: anonymousId,
          data: data,
        ),
      );
    }

    return List.unmodifiable(events);
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing event records.',
      );
    }

    return user.uid;
  }
}
