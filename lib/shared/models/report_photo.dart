import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/firestore/firestore_model_utils.dart';

class ReportPhoto {
  const ReportPhoto({
    required this.id,
    required this.projectId,
    required this.reportId,
    required this.storagePath,
    required this.downloadUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.caption,
    this.takenAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String projectId;
  final String reportId;
  final String storagePath;
  final String downloadUrl;
  final String? caption;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory ReportPhoto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReportPhoto.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory ReportPhoto.fromMap(Map<String, dynamic> data, {String? id}) {
    return ReportPhoto(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      reportId: data['reportId'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      caption: data['caption'] as String?,
      takenAt: FirestoreModelUtils.readOptionalDate(data['takenAt']),
      latitude: FirestoreModelUtils.readOptionalDouble(data['latitude']),
      longitude: FirestoreModelUtils.readOptionalDouble(data['longitude']),
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'reportId': reportId,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'caption': caption,
      'takenAt': FirestoreModelUtils.optionalTimestamp(takenAt),
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }

  ReportPhoto copyWith({
    String? id,
    String? projectId,
    String? reportId,
    String? storagePath,
    String? downloadUrl,
    String? caption,
    DateTime? takenAt,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ReportPhoto(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      reportId: reportId ?? this.reportId,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      caption: caption ?? this.caption,
      takenAt: takenAt ?? this.takenAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
