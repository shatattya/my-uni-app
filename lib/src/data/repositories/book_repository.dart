import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(dbProvider);
  return BookRepository(db);
});

class BookRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  BookRepository(this._db);

  /// Watches the local SQLite database for books filtered by semester.
  /// Returns a stream to automatically update the UI without network latency.
  Stream<List<Book>> watchBooksForSemester(int semester) {
    return (_db.select(_db.books)..where((b) => b.semester.equals(semester))).watch();
  }

  /// Fetches the stringified Master JSON catalog from Firestore and writes it to SQLite.
  /// Matches the highly-optimized single-document read pattern used for routines.
  Future<void> syncBooks() async {
    try {
      final doc = await _firestore.collection('metadata').doc('books_catalog').get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !data.containsKey('data')) return;

      final rawJson = data['data'] as String;
      final List<dynamic> decoded = jsonDecode(rawJson);

      await _db.batch((batch) {
        for (var item in decoded) {
          batch.insert(
            _db.books,
            BooksCompanion.insert(
              id: item['id'] as String,
              title: item['title'] as String,
              author: item['author'] as String,
              coverUrl: item['coverUrl'] as String,
              downloadUrl: item['downloadUrl'] as String,
              semester: item['semester'] as int,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } catch (e) {
      print("DEBUG: Error syncing books catalog: $e");
      rethrow;
    }
  }

  /// Submits a request to the developer triage panel.
  /// Uses a deterministic Document ID to enforce the 1-per-day cooldown at the Firestore Rule level.
  Future<void> submitBookRequest({
    required String name,
    required String author,
    required int semester,
    required String isbn,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    // Format: YYYY-MM-DD
    final today = DateTime.now();
    final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Deterministic ID prevents multiple requests on the same day even if local cache is cleared
    final docId = "${uid}_book_$dateString";

    await _firestore.collection('requests').doc(docId).set({
      'type': 'book',
      'requesterUid': uid,
      'bookName': name,
      'authorName': author,
      'semester': semester,
      'isbn': isbn,
      'status': 'pending', // States: pending, uploaded, rejected
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}