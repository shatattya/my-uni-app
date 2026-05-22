import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoutineUploader {
  // Upgraded to accept a progress callback for real-time UI updates
  // ADDED: isExamRoutine flag to switch between regular and exam routines
  static Future<void> uploadRoutineJson(Function(String status, double progress) onProgress, {bool isExamRoutine = false}) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // --- PHASE 1: Parse Local File ---
      onProgress("Reading JSON file...", 0.2);
      final String filePath = isExamRoutine ? 'assets/data/exam_routine.json' : 'assets/data/routine.json';
      final String jsonString = await rootBundle.loadString(filePath);

      // --- PHASE 2: Safely Delete Old Routines (Only for regular routines) ---
      if (!isExamRoutine) {
        onProgress("Clearing old routines...", 0.4);
        final oldRoutines = await firestore.collection('routines').get();

        WriteBatch deleteBatch = firestore.batch();
        int deleteCount = 0;

        for (var doc in oldRoutines.docs) {
          // Prevent deleting the master or exam_routine documents during cleanup
          if (doc.id == 'master' || doc.id == 'exam_routine') continue;

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
      } else {
        onProgress("Validating Exam JSON...", 0.4);
      }

      // --- PHASE 3: Upload Master Document ---
      onProgress("Uploading to Firestore...", 0.8);

      if (isExamRoutine) {
        // MODIFICATION: Upload raw JSON string instead of parsed map to save read/write expense
        await firestore.collection("routines").doc("exam_routine").set({
          "data": jsonString,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } else {
        // Regular Routines use the legacy format
        await firestore.collection("routines").doc("master").set({
          "data": jsonString,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      onProgress("Finalizing upload...", 1.0);
      await Future.delayed(const Duration(milliseconds: 500)); // Smooth UI transition

    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }
}