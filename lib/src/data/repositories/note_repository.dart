import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../models/catalog_parser.dart';
import '../../providers/db_provider.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(dbProvider);

  return NoteRepository(db);
});

class NoteRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NoteRepository(this._db)
      : _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  Stream<List<Note>> watchNotesForSemester(
      int semester,
      ) {
    return (_db.select(_db.notes)
      ..where(
            (n) => n.semester.equals(semester),
      ))
        .watch();
  }

  Future<void> syncNotes(
      int userSemester,
      String userSection,
      ) async {
    try {
      final document = await _firestore
          .collection('metadata')
          .doc('notes_catalog')
          .get();

      if (!document.exists) {
        debugPrint(
          'Notes: notes_catalog metadata document does not exist.',
        );
        return;
      }

      final data = document.data();

      if (data == null) {
        debugPrint(
          'Notes: notes_catalog document has no data.',
        );
        return;
      }

      final rawJson = data['data'];

      if (rawJson is! String ||
          rawJson.trim().isEmpty) {
        debugPrint(
          'Notes: notes_catalog contains no valid JSON string.',
        );
        return;
      }

      List<NoteCatalogItem> catalog;

      try {
        catalog = CatalogParser.parseNotes(
          rawJson,
        );
      } on CatalogFormatException catch (error) {
        // Preserve the existing local catalog when remote data is malformed.
        debugPrint(
          'Notes: keeping existing local catalog because '
              'remote catalog is invalid: $error',
        );
        return;
      }

      // The remote catalog is authoritative. Once successfully validated,
      // replace the complete local catalog atomically.
      //
      // This reconciles deletions automatically.
      await _db.transaction(() async {
        await _db.delete(
          _db.notes,
        ).go();

        if (catalog.isEmpty) {
          return;
        }

        await _db.batch(
              (batch) {
            for (final item in catalog) {
              batch.insert(
                _db.notes,
                NotesCompanion.insert(
                  id: item.id,
                  title: item.title,
                  subjectName: item.subjectName,
                  authorName: item.authorName,
                  fileUrl: item.fileUrl,
                  semester: item.semester,
                  section: item.section,
                  createdAt:
                  item.createdAt ?? DateTime.now(),
                  isSynced:
                  const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          },
        );
      });

      debugPrint(
        'Notes: catalog synchronized successfully. '
            'Items: ${catalog.length}',
      );
    } on FirebaseException catch (error) {
      debugPrint(
        'Notes: Firebase sync failed '
            '${error.code}: ${error.message}',
      );
      rethrow;
    } catch (error) {
      debugPrint(
        'Notes: catalog sync failed: $error',
      );
      rethrow;
    }
  }

  Future<void> submitNoteRequest({
    required String subjectName,
    required int semester,
  }) async {
    final uid = _auth.currentUser?.uid;

    if (uid == null ||
        uid.trim().isEmpty) {
      throw Exception(
        'User not logged in.',
      );
    }

    final cleanSubject = subjectName.trim();

    if (cleanSubject.isEmpty) {
      throw Exception(
        'Subject name is required.',
      );
    }

    if (cleanSubject.length > 300) {
      throw Exception(
        'Subject name is too long.',
      );
    }

    if (semester < 1 || semester > 8) {
      throw Exception(
        'Semester must be between 1 and 8.',
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
        '${uid}_note_$dateString';

    try {
      await _firestore
          .collection('requests')
          .doc(documentId)
          .set({
        'type': 'note',
        'requesterUid': uid,
        'subjectName': cleanSubject,
        'semester': semester,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw Exception(
          'You have already submitted a note request today, '
              'or the request is not allowed.',
        );
      }

      rethrow;
    }
  }
}