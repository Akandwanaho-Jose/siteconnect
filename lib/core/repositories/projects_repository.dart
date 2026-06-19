import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/project.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class ProjectsRepository extends FirestoreRepository<Project> {
  ProjectsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.projects);

  @override
  Project fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return Project.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(Project model) => model.toMap();

  @override
  String documentId(Project model) => model.id;

  Query<Map<String, dynamic>> projectsByDistrict(
    String district, {
    int limit = 50,
  }) {
    return collection
        .where('district', isEqualTo: district)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> projectsByStatus(
    ProjectStatus status, {
    int limit = 50,
  }) {
    return collection
        .where('status', isEqualTo: status.value)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> projectsManagedBy(
    String userId, {
    int limit = 50,
  }) {
    return collection
        .where('projectManagerId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }
}
