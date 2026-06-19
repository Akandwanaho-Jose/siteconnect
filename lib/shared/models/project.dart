import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.district,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.projectCode,
    this.contractorName,
    this.projectManagerId,
    this.startDate,
    this.expectedEndDate,
    this.budgetAmount,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? projectCode;
  final String name;
  final String description;
  final String district;
  final ProjectStatus status;
  final String? contractorName;
  final String? projectManagerId;
  final DateTime? startDate;
  final DateTime? expectedEndDate;
  final double? budgetAmount;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory Project.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return Project.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory Project.fromMap(Map<String, dynamic> data, {String? id}) {
    return Project(
      id: id ?? data['id'] as String? ?? '',
      projectCode: data['projectCode'] as String?,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      district: data['district'] as String? ?? '',
      status: ProjectStatus.fromValue(data['status'] as String?),
      contractorName: data['contractorName'] as String?,
      projectManagerId: data['projectManagerId'] as String?,
      startDate: FirestoreModelUtils.readOptionalDate(data['startDate']),
      expectedEndDate: FirestoreModelUtils.readOptionalDate(
        data['expectedEndDate'],
      ),
      budgetAmount: FirestoreModelUtils.readOptionalDouble(
        data['budgetAmount'],
      ),
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
      'projectCode': projectCode,
      'name': name,
      'description': description,
      'district': district,
      'status': status.value,
      'contractorName': contractorName,
      'projectManagerId': projectManagerId,
      'startDate': FirestoreModelUtils.optionalTimestamp(startDate),
      'expectedEndDate': FirestoreModelUtils.optionalTimestamp(expectedEndDate),
      'budgetAmount': budgetAmount,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }

  Project copyWith({
    String? id,
    String? projectCode,
    String? name,
    String? description,
    String? district,
    ProjectStatus? status,
    String? contractorName,
    String? projectManagerId,
    DateTime? startDate,
    DateTime? expectedEndDate,
    double? budgetAmount,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return Project(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      description: description ?? this.description,
      district: district ?? this.district,
      status: status ?? this.status,
      contractorName: contractorName ?? this.contractorName,
      projectManagerId: projectManagerId ?? this.projectManagerId,
      startDate: startDate ?? this.startDate,
      expectedEndDate: expectedEndDate ?? this.expectedEndDate,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
