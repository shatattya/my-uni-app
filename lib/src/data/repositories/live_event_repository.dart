import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final liveEventRepositoryProvider = Provider<LiveEventRepository>((ref) {
  return LiveEventRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class LiveEventRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  bool _isSyncing = false;

  static const String _prefEventId = 'liveEventId';
  static const String _prefEventTitle = 'liveEventTitle';
  static const String _prefEventType = 'liveEventType';
  static const String _prefHomeTabButtonLabel = 'liveEventButtonLabel';

  LiveEventRepository(this._db, this._firestore);

  /// Get the dynamic button label for the Home Tab
  Future<String> getHomeTabButtonLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefHomeTabButtonLabel) ?? "Live Events";
  }

  /// Get the current master Event Type (e.g., 'sports_versus' or 'event_session')
  Future<String> getEventType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefEventType) ?? "event_session";
  }

  /// Get the event title for the header
  Future<String> getEventTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefEventTitle) ?? "Event Schedule";
  }

  /// OFFLINE FIRST: Watch all events, optionally filtering by a search query
  Stream<List<LiveEvent>> watchEvents({String query = ''}) {
    if (query.trim().isEmpty) {
      return (_db.select(_db.liveEvents)
        ..orderBy([(t) => OrderingTerm(expression: t.utcTime)]))
          .watch();
    } else {
      final searchPattern = '%${query.trim().toLowerCase()}%';
      return (_db.select(_db.liveEvents)
        ..where((e) =>
        e.titlePrimary.lower().like(searchPattern) |
        e.titleSecondary.lower().like(searchPattern) |
        e.groupLabel.lower().like(searchPattern))
        ..orderBy([(t) => OrderingTerm(expression: t.utcTime)]))
          .watch();
    }
  }

  /// SYNC: Fetch the master dynamic event data from Firestore and safely replace SQLite
  Future<void> syncLiveEvents() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final docSnapshot = await _firestore.collection("metadata").doc("live_event_routine").get();

      if (!docSnapshot.exists) {
        debugPrint("DEBUG: Live event document not found in Firebase.");
        return;
      }

      final docData = docSnapshot.data();
      if (docData == null || !docData.containsKey("data")) return;

      final String rawJsonString = docData["data"];

      // Safe parsing for the master JSON structure
      Map<String, dynamic> data = {};
      try {
        final decoded = json.decode(rawJsonString);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        } else {
          return; // Abort sync if the structural wrapper isn't a Map
        }
      } catch (e) {
        debugPrint("DEBUG: Malformed JSON string in live event routine: $e");
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 1. Update Dynamic Metadata
      final String? eventId = data['eventId'];
      if (eventId != null) await prefs.setString(_prefEventId, eventId);

      final String eventTitle = (data["eventTitle"]?.toString() ?? "Event Schedule").trim();
      await prefs.setString(_prefEventTitle, eventTitle);

      final String eventType = (data["eventType"]?.toString() ?? "event_session").trim();
      await prefs.setString(_prefEventType, eventType);

      final String buttonLabel = (data["homeTabButtonLabel"]?.toString() ?? "Live Events").trim();
      await prefs.setString(_prefHomeTabButtonLabel, buttonLabel);

      if (!data.containsKey("schedule")) return;
      if (data["schedule"] is! List) return;

      final List<dynamic> scheduleData = data["schedule"];
      List<LiveEventsCompanion> companions = [];

      for (var item in scheduleData) {
        if (item is! Map) continue; // Skip malformed event objects

        final String uniqueId = item["id"]?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();

        companions.add(
            LiveEventsCompanion(
              id: Value(uniqueId),
              groupLabel: Value(item["groupLabel"]?.toString() ?? ""),
              heading: Value(item["heading"]?.toString() ?? ""),
              titlePrimary: Value(item["titlePrimary"]?.toString() ?? "Unknown"),
              titleSecondary: Value(item["titleSecondary"]?.toString() ?? ""),
              subtitle: Value(item["subtitle"]?.toString() ?? ""),
              utcTime: Value(item["utcTime"]?.toString() ?? DateTime.now().toUtc().toIso8601String()),
            )
        );
      }

      await _db.transaction(() async {
        await _db.delete(_db.liveEvents).go();
        await _db.batch((batch) {
          batch.insertAll(_db.liveEvents, companions, mode: InsertMode.insertOrReplace);
        });
      });

      debugPrint("DEBUG: Live Events synced. Total processed: ${companions.length}");

    } catch (e) {
      debugPrint("DEBUG: Live Event Sync Error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}