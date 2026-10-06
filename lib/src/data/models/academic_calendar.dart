import 'dart:convert';

enum AcademicCalendarEventType {
  academic,
  holiday,
  observance,
  other;

  static AcademicCalendarEventType fromJson(
      dynamic value,
      ) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'academic':
        return AcademicCalendarEventType.academic;

      case 'holiday':
        return AcademicCalendarEventType.holiday;

      case 'observance':
      case 'occasion':
        return AcademicCalendarEventType.observance;

      default:
        return AcademicCalendarEventType.other;
    }
  }

  String get label {
    switch (this) {
      case AcademicCalendarEventType.academic:
        return 'Academic';

      case AcademicCalendarEventType.holiday:
        return 'Holiday';

      case AcademicCalendarEventType.observance:
        return 'University Observance';

      case AcademicCalendarEventType.other:
        return 'Event';
    }
  }
}

class AcademicCalendarEvent {
  final String id;
  final String title;
  final AcademicCalendarEventType type;
  final DateTime startDate;
  final DateTime endDate;
  final String? note;
  final String termId;

  const AcademicCalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.termId,
    this.note,
  });

  bool get isSingleDay {
    return startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;
  }

  bool occursOn(DateTime date) {
    final normalizedDate = _dateOnly(date);

    return !normalizedDate.isBefore(startDate) &&
        !normalizedDate.isAfter(endDate);
  }

  bool isUpcomingFrom(DateTime date) {
    final normalizedDate = _dateOnly(date);

    return !endDate.isBefore(normalizedDate);
  }

  factory AcademicCalendarEvent.fromJson(
      Map<String, dynamic> json, {
        required String termId,
      }) {
    final title = _requiredString(
      json['title'],
      fieldName: 'event.title',
    );

    final startDate = _parseDate(
      json['startDate'],
      fieldName: 'event.startDate',
    );

    final rawEndDate = json['endDate'];

    final endDate = rawEndDate == null ||
        rawEndDate.toString().trim().isEmpty
        ? startDate
        : _parseDate(
      rawEndDate,
      fieldName: 'event.endDate',
    );

    if (endDate.isBefore(startDate)) {
      throw FormatException(
        'Event "$title" has an end date before its start date.',
      );
    }

    final rawId = json['id']?.toString().trim();

    final id = rawId == null || rawId.isEmpty
        ? _buildFallbackId(
      title,
      startDate,
    )
        : rawId;

    final rawNote = json['note']?.toString().trim();

    return AcademicCalendarEvent(
      id: id,
      title: title,
      type: AcademicCalendarEventType.fromJson(
        json['category'],
      ),
      startDate: startDate,
      endDate: endDate,
      termId: termId,
      note: rawNote == null || rawNote.isEmpty
          ? null
          : rawNote,
    );
  }
}

class AcademicCalendarTerm {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<AcademicCalendarEvent> events;

  AcademicCalendarTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required List<AcademicCalendarEvent> events,
  }) : events = List.unmodifiable(
    _sortEvents(events),
  );

  factory AcademicCalendarTerm.fromJson(
      Map<String, dynamic> json,
      ) {
    final id = _requiredString(
      json['id'],
      fieldName: 'term.id',
    );

    final name = _requiredString(
      json['name'],
      fieldName: 'term.name',
    );

    final startDate = _parseDate(
      json['startDate'],
      fieldName: 'term.startDate',
    );

    final endDate = _parseDate(
      json['endDate'],
      fieldName: 'term.endDate',
    );

    if (endDate.isBefore(startDate)) {
      throw FormatException(
        'Term "$name" has an end date before its start date.',
      );
    }

    final rawEvents = json['events'];

    if (rawEvents is! List) {
      throw FormatException(
        'Term "$name" must contain an events array.',
      );
    }

    final events = <AcademicCalendarEvent>[];

    for (final rawEvent in rawEvents) {
      if (rawEvent is! Map) {
        throw FormatException(
          'Term "$name" contains an invalid event entry.',
        );
      }

      final event = AcademicCalendarEvent.fromJson(
        Map<String, dynamic>.from(rawEvent),
        termId: id,
      );

      if (event.startDate.isBefore(startDate) ||
          event.endDate.isAfter(endDate)) {
        throw FormatException(
          'Event "${event.title}" falls outside term "$name".',
        );
      }

      events.add(event);
    }

    return AcademicCalendarTerm(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      events: events,
    );
  }
}

class AcademicCalendar {
  final int schemaVersion;
  final String calendarId;
  final int academicYear;
  final String university;
  final List<AcademicCalendarTerm> terms;

  AcademicCalendar({
    required this.schemaVersion,
    required this.calendarId,
    required this.academicYear,
    required this.university,
    required List<AcademicCalendarTerm> terms,
  }) : terms = List.unmodifiable(
    _sortTerms(terms),
  ) {
    _validateUniqueIds(this.terms);
  }

