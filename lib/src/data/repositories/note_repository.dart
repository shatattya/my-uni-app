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

  /// Watches the local SQLite database for notes filtered by semester.
  /// Returns a stream to automatically update the UI without network latency.
  Stream<List<Note>> watchNotesForSemester(int semester) {
    return (_db.select(_db.notes)..where((n) => n.semester.equals(semester))).watch();
  }

  /// Fetches the stringified Master JSON catalog for Notes from Firestore and writes it to SQLite.
  /// Matches the highly-optimized single-document read pattern used for routines and books.
  Future<void> syncNotes(int userSemester, String userSection) async {
    try {
      final doc = await _firestore.collection('metadata').doc('notes_catalog').get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !data.containsKey('data')) return;

      final rawJson = data['data'] as String;
      final List<dynamic> decoded = jsonDecode(rawJson);

      await _db.batch((batch) {
        for (var item in decoded) {
          batch.insert(
            _db.notes,
            NotesCompanion.insert(
              id: item['id'] as String,
              title: item['title'] as String? ?? 'Untitled',
              subjectName: item['subjectName'] as String,
              authorName: item['authorName'] as String? ?? 'Unknown',
              fileUrl: item['fileUrl'] as String,
              semester: item['semester'] as int,
              section: item['section'] as String? ?? 'All',
              createdAt: DateTime.now(),
              isSynced: const Value(true), // Synced successfully from remote
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } catch (e) {
      print("DEBUG: Error syncing notes catalog: $e");
      rethrow;
    }
  }

  /// Submits a request to the developer triage panel for a Note.
  /// Uses a deterministic Document ID to enforce the 1-per-day cooldown at the Firestore Rule level.
  Future<void> submitNoteRequest({
    required String subjectName,
    required int semester,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    // Format: YYYY-MM-DD
    final today = DateTime.now();
    final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Deterministic ID prevents multiple note requests on the same day even if local cache is cleared
    final docId = "${uid}_note_$dateString";

    await _firestore.collection('requests').doc(docId).set({
      'type': 'note',
      'requesterUid': uid,
      'subjectName': subjectName,
      'semester': semester,
      'status': 'pending', // States: pending, uploaded, rejected
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}