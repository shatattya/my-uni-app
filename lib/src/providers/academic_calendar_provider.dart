import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/academic_calendar.dart';
import '../data/repositories/academic_calendar_repository.dart';

/// Loads the calendar from local cache first.
///
/// Firestore is only contacted when this device has no usable cached calendar.
/// Explicit remote refreshes are performed by the application's global Sync
/// action, which keeps calendar reads predictable on the Firebase free tier.
final academicCalendarProvider =
FutureProvider.autoDispose<AcademicCalendar>((ref) {
  return ref
      .watch(academicCalendarRepositoryProvider)
      .loadCalendar();
});