import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class CommunityFeedback {
  const CommunityFeedback({
    required this.id,
    required this.type,
    required this.status,
    required this.priority,
    required this.description,
    required this.district,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.submittedBy,
    this.communityName,
    this.contactPhone,
    this.assignedTo,
    this.resolution,
    this.createdBy,
  });

  final String id;
  final String? projectId;
  final String? submittedBy;
  final String? communityName;
  final String? contactPhone;
  final FeedbackType type;
  final FeedbackStatus status;
  final FeedbackPriority priority;
  final String description;
  final String district;
  final String? assignedTo;
  final String? resolution;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CommunityFeedback.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return CommunityFeedback.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory CommunityFeedback.fromMap(Map<String, dynamic> data, {String? id}) {
    return CommunityFeedback(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String?,
      submittedBy: data['submittedBy'] as String?,
      communityName: data['communityName'] as String?,
      contactPhone: data['contactPhone'] as String?,
      type: FeedbackType.fromValue(data['type'] as String?),
      status: FeedbackStatus.fromValue(data['status'] as String?),
      priority: FeedbackPriority.fromValue(data['priority'] as String?),
      description: data['description'] as String? ?? '',
      district: data['district'] as String? ?? '',
      assignedTo: data['assignedTo'] as String?,
      resolution: data['resolution'] as String?,
      createdBy: data['createdBy'] as String?,
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'submittedBy': submittedBy,
      'communityName': communityName,
      'contactPhone': contactPhone,
      'type': type.value,
      'status': status.value,
      'priority': priority.value,
      'description': description,
      'district': district,
      'assignedTo': assignedTo,
      'resolution': resolution,
      'createdBy': createdBy,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
    };
  }
}
