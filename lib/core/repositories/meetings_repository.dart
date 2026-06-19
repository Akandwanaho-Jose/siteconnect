import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/meeting.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class MeetingsRepository extends FirestoreRepository<Meeting> {
  MeetingsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.meetings);

  @override
  Meeting fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return Meeting.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(Meeting model) => model.toMap();

  @override
  String documentId(Meeting model) => model.id;

  Query<Map<String, dynamic>> meetingsForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('meetingDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> upcomingMeetingsForProject(
    String projectId,
    DateTime fromDate, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: MeetingStatus.scheduled.value)
        .where(
          'meetingDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
        )
        .orderBy('meetingDate')
        .limit(limit);
  }

  Query<Map<String, dynamic>> meetingsForParticipant(
    String userId, {
    int limit = 50,
  }) {
    return collection
        .where('participantIds', arrayContains: userId)
        .orderBy('meetingDate', descending: true)
        .limit(limit);
  }
}
