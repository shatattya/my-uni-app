import 'dart:convert';

/// A single exact announcement audience.
///
/// Example:
///   semester 7, section C
///
/// is one target and must not be separated from its section.
class AnnouncementTarget {
  final int semester;
  final String section;

  const AnnouncementTarget({
    required this.semester,
    required this.section,
  });

  String get normalizedSection => section.trim().toUpperCase();

  String get topic => 'sem_${semester}_sec_$normalizedSection';

  Map<String, dynamic> toMap() {
    return {
      'semester': semester,
      'section': normalizedSection,
    };
  }

  static AnnouncementTarget? fromMap(dynamic value) {
    if (value is! Map) {
      return null;
    }

    final semesterValue = value['semester'];
    final sectionValue = value['section'];

    final int? semester = switch (semesterValue) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(semesterValue?.toString() ?? ''),
    };

    final section = sectionValue?.toString().trim().toUpperCase();

    if (semester == null || semester < 1 || semester > 8) {
      return null;
    }

    if (section == null || !const {'A', 'B', 'C'}.contains(section)) {
      return null;
    }

    return AnnouncementTarget(
      semester: semester,
      section: section,
    );
  }

  static List<AnnouncementTarget> decodeList(String source) {
    if (source.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(source);

      if (decoded is! List) {
        return const [];
      }

      final result = <AnnouncementTarget>[];

      for (final item in decoded) {
        final target = fromMap(item);
        if (target != null && !result.contains(target)) {
          result.add(target);
        }
      }

      return result;
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(Iterable<AnnouncementTarget> targets) {
    final unique = <AnnouncementTarget>[];

    for (final target in targets) {
      if (!unique.contains(target)) {
        unique.add(target);
      }
    }

    return jsonEncode(
      unique.map((target) => target.toMap()).toList(),
    );
  }

  /// Converts the old parallel arrays:
  ///
  /// semesters = [7, 8]
  /// sections  = [C, A]
  ///
  /// into the legacy Cartesian interpretation used by the old application.
  ///
  /// This is intentionally used only for backwards compatibility with
  /// existing records. New records never use this representation.
  static List<AnnouncementTarget> fromLegacyLists(
      dynamic semesters,
      dynamic sections,
      ) {
    final semesterList = _normalizeList(semesters);
    final sectionList = _normalizeList(sections);

    final result = <AnnouncementTarget>[];

    for (final semesterValue in semesterList) {
      for (final sectionValue in sectionList) {
        final target = fromMap({
          'semester': semesterValue,
          'section': sectionValue,
        });

        if (target != null && !result.contains(target)) {
          result.add(target);
        }
      }
    }

    return result;
  }

  static List<dynamic> _normalizeList(dynamic value) {
    if (value is List) {
      return value;
    }

    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  @override
  bool operator ==(Object other) {
    return other is AnnouncementTarget &&
        other.semester == semester &&
        other.normalizedSection == normalizedSection;
  }

  @override
  int get hashCode => Object.hash(
    semester,
    normalizedSection,
  );

  @override
  String toString() {
    return 'AnnouncementTarget(semester: $semester, section: $normalizedSection)';
  }
}