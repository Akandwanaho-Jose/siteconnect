import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.assignedAt,
  });

  final String id;
  final String projectId;
  final String userId;
  final UserRole role;
  final ProjectMemberStatus status;
  final DateTime? assignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory ProjectMember.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ProjectMember.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory ProjectMember.fromMap(Map<String, dynamic> data, {String? id}) {
    return ProjectMember(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      role: UserRole.fromValue(data['role'] as String?),
      status: ProjectMemberStatus.fromValue(data['status'] as String?),
      assignedAt: FirestoreModelUtils.readOptionalDate(data['assignedAt']),
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'userId': userId,
      'role': role.value,
      'status': status.value,
      'assignedAt': FirestoreModelUtils.optionalTimestamp(assignedAt),
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }

  ProjectMember copyWith({
    String? id,
    String? projectId,
    String? userId,
    UserRole? role,
    ProjectMemberStatus? status,
    DateTime? assignedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ProjectMember(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
