import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academic_calendar.dart';

final academicCalendarRepositoryProvider =
Provider<AcademicCalendarRepository>((ref) {
  return AcademicCalendarRepository(
    FirebaseFirestore.instance,
  );
});

class AcademicCalendarRepositoryException implements Exception {
  final String message;

  const AcademicCalendarRepositoryException(this.message);

  @override
  String toString() => message;
}

class AcademicCalendarRepository {
  static const String _collectionName = 'routines';
  static const String _documentId = 'academicCalendar';
  static const String _dataField = 'data';
  static const String _cacheKey = 'academic_calendar_json_v1';
  static const Duration _requestTimeout = Duration(seconds: 10);

  final FirebaseFirestore _firestore;

  Future<AcademicCalendar>? _syncInFlight;

  AcademicCalendarRepository(this._firestore);

  /// Returns the locally cached calendar without touching Firestore.
  ///
  /// The first-ever load bootstraps the cache from Firestore. After that,
  /// opening the calendar screen is a local read only. The profile Sync action
  /// is responsible for explicitly refreshing the remote copy.
  Future<AcademicCalendar> loadCalendar() async {
    try {
      return await _loadCachedCalendar();
    } on AcademicCalendarRepositoryException {
      return syncCalendar();
    }
  }

  /// Explicitly fetches the latest calendar from Firestore and updates the
  /// local cache only after the remote payload has been parsed successfully.
  ///
  /// Concurrent callers share the same in-flight request so one sync action
  /// cannot accidentally create duplicate Firestore reads.
  Future<AcademicCalendar> syncCalendar() {
    final existing = _syncInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<AcademicCalendar> operation;
    operation = _fetchAndCacheCalendar().whenComplete(() {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    });

    _syncInFlight = operation;
    return operation;
  }

  Future<AcademicCalendar> _fetchAndCacheCalendar() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(_documentId)
          .get()
          .timeout(_requestTimeout);

      if (!snapshot.exists) {
        throw const AcademicCalendarRepositoryException(
          'The academic calendar is not available.',
        );
      }

      final documentData = snapshot.data();
      if (documentData == null) {
        throw const AcademicCalendarRepositoryException(
          'The academic calendar document is empty.',
        );
      }

      final jsonSource = _normalizeJsonSource(
        documentData[_dataField],
      );

      final calendar = AcademicCalendar.fromJsonString(jsonSource);

      await _saveCache(jsonSource);
      return calendar;
    } on AcademicCalendarRepositoryException {
      rethrow;
    } on FormatException catch (error) {
      throw AcademicCalendarRepositoryException(
        'The academic calendar contains invalid data: $error',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Academic calendar Firebase error: ${error.code}',
      );
      throw AcademicCalendarRepositoryException(
        _firebaseErrorMessage(error),
      );
    } on Exception catch (error, stackTrace) {
      debugPrint('Academic calendar load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const AcademicCalendarRepositoryException(
        'Could not load the academic calendar. Please check your connection and try again.',
      );
    }
  }

  Future<AcademicCalendar> _loadCachedCalendar() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedJson = preferences.getString(_cacheKey);

    if (cachedJson == null || cachedJson.trim().isEmpty) {
      throw const AcademicCalendarRepositoryException(
        'No cached academic calendar is available.',
      );
    }

    try {
      return AcademicCalendar.fromJsonString(cachedJson);
    } on FormatException {
      try {
        await preferences.remove(_cacheKey);
      } catch (_) {
        // A corrupt cache should not prevent the remote bootstrap attempt.
      }

      throw const AcademicCalendarRepositoryException(
        'The saved academic calendar is invalid.',
      );
    }
  }

  String _normalizeJsonSource(dynamic rawData) {
    if (rawData is String) {
      final value = rawData.trim();
      if (value.isEmpty) {
        throw const AcademicCalendarRepositoryException(
          'The academic calendar data field is empty.',
        );
      }
      return value;
    }

    if (rawData is Map) {
      try {
        return jsonEncode(
          Map<String, dynamic>.from(rawData),
        );
      } catch (error) {
        throw AcademicCalendarRepositoryException(
          'The academic calendar data field is invalid: $error',
        );
      }
    }

    throw const AcademicCalendarRepositoryException(
      'The academic calendar data field is missing or invalid.',
    );
  }

  Future<void> _saveCache(String jsonSource) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_cacheKey, jsonSource);
    } catch (error, stackTrace) {
      // Cache failure must not turn a successful Firestore sync into a failed
      // sync. The current calendar can still be displayed in this session.
      debugPrint(
        'Academic calendar cache write failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to view the academic calendar.';
      case 'unavailable':
        return 'The academic calendar service is temporarily unavailable.';
      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';
      case 'not-found':
        return 'The academic calendar could not be found.';
      case 'failed-precondition':
        return 'The academic calendar is temporarily unavailable.';
      case 'resource-exhausted':
        return 'The academic calendar service is temporarily busy.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      default:
        return 'Could not load the academic calendar.';
    }
  }
}