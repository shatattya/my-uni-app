import 'package:flutter_test/flutter_test.dart';
import 'package:myuniapp/src/data/models/catalog_parser.dart';

void main() {
  group('CatalogParser.parseBooks', () {
    test('parses a valid books catalog', () {
      const json = '''
      {
        "1": [
          {
            "id": "book-1",
            "title": "Database Systems",
            "author": "Author One",
            "coverUrl": "https://example.com/cover.jpg",
            "downloadUrl": "https://example.com/book.pdf"
          }
        ],
        "semester 2": [
          {
            "id": "book-2",
            "title": "Operating Systems",
            "author": "Author Two",
            "coverUrl": "",
            "downloadUrl": "https://example.com/os.pdf"
          }
        ]
      }
      ''';

      final books = CatalogParser.parseBooks(json);

      expect(books.length, 2);

      expect(books[0].id, 'book-1');
      expect(books[0].title, 'Database Systems');
      expect(books[0].semester, 1);

      expect(books[1].id, 'book-2');
      expect(books[1].semester, 2);
    });

    test('uses safe defaults for optional book fields', () {
      const json = '''
      {
        "3": [
          {
            "id": "book-3",
            "title": "Computer Networks"
          }
        ]
      }
      ''';

      final books = CatalogParser.parseBooks(json);

      expect(books.single.author, 'Unknown Author');
      expect(books.single.coverUrl, '');
      expect(books.single.downloadUrl, '');
    });

    test('rejects an invalid semester', () {
      const json = '''
      {
        "semester 9": [
          {
            "id": "book-1",
            "title": "Invalid"
          }
        ]
      }
      ''';

      expect(
            () => CatalogParser.parseBooks(json),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });

    test('rejects duplicate book IDs', () {
      const json = '''
      {
        "1": [
          {
            "id": "same-id",
            "title": "Book One"
          }
        ],
        "2": [
          {
            "id": "same-id",
            "title": "Book Two"
          }
        ]
      }
      ''';

      expect(
            () => CatalogParser.parseBooks(json),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });

    test('rejects malformed JSON', () {
      expect(
            () => CatalogParser.parseBooks(
          '{not valid json',
        ),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });

    test('rejects a catalog containing only invalid entries', () {
      const json = '''
      {
        "1": [
          {
            "title": "Missing ID"
          },
          {
            "id": "",
            "title": "Empty ID"
          }
        ]
      }
      ''';

      expect(
            () => CatalogParser.parseBooks(json),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });

    test('skips malformed items when valid items remain', () {
      const json = '''
      {
        "1": [
          "not an object",
          {
            "title": "Missing ID"
          },
          {
            "id": "valid-book",
            "title": "Valid Book"
          }
        ]
      }
      ''';

      final books = CatalogParser.parseBooks(json);

      expect(books.length, 1);
      expect(books.single.id, 'valid-book');
    });
  });

  group('CatalogParser.parseNotes', () {
    test('parses a valid notes catalog', () {
      const json = '''
      {
        "1": [
          {
            "id": "note-1",
            "title": "Chapter 1",
            "subjectName": "Database Systems",
            "authorName": "Teacher One",
            "fileUrl": "https://example.com/note.pdf",
            "section": "c",
            "createdAt": "2026-09-23T10:30:00Z"
          }
        ]
      }
      ''';

      final notes = CatalogParser.parseNotes(json);

      expect(notes.length, 1);

      final note = notes.single;

      expect(note.id, 'note-1');
      expect(note.title, 'Chapter 1');
      expect(note.subjectName, 'Database Systems');
      expect(note.authorName, 'Teacher One');
      expect(note.fileUrl, 'https://example.com/note.pdf');
      expect(note.semester, 1);
      expect(note.section, 'C');
      expect(
        note.createdAt,
        DateTime.parse('2026-09-23T10:30:00Z'),
      );
    });

    test('uses safe defaults for optional note fields', () {
      const json = '''
      {
        "4": [
          {
            "id": "note-4",
            "title": "Algorithms",
            "subjectName": "Algorithms",
            "fileUrl": "https://example.com/a.pdf"
          }
        ]
      }
      ''';

      final note =
          CatalogParser.parseNotes(json).single;

      expect(note.authorName, 'Unknown');
      expect(note.section, 'All');
      expect(note.createdAt, isNull);
    });

    test('rejects duplicate note IDs', () {
      const json = '''
      {
        "1": [
          {
            "id": "same-id",
            "title": "Note One",
            "subjectName": "DBMS",
            "fileUrl": "https://example.com/1.pdf"
          }
        ],
        "2": [
          {
            "id": "same-id",
            "title": "Note Two",
            "subjectName": "OS",
            "fileUrl": "https://example.com/2.pdf"
          }
        ]
      }
      ''';

      expect(
            () => CatalogParser.parseNotes(json),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });

    test('rejects notes missing required fields', () {
      const json = '''
      {
        "1": [
          {
            "id": "note-1",
            "title": "Missing subject"
          }
        ]
      }
      ''';

      expect(
            () => CatalogParser.parseNotes(json),
        throwsA(
          isA<CatalogFormatException>(),
        ),
      );
    });
  });
}