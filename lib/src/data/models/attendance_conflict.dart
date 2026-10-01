import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure attendance-state comparison used by the repository's optimistic
/// concurrency logic.
///
/// This deliberately ignores timestamps. Firestore server timestamps can have
/// greater precision than the local SQLite/Drift representation, so timestamps
/// are not a reliable equality check for an attendance edit.
class AttendanceConflictChecker {
  const AttendanceConflictChecker._();

  static bool cloudMatchesLocal({
    required Map<String, dynamic> cloudData,
    required String localSubjectId,
    required int localSemester,
    required String localSection,
    required String localDate,
    required List<String> localPresentStudentIds,
  }) {
    final cloudSubjectId = _readString(
      cloudData['subjectId'],
    );

    final cloudSemester = _readInt(
      cloudData['semester'],
    );

    final cloudSection = _readString(
      cloudData['section'],
    ).toUpperCase();

    final cloudDate = _readString(
      cloudData['date'],
    );

    if (cloudSubjectId != localSubjectId.trim()) {
      return false;
    }

    if (cloudSemester != localSemester) {
      return false;
    }

    if (cloudSection != localSection.trim().toUpperCase()) {
      return false;
    }

    if (cloudDate != localDate.trim()) {
      return false;
    }

    final cloudPresentStudentIds = decodePresentStudentIds(
      cloudData['presentStudentIds'],
    );

    final localIds = _normalizeStudentIds(
      localPresentStudentIds,
    );

    if (cloudPresentStudentIds.length != localIds.length) {
      return false;
    }

    for (final studentId in localIds) {
      if (!cloudPresentStudentIds.contains(studentId)) {
        return false;
      }
    }

    return true;
  }

  static List<String> decodePresentStudentIds(
      dynamic value,
      ) {
    if (value is List) {
      return _normalizeStudentIds(
        value.whereType<String>().toList(),
      );
    }

    return <String>[];
  }

  static List<String> _normalizeStudentIds(
      Iterable<String> values,
      ) {
    final ids = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    ids.sort();

    return ids;
  }

  static String _readString(
      dynamic value,
      ) {
    return value is String ? value.trim() : '';
  }

  static int _readInt(
      dynamic value,
      ) {
    return value is int ? value : 0;
  }

  /// Kept here as a small compatibility helper for callers that may receive a
  /// Firestore timestamp. It is intentionally not used for conflict equality.
  static DateTime? readTimestamp(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}