import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/project_member.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import '../constants/user_roles.dart';
import 'firestore_repository.dart';

class ProjectMembersRepository extends FirestoreRepository<ProjectMember> {
  ProjectMembersRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.projectMembers);

  @override
  ProjectMember fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return ProjectMember.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(ProjectMember model) => model.toMap();

  @override
  String documentId(ProjectMember model) => model.id;

  Query<Map<String, dynamic>> membersForProject(
    String projectId, {
    int limit = 100,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: ProjectMemberStatus.active.value)
        .orderBy('role')
        .limit(limit);
  }

  Query<Map<String, dynamic>> allMembersForProject(
    String projectId, {
    int limit = 100,
  }) {
    return collection.where('projectId', isEqualTo: projectId).limit(limit);
  }

  Query<Map<String, dynamic>> membershipsForUser(
    String userId, {
    int limit = 100,
  }) {
    return collection
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: ProjectMemberStatus.active.value)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> activeMembershipsForUser(
    String userId, {
    int limit = 100,
  }) {
    return collection.where('userId', isEqualTo: userId).limit(limit);
  }

  Query<Map<String, dynamic>> membersByRole(
    String projectId,
    UserRole role, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('role', isEqualTo: role.value)
        .where('status', isEqualTo: ProjectMemberStatus.active.value)
        .limit(limit);
  }
}
