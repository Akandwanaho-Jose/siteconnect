import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class AppUser {
  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phoneNumber,
    required this.district,
    required this.createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    this.profileImage,
    this.createdBy,
  }) : updatedAt = updatedAt ?? createdAt;

  final String uid;
  final String fullName;
  final String email;
  final UserRole role;
  final String phoneNumber;
  final String district;
  final String? profileImage;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AppUser.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> data, {String? id}) {
    final createdAt = FirestoreModelUtils.readDate(data['createdAt']);
    return AppUser(
      uid: id ?? data['uid'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.fromValue(data['role'] as String?),
      phoneNumber: data['phoneNumber'] as String? ?? '',
      district: data['district'] as String? ?? '',
      profileImage: data['profileImage'] as String?,
      isActive: FirestoreModelUtils.readBool(data['isActive'], fallback: true),
      createdAt: createdAt,
      updatedAt:
          FirestoreModelUtils.readOptionalDate(data['updatedAt']) ?? createdAt,
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role.value,
      'phoneNumber': phoneNumber,
      'district': district,
      'profileImage': profileImage,
      'isActive': isActive,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }

  AppUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    UserRole? role,
    String? phoneNumber,
    String? district,
    String? profileImage,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      district: district ?? this.district,
      profileImage: profileImage ?? this.profileImage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
