import 'package:flutter_test/flutter_test.dart';
import 'package:myuniapp/src/data/models/attendance_conflict.dart';

void main() {
  group('AttendanceConflictChecker', () {
    test(
      'matches identical attendance even when timestamps differ',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'Computer Networks',
          'semester': 7,
          'section': 'C',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
            'S002',
            'S003',
          ],
          'updatedAt': '2026-09-23T10:30:00.123456Z',
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'Computer Networks',
          localSemester: 7,
          localSection: 'c',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            ' S003 ',
            'S001',
            'S002',
          ],
        );

        expect(matches, isTrue);
      },
    );

    test(
      'detects a student attendance change',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'Computer Networks',
          'semester': 7,
          'section': 'C',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
            'S002',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'Computer Networks',
          localSemester: 7,
          localSection: 'C',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S001',
            'S002',
            'S003',
          ],
        );

        expect(matches, isFalse);
      },
    );

    test(
      'detects a different subject',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'Database Systems',
          'semester': 7,
          'section': 'C',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'Computer Networks',
          localSemester: 7,
          localSection: 'C',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S001',
          ],
        );

        expect(matches, isFalse);
      },
    );

    test(
      'detects a different semester',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 8,
          'section': 'A',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S001',
          ],
        );

        expect(matches, isFalse);
      },
    );

    test(
      'detects a different section',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'B',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S001',
          ],
        );

        expect(matches, isFalse);
      },
    );

    test(
      'detects a different attendance date',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'A',
          'date': '2026-09-24',
          'presentStudentIds': [
            'S001',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S001',
          ],
        );

        expect(matches, isFalse);
      },
    );

    test(
      'normalizes ordering and whitespace',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'A',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S003',
            'S001',
            'S002',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'a',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            ' S002 ',
            'S001',
            'S003',
          ],
        );

        expect(matches, isTrue);
      },
    );

    test(
      'treats duplicate student IDs as the same logical attendance',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'A',
          'date': '2026-09-23',
          'presentStudentIds': [
            'S001',
            'S002',
          ],
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: [
            'S002',
            'S001',
            'S001',
          ],
        );

        expect(matches, isTrue);
      },
    );

    test(
      'missing cloud attendance list is treated as empty',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'A',
          'date': '2026-09-23',
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: const [],
        );

        expect(matches, isTrue);
      },
    );

    test(
      'non-list cloud attendance data is treated as empty',
          () {
        final cloudData = <String, dynamic>{
          'subjectId': 'DBMS',
          'semester': 7,
          'section': 'A',
          'date': '2026-09-23',
          'presentStudentIds': 'invalid',
        };

        final matches =
        AttendanceConflictChecker.cloudMatchesLocal(
          cloudData: cloudData,
          localSubjectId: 'DBMS',
          localSemester: 7,
          localSection: 'A',
          localDate: '2026-09-23',
          localPresentStudentIds: const [],
        );

        expect(matches, isTrue);
      },
    );
  });
}