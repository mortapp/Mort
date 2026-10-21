import 'package:flutter_mort/data/models/school_directory_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonical school identity', () {
    test('parses record verification and grade span without exposing identifiers', () {
      final school = SchoolDirectoryEntry.fromJson(const {
        'id': '00000000-0000-4000-8000-000000000201',
        'official_name': 'Herron-Riverside High School',
        'display_name': 'Herron-Riverside High School',
        'district': 'Herron Classical Schools',
        'city': 'Indianapolis',
        'state': 'IN',
        'school_type': 'high_school',
        'school_record_verified': true,
        'lowest_grade': 9,
        'highest_grade': 12,
      });

      expect(school.schoolRecordVerified, isTrue);
      expect(school.gradeSpanLabel, 'Grades 9–12');
      expect(school.locationLabel, 'Indianapolis, IN');
    });

    test('supports combined grade spans without relying on school name text', () {
      final school = SchoolDirectoryEntry.fromJson(const {
        'id': '00000000-0000-4000-8000-000000000202',
        'official_name': 'Synthetic Community Academy',
        'display_name': 'Synthetic Community Academy',
        'city': 'Indianapolis',
        'state': 'IN',
        'school_type': 'other',
        'school_record_verified': true,
        'lowest_grade': 7,
        'highest_grade': 12,
      });

      expect(school.gradeSpanLabel, 'Grades 7–12');
      expect(school.typeLabel, 'School');
    });
  });
}
