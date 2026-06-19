import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/site_document.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class DocumentsRepository extends FirestoreRepository<SiteDocument> {
  DocumentsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.documents);

  @override
  SiteDocument fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return SiteDocument.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(SiteDocument model) => model.toMap();

  @override
  String documentId(SiteDocument model) => model.id;

  Query<Map<String, dynamic>> documentsForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: DocumentStatus.active.value)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> documentsByType(
    String projectId,
    DocumentType type, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('type', isEqualTo: type.value)
        .where('status', isEqualTo: DocumentStatus.active.value)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> publicDocuments({int limit = 50}) {
    return collection
        .where('visibility', isEqualTo: DocumentVisibility.public.value)
        .where('status', isEqualTo: DocumentStatus.active.value)
        .orderBy('updatedAt', descending: true)
        .limit(limit);
  }
}
