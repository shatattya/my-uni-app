import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(dbProvider);
  return NoteRepository(db);
});

class NoteRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NoteRepository(this._db);

  Stream<List<Note>> watchNotesForSemester(int semester) {
    return (_db.select(_db.notes)..where((n) => n.semester.equals(semester))).watch();
  }

  Future<void> syncNotes(int userSemester, String userSection) async {
    try {
      final doc = await _firestore.collection('metadata').doc('notes_catalog').get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !data.containsKey('data')) return;

      final rawJson = data['data'] as String;

      // MODIFICATION: Decode as a Map since the JSON structure is now grouped by semester keys
      final Map<String, dynamic> decoded = jsonDecode(rawJson);

      await _db.batch((batch) {
        decoded.forEach((semesterKey, noteList) {
          // Robust extraction: Pulls the integer from keys like "1", "semester 1", or "sem_1"
          final int semester = int.tryParse(semesterKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

          if (noteList is List) {
            for (var item in noteList) {
              batch.insert(
                _db.notes,
                NotesCompanion.insert(
                  id: item['id'] as String,
                  title: item['title'] as String? ?? 'Untitled',
                  subjectName: item['subjectName'] as String,
                  authorName: item['authorName'] as String? ?? 'Unknown',
                  fileUrl: item['fileUrl'] as String,
                  semester: semester, // Extracted dynamically from the parent JSON key
                  section: item['section'] as String? ?? 'All',
                  createdAt: DateTime.now(),
                  isSynced: const Value(true), // Synced successfully from remote
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
        });
      });
    } catch (e) {
      print("DEBUG: Error syncing notes catalog: $e");
      rethrow;
    }
  }

  Future<void> submitNoteRequest({
    required String subjectName,
    required int semester,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final today = DateTime.now();
    final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final docId = "${uid}_note_$dateString";

    await _firestore.collection('requests').doc(docId).set({
      'type': 'note',
      'requesterUid': uid,
      'subjectName': subjectName,
      'semester': semester,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}