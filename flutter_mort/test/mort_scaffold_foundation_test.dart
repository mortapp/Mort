import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MortScaffold preserves the production safe layout contract', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        MortScaffold(
          scrollController: controller,
          bottom: const Text('Navigation slot'),
          children: const [
            MortHeader(title: 'Home'),
            Text('Production body'),
          ],
        ),
      ),
    );

    expect(find.byType(MortSpaceBackground), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller,
      same(controller),
    );
    final safeArea = tester.widget<SafeArea>(
      find
          .descendant(
            of: find.byType(MortScaffold),
            matching: find.byType(SafeArea),
          )
          .first,
    );
    expect(safeArea.minimum.bottom, 48);
    final contentConstraint = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .map((widget) => widget.constraints.maxWidth)
        .where((width) => width == MortSpacing.maxContentWidth);
    expect(contentConstraint, hasLength(1));
    expect(find.text('Navigation slot'), findsOneWidget);
    expect(find.byType(MortBackButton), findsNothing);
  });

  testWidgets('header uses restrained hierarchy on narrow large-text screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MortScaffold(
          children: [
            MortHeader(
              eyebrow: 'teen workspace',
              title: 'Jobs and opportunities',
              subtitle: 'A clear view of nearby work and current progress.',
              trailing: MortIconButton(
                icon: Icons.help_outline,
                tooltip: 'Help',
              ),
            ),
          ],
        ),
        size: const Size(320, 900),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(find.text('teen workspace'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Jobs and opportunities'));
    expect(title.style?.fontWeight, FontWeight.w300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MortScaffold supports non-scroll content and custom gutters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const MortScaffold(
          scroll: false,
          padding: EdgeInsets.all(31),
          children: [Text('Fixed content')],
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
      find.descendant(
        of: find.byType(MortScaffold),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding && widget.padding == const EdgeInsets.all(31),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('system back dismisses the keyboard before route handling', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var routeHandlerCalled = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          viewInsets: EdgeInsets.only(bottom: 280),
        ),
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: MortScaffold(
            scroll: false,
            onWillPop: (_) async {
              routeHandlerCalled = true;
              return true;
            },
            children: [TextField(focusNode: focusNode, autofocus: true)],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(routeHandlerCalled, isFalse);
  });
}

Widget _host(
  Widget child, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: textScaler),
    child: MaterialApp(theme: MortTheme.dark(), home: child),
  );
}
