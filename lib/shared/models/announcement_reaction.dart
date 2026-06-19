import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class AnnouncementReaction {
  const AnnouncementReaction({
    required this.id,
    required this.announcementId,
    required this.type,
    required this.createdBy,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String announcementId;
  final AnnouncementReactionType type;
  final String createdBy;
  final String authorName;
  final UserRole authorRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AnnouncementReaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AnnouncementReaction.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory AnnouncementReaction.fromMap(
    Map<String, dynamic> data, {
    String? id,
  }) {
    final createdAt = FirestoreModelUtils.readDate(data['createdAt']);
    return AnnouncementReaction(
      id: id ?? data['id'] as String? ?? '',
      announcementId: data['announcementId'] as String? ?? '',
      type: AnnouncementReactionType.fromValue(data['type'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: UserRole.fromValue(data['authorRole'] as String?),
      createdAt: createdAt,
      updatedAt:
          FirestoreModelUtils.readOptionalDate(data['updatedAt']) ?? createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'announcementId': announcementId,
      'type': type.value,
      'createdBy': createdBy,
      'authorName': authorName,
      'authorRole': authorRole.value,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
    };
  }
}
