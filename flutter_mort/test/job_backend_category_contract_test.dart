import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/data/models/job.dart';

void main() {
  test('Flutter job categories map to the live Supabase category enum', () {
    expect(JobCategoryContract.toBackend('lawn care'), 'yard_work');
    expect(JobCategoryContract.toBackend('dog walking'), 'pet_care');
    expect(JobCategoryContract.toBackend('cleaning'), 'household_help');
    expect(
      JobCategoryContract.toBackend('moving/light lifting'),
      'moving_help',
    );
    expect(JobCategoryContract.toBackend('technology help'), 'tech_help');
    expect(JobCategoryContract.toBackend('tutoring'), 'tutoring');
    expect(JobCategoryContract.toBackend('other safe local work'), 'other');
  });

  test(
    'live category enum maps back to an editable Flutter category label',
    () {
      expect(JobCategoryContract.toDisplay('yard_work'), 'lawn care');
      expect(JobCategoryContract.toDisplay('pet_care'), 'pet care');
      expect(JobCategoryContract.toDisplay('household_help'), 'cleaning');
      expect(
        JobCategoryContract.toDisplay('moving_help'),
        'moving/light lifting',
      );
      expect(JobCategoryContract.toDisplay('tech_help'), 'technology help');
    },
  );
}
