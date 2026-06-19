import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class AnnouncementComment {
  const AnnouncementComment({
    required this.id,
    required this.announcementId,
    required this.body,
    required this.createdBy,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
    this.parentCommentId,
    this.replyToAuthorName,
  });

  final String id;
  final String announcementId;
  final String body;
  final String createdBy;
  final String authorName;
  final UserRole authorRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentCommentId;
  final String? replyToAuthorName;

  factory AnnouncementComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AnnouncementComment.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory AnnouncementComment.fromMap(Map<String, dynamic> data, {String? id}) {
    final createdAt = FirestoreModelUtils.readDate(data['createdAt']);
    return AnnouncementComment(
      id: id ?? data['id'] as String? ?? '',
      announcementId: data['announcementId'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: UserRole.fromValue(data['authorRole'] as String?),
      createdAt: createdAt,
      updatedAt:
          FirestoreModelUtils.readOptionalDate(data['updatedAt']) ?? createdAt,
      parentCommentId: data['parentCommentId'] as String?,
      replyToAuthorName: data['replyToAuthorName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'announcementId': announcementId,
      'body': body,
      'createdBy': createdBy,
      'authorName': authorName,
      'authorRole': authorRole.value,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'parentCommentId': parentCommentId,
      'replyToAuthorName': replyToAuthorName,
    };
  }
}
