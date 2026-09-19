import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/history/models/payment_history.dart';

void main() {
  group('payment history', () {
    test('sorts entries newest first and filters cleanly', () {
      final entries = [
        const MortPaymentHistoryEntry(
          id: 'older',
          title: 'Hello',
          occurredAt: '2025-01-01T10:00:00Z',
          status: MortPaymentState.succeeded,
          amountCents: 1000,
          kind: MortPaymentHistoryKind.payment,
        ),
        const MortPaymentHistoryEntry(
          id: 'newer',
          title: 'World',
          occurredAt: '2026-01-01T10:00:00Z',
          status: MortPaymentState.declined,
          amountCents: 2000,
          kind: MortPaymentHistoryKind.payment,
        ),
      ];

      final sorted = MortPaymentHistoryEntry.sortByNewest(entries);
      expect(sorted.first.id, 'newer');
      expect(sorted.where((item) => item.matchesSearch('world')).length, 1);
      expect(sorted.where((item) => item.matchesYear(2025)).length, 1);
    });

    testWidgets('renders timeline and empty states', (tester) async {
      final entries = [
        const MortPaymentHistoryEntry(
          id: 'a',
          title: 'Job payment',
          occurredAt: '2026-01-15T12:00:00Z',
          status: MortPaymentState.succeeded,
          amountCents: 1250,
          kind: MortPaymentHistoryKind.payment,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MortPaymentHistoryView(
              entries: entries,
              selectedYear: 2026,
              searchQuery: '',
              currentFilter: MortPaymentHistoryFilter.all,
              isLoading: false,
              hasNextPage: false,
            ),
          ),
        ),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Job payment'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MortPaymentHistoryView(
              entries: [],
              selectedYear: 2026,
              searchQuery: '',
              currentFilter: MortPaymentHistoryFilter.all,
              isLoading: false,
              hasNextPage: false,
            ),
          ),
        ),
      );

      expect(find.text('No payment activity'), findsOneWidget);
    });
  });
}
