import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class Meeting {
  const Meeting({
    required this.id,
    required this.projectId,
    required this.title,
    required this.agenda,
    required this.meetingDate,
    required this.venue,
    required this.organizerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.participantIds = const <String>[],
    this.minutesDocumentId,
  });

  final String id;
  final String projectId;
  final String title;
  final String agenda;
  final DateTime meetingDate;
  final String venue;
  final String organizerId;
  final List<String> participantIds;
  final String? minutesDocumentId;
  final MeetingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory Meeting.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return Meeting.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory Meeting.fromMap(Map<String, dynamic> data, {String? id}) {
    return Meeting(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      agenda: data['agenda'] as String? ?? '',
      meetingDate: FirestoreModelUtils.readDate(data['meetingDate']),
      venue: data['venue'] as String? ?? '',
      organizerId: data['organizerId'] as String? ?? '',
      participantIds: FirestoreModelUtils.readStringList(
        data['participantIds'],
      ),
      minutesDocumentId: data['minutesDocumentId'] as String?,
      status: MeetingStatus.fromValue(data['status'] as String?),
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'agenda': agenda,
      'meetingDate': FirestoreModelUtils.timestamp(meetingDate),
      'venue': venue,
      'organizerId': organizerId,
      'participantIds': participantIds,
      'minutesDocumentId': minutesDocumentId,
      'status': status.value,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }
}
