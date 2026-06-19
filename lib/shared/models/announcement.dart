import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.scope,
    required this.priority,
    required this.status,
    required this.createdBy,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
    required this.publishAt,
    this.projectId,
    this.projectName,
    this.district,
    this.expiresAt,
    this.imageUrl,
    this.imageStoragePath,
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementScope scope;
  final AnnouncementPriority priority;
  final AnnouncementStatus status;
  final String createdBy;
  final String authorName;
  final UserRole authorRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime publishAt;
  final String? projectId;
  final String? projectName;
  final String? district;
  final DateTime? expiresAt;
  final String? imageUrl;
  final String? imageStoragePath;

  factory Announcement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return Announcement.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory Announcement.fromMap(Map<String, dynamic> data, {String? id}) {
    final createdAt = FirestoreModelUtils.readDate(data['createdAt']);
    return Announcement(
      id: id ?? data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      scope: AnnouncementScope.fromValue(data['scope'] as String?),
      priority: AnnouncementPriority.fromValue(data['priority'] as String?),
      status: AnnouncementStatus.fromValue(data['status'] as String?),
      projectId: data['projectId'] as String?,
      projectName: data['projectName'] as String?,
      district: data['district'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: UserRole.fromValue(data['authorRole'] as String?),
      createdAt: createdAt,
      updatedAt:
          FirestoreModelUtils.readOptionalDate(data['updatedAt']) ?? createdAt,
      publishAt:
          FirestoreModelUtils.readOptionalDate(data['publishAt']) ?? createdAt,
      expiresAt: FirestoreModelUtils.readOptionalDate(data['expiresAt']),
      imageUrl: data['imageUrl'] as String?,
      imageStoragePath: data['imageStoragePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scope': scope.value,
      'priority': priority.value,
      'status': status.value,
      'projectId': projectId,
      'projectName': projectName,
      'district': district,
      'createdBy': createdBy,
      'authorName': authorName,
      'authorRole': authorRole.value,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'publishAt': FirestoreModelUtils.timestamp(publishAt),
      'expiresAt': FirestoreModelUtils.optionalTimestamp(expiresAt),
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
    };
  }

  Announcement copyWith({AnnouncementStatus? status, DateTime? updatedAt}) {
    return Announcement(
      id: id,
      title: title,
      body: body,
      scope: scope,
      priority: priority,
      status: status ?? this.status,
      projectId: projectId,
      projectName: projectName,
      district: district,
      createdBy: createdBy,
      authorName: authorName,
      authorRole: authorRole,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishAt: publishAt,
      expiresAt: expiresAt,
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
    );
  }
}