  factory AcademicCalendar.fromJsonString(
      String source,
      ) {
    final value = source.trim();

    if (value.isEmpty) {
      throw const FormatException(
        'Academic calendar JSON is empty.',
      );
    }

    late final dynamic decoded;

    try {
      decoded = jsonDecode(value);
    } on FormatException catch (error) {
      throw FormatException(
        'Academic calendar JSON is malformed: $error',
      );
    }

    if (decoded is! Map) {
      throw const FormatException(
        'Academic calendar JSON must contain an object.',
      );
    }

    return AcademicCalendar.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  factory AcademicCalendar.fromJson(
      Map<String, dynamic> json,
      ) {
    final schemaVersion = _parseInt(
      json['schemaVersion'],
      fieldName: 'schemaVersion',
      fallback: 1,
    );

    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported academic calendar schema version: '
            '$schemaVersion',
      );
    }

    final calendarId = _requiredString(
      json['calendarId'],
      fieldName: 'calendarId',
    );

    final academicYear = _parseInt(
      json['academicYear'],
      fieldName: 'academicYear',
    );

    final university = _requiredString(
      json['university'],
      fieldName: 'university',
    );

    final rawTerms = json['terms'];

    if (rawTerms is! List || rawTerms.isEmpty) {
      throw const FormatException(
        'Academic calendar must contain at least one term.',
      );
    }

    final terms = <AcademicCalendarTerm>[];

    for (final rawTerm in rawTerms) {
      if (rawTerm is! Map) {
        throw const FormatException(
          'Academic calendar contains an invalid term entry.',
        );
      }

      terms.add(
        AcademicCalendarTerm.fromJson(
          Map<String, dynamic>.from(rawTerm),
        ),
      );
    }

    return AcademicCalendar(
      schemaVersion: schemaVersion,
      calendarId: calendarId,
      academicYear: academicYear,
      university: university,
      terms: terms,
    );
  }

  List<AcademicCalendarEvent> get events {
    final allEvents = <AcademicCalendarEvent>[];

    for (final term in terms) {
      allEvents.addAll(term.events);
    }

    allEvents.sort(_compareEvents);

    return List.unmodifiable(allEvents);
  }
}

String _requiredString(
    dynamic value, {
      required String fieldName,
    }) {
  final result = value?.toString().trim();

  if (result == null || result.isEmpty) {
    throw FormatException(
      '$fieldName must be a non-empty string.',
    );
  }

  return result;
}

int _parseInt(
    dynamic value, {
      required String fieldName,
      int? fallback,
    }) {
  if (value == null) {
    if (fallback != null) {
      return fallback;
    }

    throw FormatException(
      '$fieldName is missing.',
    );
  }

  final parsed = int.tryParse(
    value.toString().trim(),
  );

  if (parsed == null) {
    throw FormatException(
      '$fieldName must be an integer.',
    );
  }

  return parsed;
}

DateTime _parseDate(
    dynamic value, {
      required String fieldName,
    }) {
  final raw = value?.toString().trim();

  if (raw == null || raw.isEmpty) {
    throw FormatException(
      '$fieldName is missing.',
    );
  }

  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(raw);

  if (match == null) {
    throw FormatException(
      '$fieldName must use YYYY-MM-DD format.',
    );
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  final date = DateTime(
    year,
    month,
    day,
  );

  if (date.year != year ||
      date.month != month ||
      date.day != day) {
    throw FormatException(
      '$fieldName contains an invalid calendar date.',
    );
  }

  return date;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  );
}

String _buildFallbackId(
    String title,
    DateTime date,
    ) {
  final slug = title
      .toLowerCase()
      .replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  )
      .replaceAll(
    RegExp(r'_+'),
    '_',
  )
      .replaceAll(
    RegExp(r'^_|_$'),
    '',
  );

  return '${slug}_${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

List<AcademicCalendarEvent> _sortEvents(
    List<AcademicCalendarEvent> events,
    ) {
  final result =
  List<AcademicCalendarEvent>.from(events);

  result.sort(_compareEvents);

  return result;
}

List<AcademicCalendarTerm> _sortTerms(
    List<AcademicCalendarTerm> terms,
    ) {
  final result =
  List<AcademicCalendarTerm>.from(terms);

  result.sort(
        (a, b) {
      final comparison =
      a.startDate.compareTo(
        b.startDate,
      );

      if (comparison != 0) {
        return comparison;
      }

      return a.name.compareTo(b.name);
    },
  );

  return result;
}

int _compareEvents(
    AcademicCalendarEvent a,
    AcademicCalendarEvent b,
    ) {
  final startComparison =
  a.startDate.compareTo(b.startDate);

  if (startComparison != 0) {
    return startComparison;
  }

  final endComparison =
  a.endDate.compareTo(b.endDate);

  if (endComparison != 0) {
    return endComparison;
  }

  return a.title.compareTo(b.title);
}

void _validateUniqueIds(
    List<AcademicCalendarTerm> terms,
    ) {
  final termIds = <String>{};
  final eventIds = <String>{};

  for (final term in terms) {
    if (!termIds.add(term.id)) {
      throw FormatException(
        'Duplicate academic calendar term ID: ${term.id}',
      );
    }

    for (final event in term.events) {
      if (!eventIds.add(event.id)) {
        throw FormatException(
          'Duplicate academic calendar event ID: ${event.id}',
        );
      }
    }
  }
}