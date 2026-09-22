import 'package:flutter_test/flutter_test.dart';
import 'package:myuniapp/src/data/models/attendance_draft.dart';

void main() {
  group('AttendanceDraft', () {
    test('normalizes valid attendance input', () {
      final draft = AttendanceDraft.create(
        subjectName: '  Computer   Networks  ',
        semester: 7,
        section: ' c ',
        date: '2026-09-23',
        presentStudentIds: [
          ' S003 ',
          'S001',
          'S003',
          'S002',
        ],
      );

      expect(draft.subjectName, 'Computer Networks');
      expect(draft.semester, 7);
      expect(draft.section, 'C');
      expect(draft.date, '2026-09-23');
      expect(
        draft.presentStudentIds,
        ['S001', 'S002', 'S003'],
      );
    });

    test('rejects empty subject', () {
      expect(
            () => AttendanceDraft.create(
          subjectName: '   ',
          semester: 7,
          section: 'A',
          date: '2026-09-23',
          presentStudentIds: const [],
        ),
        throwsA(isA<AttendanceValidationException>()),
      );
    });

    test('rejects invalid semester', () {
      expect(
            () => AttendanceDraft.create(
          subjectName: 'DBMS',
          semester: 9,
          section: 'A',
          date: '2026-09-23',
          presentStudentIds: const [],
        ),
        throwsA(isA<AttendanceValidationException>()),
      );
    });

    test('rejects invalid section', () {
      expect(
            () => AttendanceDraft.create(
          subjectName: 'DBMS',
          semester: 7,
          section: 'D',
          date: '2026-09-23',
          presentStudentIds: const [],
        ),
        throwsA(isA<AttendanceValidationException>()),
      );
    });

    test('rejects impossible calendar date', () {
      expect(
            () => AttendanceDraft.create(
          subjectName: 'DBMS',
          semester: 7,
          section: 'A',
          date: '2026-02-30',
          presentStudentIds: const [],
        ),
        throwsA(isA<AttendanceValidationException>()),
      );
    });

    test('rejects empty student IDs', () {
      expect(
            () => AttendanceDraft.create(
          subjectName: 'DBMS',
          semester: 7,
          section: 'A',
          date: '2026-09-23',
          presentStudentIds: ['S001', ' '],
        ),
        throwsA(isA<AttendanceValidationException>()),
      );
    });
  });
}