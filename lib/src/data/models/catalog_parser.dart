import 'dart:convert';

class CatalogFormatException implements Exception {
  final String message;

  const CatalogFormatException(this.message);

  @override
  String toString() => message;
}

class BookCatalogItem {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String downloadUrl;
  final int semester;

  const BookCatalogItem({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.downloadUrl,
    required this.semester,
  });
}

class NoteCatalogItem {
  final String id;
  final String title;
  final String subjectName;
  final String authorName;
  final String fileUrl;
  final int semester;
  final String section;
  final DateTime? createdAt;

  const NoteCatalogItem({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.authorName,
    required this.fileUrl,
    required this.semester,
    required this.section,
    required this.createdAt,
  });
}

class CatalogParser {
  const CatalogParser._();

  static List<BookCatalogItem> parseBooks(String rawJson) {
    final root = _decodeRoot(rawJson, 'books');

    final results = <BookCatalogItem>[];
    final ids = <String>{};

    var sawItems = false;
    var validItems = 0;

    for (final entry in root.entries) {
      final semester = _parseSemester(
        entry.key,
        'books',
      );

      final value = entry.value;

      if (value is! List) {
        throw CatalogFormatException(
          'Books catalog semester "${entry.key}" must contain a list.',
        );
      }

      for (final rawItem in value) {
        sawItems = true;

        if (rawItem is! Map) {
          continue;
        }

        final id = _requiredString(
          rawItem['id'],
        );

        final title = _requiredString(
          rawItem['title'],
        );

        final author = _optionalString(
          rawItem['author'],
          fallback: 'Unknown Author',
        );

        final coverUrl = _optionalString(
          rawItem['coverUrl'],
          fallback: '',
        );

        final downloadUrl = _optionalString(
          rawItem['downloadUrl'],
          fallback: '',
        );

        if (id == null ||
            id.isEmpty ||
            title == null ||
            title.isEmpty) {
          continue;
        }

        if (!ids.add(id)) {
          throw CatalogFormatException(
            'Books catalog contains duplicate ID "$id".',
          );
        }

        results.add(
          BookCatalogItem(
            id: id,
            title: title,
            author: author,
            coverUrl: coverUrl,
            downloadUrl: downloadUrl,
            semester: semester,
          ),
        );

        validItems++;
      }
    }

    if (sawItems && validItems == 0) {
      throw const CatalogFormatException(
        'Books catalog contains no valid book entries.',
      );
    }

    return List.unmodifiable(results);
  }

  static List<NoteCatalogItem> parseNotes(String rawJson) {
    final root = _decodeRoot(rawJson, 'notes');

    final results = <NoteCatalogItem>[];
    final ids = <String>{};

    var sawItems = false;
    var validItems = 0;

    for (final entry in root.entries) {
      final semester = _parseSemester(
        entry.key,
        'notes',
      );

      final value = entry.value;

      if (value is! List) {
        throw CatalogFormatException(
          'Notes catalog semester "${entry.key}" must contain a list.',
        );
      }

      for (final rawItem in value) {
        sawItems = true;

        if (rawItem is! Map) {
          continue;
        }

        final id = _requiredString(
          rawItem['id'],
        );

        final title = _requiredString(
          rawItem['title'],
        );

        final subjectName = _requiredString(
          rawItem['subjectName'],
        );

        final fileUrl = _requiredString(
          rawItem['fileUrl'],
        );

        final authorName = _optionalString(
          rawItem['authorName'],
          fallback: 'Unknown',
        );

        final section = _normalizeSection(
          rawItem['section'],
        );

        final createdAt = _parseOptionalDateTime(
          rawItem['createdAt'],
        );

        if (id == null ||
            id.isEmpty ||
            title == null ||
            title.isEmpty ||
            subjectName == null ||
            subjectName.isEmpty ||
            fileUrl == null ||
            fileUrl.isEmpty) {
          continue;
        }

        if (!ids.add(id)) {
          throw CatalogFormatException(
            'Notes catalog contains duplicate ID "$id".',
          );
        }

        results.add(
          NoteCatalogItem(
            id: id,
            title: title,
            subjectName: subjectName,
            authorName: authorName,
            fileUrl: fileUrl,
            semester: semester,
            section: section,
            createdAt: createdAt,
          ),
        );

        validItems++;
      }
    }

    if (sawItems && validItems == 0) {
      throw const CatalogFormatException(
        'Notes catalog contains no valid note entries.',
      );
    }

    return List.unmodifiable(results);
  }

  static Map<String, dynamic> _decodeRoot(
      String rawJson,
      String catalogName,
      ) {
    dynamic decoded;

    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw CatalogFormatException(
        'Malformed $catalogName catalog JSON: ${error.message}',
      );
    }

    if (decoded is! Map) {
      throw CatalogFormatException(
        '$catalogName catalog root must be a JSON object.',
      );
    }

    final root = <String, dynamic>{};

    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw CatalogFormatException(
          '$catalogName catalog contains a non-string semester key.',
        );
      }

      root[entry.key as String] = entry.value;
    }

    return root;
  }

  static int _parseSemester(
      String rawKey,
      String catalogName,
      ) {
    final digits = rawKey.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    final semester = int.tryParse(digits);

    if (semester == null ||
        semester < 1 ||
        semester > 8) {
      throw CatalogFormatException(
        'Invalid semester key "$rawKey" in $catalogName catalog.',
      );
    }

    return semester;
  }

  static String? _requiredString(
      dynamic value,
      ) {
    if (value is! String) {
      return null;
    }

    final result = value.trim();

    return result.isEmpty ? null : result;
  }

  static String _optionalString(
      dynamic value, {
        required String fallback,
      }) {
    if (value is! String) {
      return fallback;
    }

    final result = value.trim();

    return result.isEmpty ? fallback : result;
  }

  static String _normalizeSection(
      dynamic value,
      ) {
    if (value is! String) {
      return 'All';
    }

    final section = value.trim();

    if (section.isEmpty) {
      return 'All';
    }

    final normalized = section.toUpperCase();

    if (normalized == 'A' ||
        normalized == 'B' ||
        normalized == 'C') {
      return normalized;
    }

    return section;
  }

  static DateTime? _parseOptionalDateTime(
      dynamic value,
      ) {
    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value.trim(),
      );
    }

    return null;
  }
}