import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mort_spacing.dart';
import '../../core/utils/financial_math.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/financial_safety.dart';
import '../../data/repositories/providers.dart';

/// Default year selector range: the current calendar year plus the three
/// before it (annual records with correct calendar-year math).
int currentFinancialYear() => DateTime.now().year;

List<int> selectableYears() {
  final current = currentFinancialYear();
  return [for (var y = current - 3; y <= current; y++) y];
}

/// Compact teen-dashboard card: real values only (zeros included), never a
/// fake wallet or balance. Tapping opens the Financial Safety Center.
class FinancialDashboardCard extends ConsumerWidget {
  const FinancialDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = currentFinancialYear();
    final summary = ref.watch(financialSummaryProvider(year));
    final alerts = ref.watch(financialAlertsProvider(year));

    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final levels =
            alerts.asData?.value.alerts
                .map((alert) => alert.level)
                .toList(growable: false) ??
            const <String>[];
        final check = financialCheckLabel(levels);
        return Semantics(
          label:
              'MORT Earnings Safety. $year tracked. '
              '${formatUsdCents(data.estimatedNetCents)} estimated net. '
              '${data.receiptsCount} receipts. Financial check: $check. View.',
          button: true,
          child: MortCard(
            onTap: () => context.go('/financial'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MORT Earnings Safety',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    MortBadge(label: '$year tracked', icon: Icons.receipt_long),
                  ],
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  '${formatUsdCents(data.estimatedNetCents)} estimated net',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  '${data.receiptsCount} receipts · Financial check: $check',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (data.isEmpty) ...[
                  const SizedBox(height: MortSpacing.xs),
                  Text(
                    'Your financial record starts when you complete work.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Count row (jobs, receipts) with screen-reader-friendly semantics.
class FinancialCountRow extends StatelessWidget {
  const FinancialCountRow({
    super.key,
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MortSpacing.xxs),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Text('$count', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// Money row with explicit semantics so screen readers announce label and
/// amount together (currency semantics for TalkBack).
class FinancialMoneyRow extends StatelessWidget {
  const FinancialMoneyRow({
    super.key,
    required this.label,
    required this.cents,
    this.emphasized = false,
  });

  final String label;
  final int cents;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final formatted = formatUsdCents(cents);
    return Semantics(
      label: '$label: $formatted',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MortSpacing.xxs),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            // Scale the amount down instead of overflowing at large text
            // scales / narrow widths (long currency values stay readable).
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatted,
                  style: emphasized
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared year selector used across Financial Safety screens.
class FinancialYearSelector extends StatelessWidget {
  const FinancialYearSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MortSpacing.sm,
      runSpacing: MortSpacing.sm,
      children: [
        for (final year in selectableYears())
          ChoiceChip(
            label: Text('$year'),
            selected: year == selected,
            onSelected: (_) => onChanged(year),
          ),
      ],
    );
  }
}

/// MORT Earnings Safety dashboard: earnings, expenses, estimated net,
/// financial checks, and the section directory.
class FinancialSafetyCenterScreen extends ConsumerStatefulWidget {
  const FinancialSafetyCenterScreen({super.key});

  @override
  ConsumerState<FinancialSafetyCenterScreen> createState() =>
      _FinancialSafetyCenterScreenState();
}

class _FinancialSafetyCenterScreenState
    extends ConsumerState<FinancialSafetyCenterScreen> {
  late int _year = currentFinancialYear();

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(financialSummaryProvider(_year));
    final alerts = ref.watch(financialAlertsProvider(_year));

    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Financial Safety',
          subtitle:
              'Keep earning while your records, expenses, and checks stay '
              'current and private to you.',
        ),
        FinancialYearSelector(
          selected: _year,
          onChanged: (year) => setState(() => _year = year),
        ),
        const SizedBox(height: MortSpacing.md),
        summary.when(
          loading: () => const MortLoading(
            label: 'Loading your records...',
            fullScreen: false,
          ),
          error: (error, _) => MortErrorState(
            title: 'Records unavailable',
            message: 'Your financial records could not be loaded. Try again.',
            action: MortButton(
              label: 'Retry',
              onPressed: () => ref.invalidate(financialSummaryProvider(_year)),
            ),
          ),
          data: (data) => _buildSummary(context, data, alerts),
        ),
        const SizedBox(height: MortSpacing.md),
        _SectionDirectory(year: _year),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    FinancialSummary data,
    AsyncValue<FinancialEvaluation> alerts,
  ) {
    if (data.isEmpty) {
      return Semantics(
        identifier: 'qa-financial-zero-state',
        child: MortEmptyState(
          title: '$_year records',
          message: 'Your financial record starts when you complete work.',
          action: MortActionRow(
            actions: [
              const MortAction(
                label: 'Learn how earnings tracking works',
                icon: Icons.menu_book_outlined,
                route: '/financial/learn',
              ),
              const MortAction(
                label: 'Add an expense',
                icon: Icons.receipt_long,
                route: '/financial/expenses',
              ),
            ],
          ),
        ),
      );
    }

    final levels =
        alerts.asData?.value.alerts
            .map((alert) => alert.level)
            .toList(growable: false) ??
        const <String>[];
    final check = financialCheckLabel(levels);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_year summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.sm),
              FinancialMoneyRow(
                label: 'Gross tracked',
                cents: data.grossTrackedCents,
              ),
              FinancialMoneyRow(
                label: 'Recorded expenses',
                cents: data.expensesCents,
              ),
              FinancialMoneyRow(
                label: 'Estimated net',
                cents: data.estimatedNetCents,
                emphasized: true,
              ),
              const Divider(),
              FinancialCountRow(
                label: 'Jobs completed',
                count: data.jobsCompleted,
              ),
              FinancialCountRow(
                label: 'Recorded expenses',
                count: data.expenseCount,
              ),
              FinancialCountRow(label: 'Receipts', count: data.receiptsCount),
              const SizedBox(height: MortSpacing.sm),
              Text(
                data.disclaimer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        _FinancialCheckPreviewCard(levels: levels, label: check),
        if (data.methodBreakdown.isNotEmpty) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment method breakdown',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MortSpacing.xs),
                for (final method in data.methodBreakdown)
                  FinancialMoneyRow(
                    label: _methodLabel(method),
                    cents: method.amountCents,
                  ),
                const SizedBox(height: MortSpacing.xs),
                Text(
                  'Every compensation category counts toward the same tracked '
                  'total. Changing payment method never resets earnings.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _methodLabel(FinancialMethodBreakdown method) {
    final category = method.compensationCategory;
    return '${category.label} (${method.count} '
        '${method.count == 1 ? 'job' : 'jobs'})';
  }
}

/// Compact Financial Check status on the dashboard. Always pairs the status
/// with the reassurance that work is unaffected (never color-only).
class _FinancialCheckPreviewCard extends StatelessWidget {
  const _FinancialCheckPreviewCard({required this.levels, required this.label});

  final List<String> levels;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      onTap: () => context.go('/financial/check'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Financial check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MortBadge(label: label),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'Financial checks are informational. They never block or limit '
            'your ability to keep working.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionDirectory extends StatelessWidget {
  const _SectionDirectory({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortSectionTitle(title: 'Sections'),
        MortActionRow(
          actions: [
            const MortAction(
              label: 'Expenses',
              icon: Icons.receipt_long_outlined,
              route: '/financial/expenses',
            ),
            const MortAction(
              label: 'Financial check',
              icon: Icons.fact_check_outlined,
              route: '/financial/check',
            ),
            const MortAction(
              label: 'Benefits check',
              icon: Icons.diversity_3_outlined,
              route: '/financial/benefits',
            ),
            const MortAction(
              label: 'Personal targets',
              icon: Icons.flag_outlined,
              route: '/financial/targets',
            ),
            const MortAction(
              label: 'Records & exports',
              icon: Icons.ios_share,
              route: '/financial/records',
            ),
            const MortAction(
              label: 'Keep earning',
              icon: Icons.trending_up,
              route: '/financial/keep-earning',
            ),
            const MortAction(
              label: 'Learn',
              icon: Icons.menu_book_outlined,
              route: '/financial/learn',
            ),
          ],
        ),
      ],
    );
  }
}
