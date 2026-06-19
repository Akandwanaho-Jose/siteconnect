import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/app_user.dart';
import '../constants/user_roles.dart';
import 'project_members_repository.dart';
import 'projects_repository.dart';

class RoleBasedQueryService {
  const RoleBasedQueryService({
    required this.projectsRepository,
    required this.projectMembersRepository,
  });

  final ProjectsRepository projectsRepository;
  final ProjectMembersRepository projectMembersRepository;

  /// Some roles can query projects directly by a stable field. Assigned
  /// technical roles should first read project_members by userId, then load
  /// only the returned project ids.
  Query<Map<String, dynamic>>? directProjectsForUser(
    AppUser user, {
    int limit = 50,
  }) {
    return switch (user.role) {
      UserRole.administrator => projectsRepository.recent(limit: limit),
      UserRole.projectManager => projectsRepository.projectsManagedBy(
        user.uid,
        limit: limit,
      ),
      UserRole.procurementOfficer ||
      UserRole.environmentOfficer ||
      UserRole.communityDevelopmentOfficer ||
      UserRole.communityRepresentative => projectsRepository.projectsByDistrict(
        user.district,
        limit: limit,
      ),
      UserRole.districtEngineer ||
      UserRole.siteEngineer ||
      UserRole.contractor ||
      UserRole.consultant ||
      UserRole.clerkOfWorks ||
      UserRole.unknown => null,
    };
  }

  Query<Map<String, dynamic>> membershipsForUser(
    String userId, {
    int limit = 100,
  }) {
    return projectMembersRepository.activeMembershipsForUser(
      userId,
      limit: limit,
    );
  }
}
