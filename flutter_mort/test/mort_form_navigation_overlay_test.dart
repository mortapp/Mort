import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('form family preserves native editable and select controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final password = TextEditingController();
    final dob = TextEditingController();
    addTearDown(password.dispose);
    addTearDown(dob.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            MortPasswordField(label: 'Password', controller: password),
            MortDateField(controller: dob, showDatePickerButton: false),
            MortSelect<String>(
              label: 'Role',
              value: 'teen',
              items: const {'teen': 'Teen', 'adult': 'Adult'},
              onChanged: (_) {},
            ),
            const MortSearchField(hint: 'Search jobs'),
            const MortTextArea(label: 'Message'),
          ],
        ),
      ),
    );

    final editableFields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(editableFields, hasLength(4));
    expect(editableFields.first.obscureText, isTrue);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('MM/DD/YYYY'), findsOneWidget);
    final dobSemantics = find.bySemanticsLabel('Date of birth');
    expect(dobSemantics, findsOneWidget);
    expect(
      tester.getSemantics(dobSemantics).flagsCollection.isTextField,
      isTrue,
    );
    expect(find.text('Message'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('form fields expose focus, error, and disabled behavior', (
    tester,
  ) async {
    final passwordFocus = FocusNode();
    final selectFocus = FocusNode();
    final searchFocus = FocusNode();
    final notesFocus = FocusNode();
    final password = TextEditingController();
    final dob = TextEditingController();
    addTearDown(passwordFocus.dispose);
    addTearDown(selectFocus.dispose);
    addTearDown(searchFocus.dispose);
    addTearDown(notesFocus.dispose);
    addTearDown(password.dispose);
    addTearDown(dob.dispose);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            MortPasswordField(
              label: 'Password',
              controller: password,
              focusNode: passwordFocus,
              errorText: 'Password required',
            ),
            MortDateField(
              controller: dob,
              enabled: false,
              errorText: 'Date locked',
              showDatePickerButton: false,
            ),
            MortSelect<String>(
              label: 'Focused role',
              value: 'teen',
              items: const {'teen': 'Teen'},
              focusNode: selectFocus,
              errorText: 'Confirm role',
              onChanged: (_) {},
            ),
            const MortSelect<String>(
              label: 'Disabled role',
              value: 'teen',
              items: {'teen': 'Teen'},
              onChanged: null,
            ),
            MortSearchField(
              hint: 'Search roles',
              focusNode: searchFocus,
              errorText: 'Search unavailable',
            ),
            const MortSearchField(hint: 'Disabled search', enabled: false),
            MortTextArea(
              label: 'Notes',
              focusNode: notesFocus,
              errorText: 'Notes required',
            ),
            const MortTextArea(label: 'Disabled notes', enabled: false),
          ],
        ),
      ),
    );

    passwordFocus.requestFocus();
    await tester.pump();
    expect(passwordFocus.hasFocus, isTrue);
    expect(find.text('Password required'), findsOneWidget);
    expect(find.text('Date locked'), findsOneWidget);
    selectFocus.requestFocus();
    await tester.pump();
    expect(selectFocus.hasFocus, isTrue);
    expect(find.text('Confirm role'), findsOneWidget);
    final disabled = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Disabled role',
      ),
    );
    expect(disabled.onChanged, isNull);
    searchFocus.requestFocus();
    await tester.pump();
    expect(searchFocus.hasFocus, isTrue);
    expect(find.text('Search unavailable'), findsOneWidget);
    final disabledSearch = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Disabled search',
      ),
    );
    expect(disabledSearch.enabled, isFalse);
    notesFocus.requestFocus();
    await tester.pump();
    expect(notesFocus.hasFocus, isTrue);
    expect(find.text('Notes required'), findsOneWidget);
    final disabledNotes = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Disabled notes'),
    );
    expect(disabledNotes.enabled, isFalse);
  });

  testWidgets('bottom navigation preserves selection and callback fidelity', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        MortBottomNavigation(
          index: 1,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.work_outline),
              label: 'Jobs',
            ),
          ],
          onDestinationSelected: (index) => selected = index,
        ),
      ),
    );

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);
    final navigationTheme = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    expect(
      navigationTheme.indicatorColor,
      MortColors.accent.withValues(alpha: 0.18),
    );
    expect(
      navigationTheme.iconTheme!.resolve(<WidgetState>{
        WidgetState.selected,
      })!.color,
      MortColors.accent,
    );
    expect(
      navigationTheme.iconTheme!.resolve(<WidgetState>{})!.color,
      MortColors.textMuted,
    );
    await tester.tap(find.text('Home'));
    expect(selected, 0);
  });

  testWidgets('destructive modal remains safe-area and keyboard aware', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => MortModal.confirm(
              context,
              title: 'Remove report?',
              message: 'This action cannot be undone.',
              confirmLabel: 'Remove',
              destructive: true,
            ),
            child: const Text('Open modal'),
          ),
        ),
        viewInsets: const EdgeInsets.only(bottom: 260),
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();

    expect(find.text('Remove report?'), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    expect(find.byType(AnimatedPadding), findsOneWidget);
    final insetPadding = tester.widget<AnimatedPadding>(
      find.byType(AnimatedPadding),
    );
    expect((insetPadding.padding as EdgeInsets).bottom, 280);
    final remove = tester.widget<MortButton>(
      find.widgetWithText(MortButton, 'Remove'),
    );
    expect(remove.style, MortButtonStyle.danger);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(
  Widget child, {
  EdgeInsets viewInsets = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      viewInsets: viewInsets,
      textScaler: textScaler,
    ),
    child: MaterialApp(
      theme: MortTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
