import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mort payment status badge exposes a useful accessibility label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MortPaymentStatusBadge(
                label: 'Succeeded',
                icon: Icons.check_circle_rounded,
                color: MortColors.paymentSuccess,
              ),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(
        find.byType(MortPaymentStatusBadge),
      );
      expect(semantics.label, 'Payment status Succeeded');
      expect(find.text('Succeeded'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    },
  );
}
