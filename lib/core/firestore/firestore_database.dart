import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';

class FirestoreDatabase {
  FirestoreDatabase({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get users =>
      firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get projects =>
      firestore.collection(FirestoreCollections.projects);

  CollectionReference<Map<String, dynamic>> get projectMembers =>
      firestore.collection(FirestoreCollections.projectMembers);

  CollectionReference<Map<String, dynamic>> get siteReports =>
      firestore.collection(FirestoreCollections.siteReports);

  CollectionReference<Map<String, dynamic>> get reportPhotos =>
      firestore.collection(FirestoreCollections.reportPhotos);

  CollectionReference<Map<String, dynamic>> get documents =>
      firestore.collection(FirestoreCollections.documents);

  CollectionReference<Map<String, dynamic>> get notifications =>
      firestore.collection(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>> get environmentalReports =>
      firestore.collection(FirestoreCollections.environmentalReports);

  CollectionReference<Map<String, dynamic>> get communityFeedback =>
      firestore.collection(FirestoreCollections.communityFeedback);

  CollectionReference<Map<String, dynamic>> get meetings =>
      firestore.collection(FirestoreCollections.meetings);

  WriteBatch batch() => firestore.batch();
}
