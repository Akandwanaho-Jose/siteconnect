import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/app_user.dart';
import '../constants/firestore_collections.dart';
import '../constants/user_roles.dart';
import 'firestore_repository.dart';

class UsersRepository extends FirestoreRepository<AppUser> {
  UsersRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.users);

  @override
  AppUser fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return AppUser.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(AppUser model) => model.toMap();

  @override
  String documentId(AppUser model) => model.uid;

  Query<Map<String, dynamic>> allUsers({int limit = 100}) {
    return collection.orderBy('fullName').limit(limit);
  }

  Query<Map<String, dynamic>> usersByRole(UserRole role, {int limit = 50}) {
    return collection
        .where('role', isEqualTo: role.value)
        .orderBy('fullName')
        .limit(limit);
  }

  Query<Map<String, dynamic>> usersByDistrict(
    String district, {
    int limit = 50,
  }) {
    return collection
        .where('district', isEqualTo: district)
        .orderBy('fullName')
        .limit(limit);
  }
}
