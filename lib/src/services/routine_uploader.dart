import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoutineUploader {
  // Upgraded to accept a progress callback for real-time UI updates
  static Future<void> uploadRoutineJson(Function(String status, double progress) onProgress) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // --- PHASE 1: Parse Local File ---
      onProgress("Reading JSON file...", 0.2);
      final String jsonString = await rootBundle.loadString('assets/data/routine.json');

      // --- PHASE 2: Safely Delete Old Routines ---
      // We must clean up the old inefficient multi-document structure so it doesn't waste space
      onProgress("Clearing old routines...", 0.4);
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

      // --- PHASE 3: Upload Master Document ---
      // Uploading the entire routine as a single document reduces Firestore writes from ~500 to exactly 1.
      onProgress("Uploading master routine (1 write)...", 0.8);

      await firestore.collection("routines").doc("master").set({
        "data": jsonString,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      onProgress("Finalizing upload...", 1.0);
      await Future.delayed(const Duration(milliseconds: 500)); // Smooth UI transition

    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }
}