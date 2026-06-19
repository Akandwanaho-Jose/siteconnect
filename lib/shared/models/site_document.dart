import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class SiteDocument {
  const SiteDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.visibility,
    required this.status,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.projectId,
    this.version = 1,
    this.fileSizeBytes,
  });

  final String id;
  final String? projectId;
  final String title;
  final DocumentType type;
  final DocumentVisibility visibility;
  final DocumentStatus status;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final int version;
  final int? fileSizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory SiteDocument.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return SiteDocument.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory SiteDocument.fromMap(Map<String, dynamic> data, {String? id}) {
    return SiteDocument(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String?,
      title: data['title'] as String? ?? '',
      type: DocumentType.fromValue(data['type'] as String?),
      visibility: DocumentVisibility.fromValue(data['visibility'] as String?),
      status: DocumentStatus.fromValue(data['status'] as String?),
      fileName: data['fileName'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      version: FirestoreModelUtils.readInt(data['version'], fallback: 1),
      fileSizeBytes: data['fileSizeBytes'] == null
          ? null
          : FirestoreModelUtils.readInt(data['fileSizeBytes']),
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
      'type': type.value,
      'visibility': visibility.value,
      'status': status.value,
      'fileName': fileName,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'version': version,
      'fileSizeBytes': fileSizeBytes,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }
}
