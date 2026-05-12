import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoutineUploader {
  static const Map<String, Map<String, String>> _timeSlots = {
    "class1": {"start": "09:30", "end": "10:20"},
    "class2": {"start": "10:25", "end": "11:15"},
    "class3": {"start": "11:20", "end": "12:10"},
    "class4": {"start": "12:15", "end": "13:05"},
    "class5": {"start": "13:10", "end": "14:00"},
    "class6": {"start": "14:05", "end": "14:55"},
  };

  static const Map<String, int> _dayMap = {
    "Monday": 1, "Tuesday": 2, "Wednesday": 3,
    "Thursday": 4, "Friday": 5, "Saturday": 6, "Sunday": 7,
  };

  // Upgraded to accept a progress callback for real-time UI updates
  static Future<void> uploadRoutineJson(Function(String status, double progress) onProgress) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // --- PHASE 1: Parse Local File ---
      onProgress("Reading JSON file...", 0.1);
      final String jsonString = await rootBundle.loadString('assets/data/routine.json');
      final List<dynamic> teachersData = jsonDecode(jsonString);

      // --- PHASE 2: Safely Delete Old Routines (Chunked) ---
      onProgress("Clearing old routines...", 0.3);
      final oldRoutines = await firestore.collection('routines').get();

      WriteBatch deleteBatch = firestore.batch();
      int deleteCount = 0;

      for (var doc in oldRoutines.docs) {
        deleteBatch.delete(doc.reference);
        deleteCount++;

        // Firestore limit is 500. We commit at 450 to be safe.
        if (deleteCount == 450) {
          await deleteBatch.commit();
          deleteBatch = firestore.batch();
          deleteCount = 0;
        }
      }
      if (deleteCount > 0) await deleteBatch.commit();

      // --- PHASE 3: Prepare New Data ---
      onProgress("Parsing new classes...", 0.5);
      WriteBatch uploadBatch = firestore.batch();
      int uploadCount = 0;
      int totalClasses = 0;

      for (var teacher in teachersData) {
        final String teacherName = teacher["teacherName"];
        final Map<String, dynamic> days = teacher["days"];

        for (var dayEntry in days.entries) {
          final int dayOfWeek = _dayMap[dayEntry.key] ?? 1;
          final Map<String, dynamic> classes = dayEntry.value;

          for (var classEntry in classes.entries) {
            final String slotKey = classEntry.key;
            final Map<String, dynamic> details = classEntry.value;

            // Handle corrupted/missing time slots gracefully
            final startTime = _timeSlots[slotKey]?["start"] ?? "00:00";
            final endTime = _timeSlots[slotKey]?["end"] ?? "00:00";

            DocumentReference docRef = firestore.collection("routines").doc();

            uploadBatch.set(docRef, {
              "subjectName": details["sub"],
              "teacherName": teacherName,
              "roomNumber": details["room"],
              "dayOfWeek": dayOfWeek,
              "startTime": startTime,
              "endTime": endTime,
              "semester": details["sem"],
              "section": details["sec"],
            });

            uploadCount++;
            totalClasses++;

            // Commit in safe chunks of 450
            if (uploadCount == 450) {
              await uploadBatch.commit();
              uploadBatch = firestore.batch();
              uploadCount = 0;
              // Small UI update so it doesn't freeze
              onProgress("Uploaded $totalClasses classes...", 0.7);
            }
          }
        }
      }
      // Commit remaining items
      if (uploadCount > 0) await uploadBatch.commit();

      onProgress("Finalizing upload ($totalClasses classes)...", 0.9);
      await Future.delayed(const Duration(milliseconds: 500)); // Smooth UI transition

    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }
}