import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart'; // ADDED: For debugPrint
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

  Stream<List<Book>> watchBooksForSemester(int semester) {
    return (_db.select(_db.books)..where((b) => b.semester.equals(semester))).watch();
  }

  Future<void> syncBooks() async {
    try {
      final doc = await _firestore.collection('metadata').doc('books_catalog').get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null || !data.containsKey('data')) return;

      final rawJson = data['data'] as String;

      // BUG FIX: Safe JSON parsing to prevent FormatException from halting the global sync
      Map<String, dynamic> decoded = {};
      try {
        final parsed = jsonDecode(rawJson);
        if (parsed is Map) {
          decoded = Map<String, dynamic>.from(parsed);
        }
      } catch (e) {
        debugPrint("DEBUG: Malformed JSON in books catalog: $e");
        return; // Gracefully abort book sync without crashing the app
      }

      await _db.batch((batch) {
        decoded.forEach((semesterKey, bookList) {
          // Robust extraction: Pulls the integer from keys like "1", "semester 1", or "sem_1"
          final int semester = int.tryParse(semesterKey.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

          if (bookList is List) {
            for (var item in bookList) {
              if (item is Map) { // Added structural validation
                batch.insert(
                  _db.books,
                  BooksCompanion.insert(
                    // BUG FIX: Removed unsafe 'as String' casts to prevent TypeError crashes
                    id: item['id']?.toString() ?? '',
                    title: item['title']?.toString() ?? 'Unknown Title',
                    author: item['author']?.toString() ?? 'Unknown Author',
                    coverUrl: item['coverUrl']?.toString() ?? '',
                    downloadUrl: item['downloadUrl']?.toString() ?? '',
                    semester: semester, // Extracted dynamically from the parent JSON key
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        });
      });
    } catch (e) {
      debugPrint("DEBUG: Error syncing books catalog: $e");
      rethrow;
    }
  }

  Future<void> submitBookRequest({
    required String name,
    required String author,
    required int semester,
    required String isbn,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final today = DateTime.now();
    final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final docId = "${uid}_book_$dateString";

    await _firestore.collection('requests').doc(docId).set({
      'type': 'book',
      'requesterUid': uid,
      'bookName': name,
      'authorName': author,
      'semester': semester,
      'isbn': isbn,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}