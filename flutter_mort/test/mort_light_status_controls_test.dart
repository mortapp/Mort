import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light theme keeps selected filters and status labels readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MortTheme.light(),
        home: const Scaffold(
          body: Row(
            children: [
              MortCategoryPill(label: 'All', selected: true),
              MortJobStatusBadge(status: 'open'),
            ],
          ),
        ),
      ),
    );

    final filter = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(filter.selectedColor, MortColors.lightSurfaceRaised);
    expect(filter.labelStyle?.color, MortColors.lightText);

    final status = tester.widget<Text>(find.text('open'));
    expect(status.style?.color, MortColors.lightTextSoft);
  });
}
