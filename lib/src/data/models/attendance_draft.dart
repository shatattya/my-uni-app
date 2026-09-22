class AttendanceException implements Exception {
  final String message;

  const AttendanceException(this.message);

  @override
  String toString() => message;
}

class AttendanceAuthorizationException extends AttendanceException {
  const AttendanceAuthorizationException(super.message);
}

class AttendanceConflictException extends AttendanceException {
  const AttendanceConflictException(super.message);
}

class AttendanceValidationException extends AttendanceException {
  const AttendanceValidationException(super.message);
}

enum AttendanceSaveResult {
  cloudSynced,
  queuedForSync,
}

/// Validated, canonical representation of attendance input.
class AttendanceDraft {
  static const int maxSubjectLength = 200;
  static const int maxPresentStudentIds = 500;

  final String subjectName;
  final int semester;
  final String section;
  final String date;
  final List<String> presentStudentIds;

  const AttendanceDraft._({
    required this.subjectName,
    required this.semester,
    required this.section,
    required this.date,
    required this.presentStudentIds,
  });

  factory AttendanceDraft.create({
    required String subjectName,
    required int semester,
    required String section,
    required String date,
    required List<String> presentStudentIds,
  }) {
    final normalizedSubject = subjectName.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (normalizedSubject.isEmpty) {
      throw const AttendanceValidationException(
        'Subject name cannot be empty.',
      );
    }

    if (normalizedSubject.length > maxSubjectLength) {
      throw const AttendanceValidationException(
        'Subject name is too long.',
      );
    }

    if (semester < 1 || semester > 8) {
      throw const AttendanceValidationException(
        'Semester must be between 1 and 8.',
      );
    }

    final normalizedSection = section.trim().toUpperCase();

    if (!{'A', 'B', 'C'}.contains(normalizedSection)) {
      throw const AttendanceValidationException(
        'Section must be A, B, or C.',
      );
    }

    final normalizedDate = date.trim();

    if (!_isValidIsoDate(normalizedDate)) {
      throw const AttendanceValidationException(
        'Attendance date must be in YYYY-MM-DD format.',
      );
    }

    final normalizedStudentIds = <String>{};

    for (final rawId in presentStudentIds) {
      final id = rawId.trim();

      if (id.isEmpty) {
        throw const AttendanceValidationException(
          'Attendance contains an empty student ID.',
        );
      }

      normalizedStudentIds.add(id);
    }

    if (normalizedStudentIds.length > maxPresentStudentIds) {
      throw const AttendanceValidationException(
        'Too many student IDs were submitted.',
      );
    }

    final sortedStudentIds = normalizedStudentIds.toList()..sort();

    return AttendanceDraft._(
      subjectName: normalizedSubject,
      semester: semester,
      section: normalizedSection,
      date: normalizedDate,
      presentStudentIds: List.unmodifiable(sortedStudentIds),
    );
  }

  static bool _isValidIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);

    if (match == null) {
      return false;
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);

    if (year == null || month == null || day == null) {
      return false;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }

    final parsed = DateTime.utc(year, month, day);

    return parsed.year == year &&
        parsed.month == month &&
        parsed.day == day;
  }
}