import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreModelUtils {
  const FirestoreModelUtils._();

  static DateTime readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? readOptionalDate(Object? value) {
    if (value == null) {
      return null;
    }

    return readDate(value);
  }

  static double? readOptionalDouble(Object? value) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  static int readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  static bool readBool(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }

    return fallback;
  }

  static List<String> readStringList(Object? value) {
    if (value is Iterable) {
      return value.whereType<String>().toList(growable: false);
    }

    return const <String>[];
  }

  static Timestamp timestamp(DateTime value) {
    return Timestamp.fromDate(value);
  }

  static Timestamp? optionalTimestamp(DateTime? value) {
    return value == null ? null : Timestamp.fromDate(value);
  }
}
