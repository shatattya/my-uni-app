import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../models/catalog_parser.dart';
import '../../providers/db_provider.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(dbProvider);

  return BookRepository(db);
});

class BookRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BookRepository(this._db)
      : _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  Stream<List<Book>> watchBooksForSemester(
      int semester,
      ) {
    return (_db.select(_db.books)
      ..where(
            (b) => b.semester.equals(semester),
      ))
        .watch();
  }

  Future<void> syncBooks() async {
    try {
      final document = await _firestore
          .collection('metadata')
          .doc('books_catalog')
          .get();

      if (!document.exists) {
        debugPrint(
          'Books: books_catalog metadata document does not exist.',
        );
        return;
      }

      final data = document.data();

      if (data == null) {
        debugPrint(
          'Books: books_catalog document has no data.',
        );
        return;
      }

      final rawJson = data['data'];

      if (rawJson is! String ||
          rawJson.trim().isEmpty) {
        debugPrint(
          'Books: books_catalog contains no valid JSON string.',
        );
        return;
      }

      List<BookCatalogItem> catalog;

      try {
        catalog = CatalogParser.parseBooks(
          rawJson,
        );
      } on CatalogFormatException catch (error) {
        // Preserve the existing local catalog when remote data is malformed.
        debugPrint(
          'Books: keeping existing local catalog because '
              'remote catalog is invalid: $error',
        );
        return;
      }

      // Reconciliation strategy:
      //
      // The remote catalog is authoritative. Once it has been successfully
      // validated, replace the entire local catalog atomically.
      //
      // This automatically removes books that were deleted remotely.
      await _db.transaction(() async {
        await _db.delete(
          _db.books,
        ).go();

        if (catalog.isEmpty) {
          return;
        }

        await _db.batch(
              (batch) {
            for (final item in catalog) {
              batch.insert(
                _db.books,
                BooksCompanion.insert(
                  id: item.id,
                  title: item.title,
                  author: item.author,
                  coverUrl: item.coverUrl,
                  downloadUrl: item.downloadUrl,
                  semester: item.semester,
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          },
        );
      });

      debugPrint(
        'Books: catalog synchronized successfully. '
            'Items: ${catalog.length}',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Books: Firebase sync failed '
            '${error.code}: ${error.message}',
      );
      rethrow;
    } catch (error) {
      debugPrint(
        'Books: catalog sync failed: $error',
      );
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

    if (uid == null ||
        uid.trim().isEmpty) {
      throw Exception(
        'User not logged in.',
      );
    }

    final cleanName = name.trim();
    final cleanAuthor = author.trim();
    final cleanIsbn = isbn.trim();

    if (cleanName.isEmpty) {
      throw Exception(
        'Book name is required.',
      );
    }

    if (cleanName.length > 300) {
      throw Exception(
        'Book name is too long.',
      );
    }

    if (cleanAuthor.length > 300) {
      throw Exception(
        'Author name is too long.',
      );
    }

    if (semester < 1 || semester > 8) {
      throw Exception(
        'Semester must be between 1 and 8.',
      );
    }

    if (cleanIsbn.length > 32) {
      throw Exception(
        'ISBN is too long.',
      );
    }

    final bangladeshToday = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 6));

    final dateString =
        '${bangladeshToday.year}-'
        '${bangladeshToday.month.toString().padLeft(2, '0')}-'
        '${bangladeshToday.day.toString().padLeft(2, '0')}';

    final documentId =
        '${uid}_book_$dateString';

    try {
      await _firestore
          .collection('requests')
          .doc(documentId)
          .set({
        'type': 'book',
        'requesterUid': uid,
        'bookName': cleanName,
        'authorName': cleanAuthor,
        'semester': semester,
        'isbn': cleanIsbn,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw Exception(
          'You have already submitted a book request today, '
              'or the request is not allowed.',
        );
      }

      rethrow;
    }
  }
}