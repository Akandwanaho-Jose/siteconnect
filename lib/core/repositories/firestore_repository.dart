import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FirestoreRepository<T> {
  FirestoreRepository({
    FirebaseFirestore? firestore,
    required this.collectionPath,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  final String collectionPath;

  CollectionReference<Map<String, dynamic>> get collection {
    return firestore.collection(collectionPath);
  }

  T fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot);

  Map<String, dynamic> toMap(T model);

  String documentId(T model);

  DocumentReference<Map<String, dynamic>> doc(String id) {
    return collection.doc(id);
  }

  Future<T?> findById(String id) async {
    final snapshot = await doc(id).get();
    if (!snapshot.exists) {
      return null;
    }

    return fromSnapshot(snapshot);
  }

  Stream<T?> watchById(String id) {
    return doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return fromSnapshot(snapshot);
    });
  }

  Stream<List<T>> watchQuery(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map(fromSnapshot).toList(growable: false);
    });
  }

  Future<List<T>> getQuery(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.get();
    return snapshot.docs.map(fromSnapshot).toList(growable: false);
  }

  Future<void> save(T model, {bool merge = true}) {
    final id = documentId(model);
    if (id.isEmpty) {
      throw ArgumentError('Firestore document id cannot be empty.');
    }

    return doc(id).set(toMap(model), SetOptions(merge: merge));
  }

  Future<void> updateFields(String id, Map<String, dynamic> fields) {
    return doc(
      id,
    ).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteById(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Firestore document id cannot be empty.');
    }

    return doc(id).delete();
  }

  String newDocumentId() => collection.doc().id;

  Query<Map<String, dynamic>> recent({int limit = 50}) {
    return collection.orderBy('createdAt', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> updatedSince(
    DateTime timestamp, {
    int limit = 100,
  }) {
    return collection
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(timestamp))
        .orderBy('updatedAt')
        .limit(limit);
  }
}
