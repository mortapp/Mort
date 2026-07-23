import 'package:flutter/material.dart';
import 'package:flutter_mort/core/utils/date_of_birth.dart';
import 'package:flutter_mort/core/widgets/date_of_birth_field.dart';
import 'package:flutter_test/flutter_test.dart';

Widget dobForm({
  required TextEditingController controller,
  required GlobalKey<FormState> formKey,
  required VoidCallback onValid,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              DateOfBirthField(
                controller: controller,
                showDatePickerButton: false,
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) onValid();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows MM/DD/YYYY placeholder and DOB helper text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      dobForm(
        controller: controller,
        formKey: GlobalKey<FormState>(),
        onValid: () {},
      ),
    );

    expect(find.text('MM/DD/YYYY'), findsOneWidget);
    expect(find.text('Month / Day / Year'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.number);
    expect(field.textInputAction, TextInputAction.done);
  });

  testWidgets('auto-inserts slashes in the field', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      dobForm(
        controller: controller,
        formKey: GlobalKey<FormState>(),
        onValid: () {},
      ),
    );

    await tester.enterText(find.byType(TextFormField), '06292011');
    expect(controller.text, '06/29/2011');
  });

  testWidgets('partial input does not validate as complete', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      dobForm(controller: controller, formKey: formKey, onValid: () {}),
    );

    await tester.enterText(find.byType(TextFormField), '062');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter your full date of birth.'), findsOneWidget);
  });

  testWidgets('invalid calendar date displays friendly error', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      dobForm(controller: controller, formKey: formKey, onValid: () {}),
    );

    await tester.enterText(find.byType(TextFormField), '02302011');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Enter a real calendar date.'), findsOneWidget);
  });

  testWidgets('valid DOB allows continuation and normalizes to ISO', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var continued = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      dobForm(
        controller: controller,
        formKey: formKey,
        onValid: () => continued = true,
      ),
    );

    await tester.enterText(find.byType(TextFormField), '06292011');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continued, isTrue);
    final date = DateOfBirthParser.tryParse(controller.text)!;
    expect(DateOfBirthParser.toIsoDate(date), '2011-06-29');
  });
}
