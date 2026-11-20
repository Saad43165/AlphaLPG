import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a date stored as a Firestore [Timestamp], [DateTime] or ISO string.
DateTime? readDate(Object? v) => switch (v) {
  final Timestamp t => t.toDate(),
  final DateTime d => d,
  final String s => DateTime.tryParse(s),
  _ => null,
};
