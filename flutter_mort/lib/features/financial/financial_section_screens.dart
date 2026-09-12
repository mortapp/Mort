import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/money/mort_service_fee.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/financial_math.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/financial_safety.dart';
import '../../data/repositories/financial_repository.dart';
import '../../data/repositories/providers.dart';
import '../guide/mort_guide_screens.dart';
import 'financial_export_service.dart';
import 'financial_safety_center.dart';

/// Shared provider invalidation after any Financial Safety data change.
void _invalidateFinancialData(WidgetRef ref, int year) {
  ref.invalidate(financialSummaryProvider(year));
  ref.invalidate(financialExpensesProvider(year));
  ref.invalidate(financialAlertsProvider(year));
  ref.invalidate(financialYearReportProvider(year));
}

// ---------------------------------------------------------------------------
// EXPENSES
// ---------------------------------------------------------------------------

/// Expense ledger: real recorded expenses with receipts. Expenses are
/// "recorded expenses" / "potential business expenses" — MORT never labels
/// one deductible.
class FinancialExpensesScreen extends ConsumerStatefulWidget {
  const FinancialExpensesScreen({super.key});

  @override
  ConsumerState<FinancialExpensesScreen> createState() =>
      _FinancialExpensesScreenState();
}

class _FinancialExpensesScreenState
    extends ConsumerState<FinancialExpensesScreen> {
  late int _year = currentFinancialYear();

  Future<void> _openExpenseForm({ExpenseRecord? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MortColors.cardAlt,
      builder: (_) => _ExpenseFormSheet(year: _year, existing: existing),
    );
    if (saved == true) {
      _invalidateFinancialData(ref, _year);
    }
  }

  Future<void> _openExpenseDetail(ExpenseRecord expense) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MortColors.cardAlt,
      builder: (_) => _ExpenseDetailSheet(expense: expense, year: _year),
    );
    _invalidateFinancialData(ref, _year);
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(financialExpensesProvider(_year));
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Expenses',
          subtitle:
              'Record work expenses and receipts. Receipts stay private to '
              'you.',
        ),
        FinancialYearSelector(
          selected: _year,
          onChanged: (year) => setState(() => _year = year),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Expenses are recorded expenses and potential business '
              'expenses. MORT does not decide whether an expense is '
              'deductible.',
        ),
        const SizedBox(height: MortSpacing.md),
        expenses.when(
          loading: () => const MortLoading(
            label: 'Loading expenses...',
            fullScreen: false,
          ),
          error: (error, _) => MortErrorState(
            title: 'Expenses unavailable',
            message: 'Your expense records could not be loaded. Try again.',
          ),
          data: (records) {
            if (records.isEmpty) {
              return MortEmptyState(
                title: 'No recorded expenses',
                message:
                    'Your financial record starts when you complete work. '
                    'Add supplies, fuel, tools, or other work expenses to '
                    'keep your records current.',
                action: MortButton(
                  label: 'Add an expense',
                  icon: Icons.add,
                  onPressed: _openExpenseForm,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final expense in records) ...[
                  MortCard(
                    onTap: () => _openExpenseDetail(expense),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                expense.expenseCategory.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              formatUsdCents(expense.amountCents),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          _expenseDateLabel(expense.spentOn),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (expense.merchant.isNotEmpty)
                          Text(
                            expense.merchant,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: MortSpacing.xs),
                        MortBadge(
                          label: expense.hasReceipt
                              ? 'Receipt attached'
                              : 'No receipt',
                          color: expense.hasReceipt
                              ? MortColors.success
                              : MortColors.textMuted,
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Add an expense',
          icon: Icons.add,
          onPressed: _openExpenseForm,
        ),
      ],
    );
  }
}

String _expenseDateLabel(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  const _ExpenseFormSheet({required this.year, this.existing});

  final int year;
  final ExpenseRecord? existing;

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _description;
  late ExpenseCategory _category;
  late DateTime _spentOn;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : (widget.existing!.amountCents ~/ 100).toString(),
    );
    _merchant = TextEditingController(text: widget.existing?.merchant ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _category = widget.existing?.expenseCategory ?? ExpenseCategory.supplies;
    _spentOn = widget.existing?.spentOn ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the amount you spent.';
    if (!RegExp(r'^\d{1,7}(?:\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter dollars with no more than 2 decimal places.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = MortServiceFee.tryParseAdultAmount(_amount.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = 'Enter a valid expense amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(financialRepositoryProvider);
      if (widget.existing == null) {
        await repository.createExpense(
          amountCents: cents,
          spentOn: _spentOn,
          category: _category,
          merchant: _merchant.text.trim(),
          description: _description.text.trim(),
        );
      } else {
        await repository.updateExpense(
          widget.existing!.id,
          amountCents: cents,
          spentOn: _spentOn,
          category: _category,
          merchant: _merchant.text.trim(),
          description: _description.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MortSpacing.lg,
        MortSpacing.lg,
        MortSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + MortSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Add an expense' : 'Edit expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.md),
              MortTextField(
                label: 'Amount (USD)',
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: MortSpacing.sm),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _spentOn.isAfter(DateTime.now())
                        ? DateTime.now()
                        : _spentOn,
                    firstDate: DateTime(2019),
                    lastDate: DateTime.now().add(const Duration(days: 366)),
                  );
                  if (picked != null) setState(() => _spentOn = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date spent'),
                  child: Text(_expenseDateLabel(_spentOn)),
                ),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortDropdown<ExpenseCategory>(
                label: 'Category',
                value: _category,
                items: {
                  for (final category in ExpenseCategory.values)
                    category: category.label,
                },
                onChanged: (value) => setState(
                  () => _category = value ?? ExpenseCategory.supplies,
                ),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Merchant (optional)',
                controller: _merchant,
                maxLength: 120,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Description (optional)',
                controller: _description,
                maxLength: 500,
              ),
              if (_error != null) ...[
                const SizedBox(height: MortSpacing.sm),
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: MortColors.danger),
                ),
              ],
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: widget.existing == null
                    ? 'Save expense'
                    : 'Save changes',
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'Cancel',
                style: MortButtonStyle.ghost,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseDetailSheet extends ConsumerStatefulWidget {
  const _ExpenseDetailSheet({required this.expense, required this.year});

  final ExpenseRecord expense;
  final int year;

  @override
  ConsumerState<_ExpenseDetailSheet> createState() =>
      _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<_ExpenseDetailSheet> {
  String? _signedUrl;
  bool _loadingUrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense.hasReceipt) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    setState(() => _loadingUrl = true);
    final url = await ref
        .read(financialRepositoryProvider)
        .signedReceiptUrl(widget.expense.receiptPath!);
    if (mounted) setState(() => _signedUrl = url);
    if (mounted) setState(() => _loadingUrl = false);
  }

  Future<void> _attachReceipt(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(financialRepositoryProvider);
      final file = await repository.chooseReceiptPhoto(source: source);
      if (file == null) return;
      await repository.attachReceipt(file, widget.expense.id);
      _invalidateFinancialData(ref, widget.year);
      if (mounted) Navigator.pop(context);
    } on ReceiptTooLarge catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('The receipt could not be attached. Try again.'),
        ),
      );
    }
  }

  Future<void> _removeReceipt() async {
    try {
      await ref
          .read(financialRepositoryProvider)
          .removeReceipt(widget.expense.id, widget.expense.receiptPath!);
      _invalidateFinancialData(ref, widget.year);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'The receipt could not be removed. Try again.');
      }
    }
  }

  Future<void> _deleteExpense() async {
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Delete this expense?',
      message:
          'This removes the expense record. Attached receipts are also '
          'removed. This cannot be undone.',
      confirmLabel: 'Delete expense',
    );
    if (!confirmed) return;
    try {
      await ref
          .read(financialRepositoryProvider)
          .deleteExpense(widget.expense.id);
      _invalidateFinancialData(ref, widget.year);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'The expense could not be deleted. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MortSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recorded expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.sm),
              FinancialMoneyRow(
                label: expense.expenseCategory.label,
                cents: expense.amountCents,
              ),
              Text(
                _expenseDateLabel(expense.spentOn),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (expense.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: MortSpacing.xs),
                  child: Text(
                    expense.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: MortSpacing.md),
              Text(
                'Receipt (private — only you can see it)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: MortSpacing.xs),
              if (expense.hasReceipt) ...[
                if (_loadingUrl)
                  const MortLoading(
                    label: 'Opening receipt...',
                    fullScreen: false,
                  )
                else if (_signedUrl != null)
                  Semantics(
                    label: 'Receipt image preview',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _signedUrl!,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Text(
                          'The receipt preview could not be loaded.',
                        ),
                      ),
                    ),
                  )
                else
                  const Text('The receipt preview could not be loaded.'),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Replace receipt',
                  icon: Icons.upload_file,
                  style: MortButtonStyle.secondary,
                  onPressed: () => _attachReceipt(ImageSource.gallery),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Remove receipt',
                  icon: Icons.delete_outline,
                  style: MortButtonStyle.secondary,
                  onPressed: _removeReceipt,
                ),
              ] else ...[
                const Text(
                  'Attach a receipt photo so your records stay ready when '
                  'you need them.',
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Attach receipt photo',
                  icon: Icons.photo_library_outlined,
                  onPressed: () => _attachReceipt(ImageSource.gallery),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Take a photo',
                  icon: Icons.photo_camera_outlined,
                  style: MortButtonStyle.secondary,
                  onPressed: () => _attachReceipt(ImageSource.camera),
                ),
              ],
              const SizedBox(height: MortSpacing.md),
              MortButton(
                label: 'Delete expense',
                icon: Icons.delete_outline,
                style: MortButtonStyle.danger,
                onPressed: _deleteExpense,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'Close',
                style: MortButtonStyle.ghost,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FINANCIAL CHECK + INCOME CONTINUITY (KEEP EARNING)
// ---------------------------------------------------------------------------

/// Copy for each alert level. Never implies a block, a debt, or a benefits
/// loss.
String alertHeadline(String level) => switch (level) {
  'HEADS_UP' => 'HEADS UP',
  'FINANCIAL_CHECK' => 'FINANCIAL CHECK',
  'REVIEW_RECOMMENDED' => 'REVIEW RECOMMENDED',
  'THRESHOLD_REACHED' => 'THRESHOLD REACHED',
  _ => 'FINANCIAL CHECK',
};

String alertCopy(String level) => switch (level) {
  'HEADS_UP' =>
    'Your earnings are increasing. This is a good time to make sure your '
        'records and expenses are current.',
  'FINANCIAL_CHECK' =>
    "You may be approaching a financial threshold you've asked MORT to "
        'monitor. Review the applicable rules before accepting substantially '
        'more work.',
  'REVIEW_RECOMMENDED' =>
    "You're close to a tracked threshold. Review the official rule and "
        'make sure your records are current.',
  'THRESHOLD_REACHED' =>
    "You've reached this tracked threshold. This does not automatically "
        'mean you owe tax or lose benefits. Review the rule and decide how '
        'you want to continue.',
  _ => 'Review the applicable rules before accepting substantially more work.',
};

class FinancialCheckScreen extends ConsumerWidget {
  const FinancialCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = currentFinancialYear();
    final evaluation = ref.watch(financialAlertsProvider(year));
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Financial Check',
          subtitle:
              'Informational checks based on your tracked earnings and the '
              'rules you asked MORT to monitor.',
        ),
        const MortSafetyBanner(
          message:
              'Financial checks are informational. They never block or limit '
              'your ability to keep working.',
        ),
        const SizedBox(height: MortSpacing.md),
        evaluation.when(
          loading: () => const MortLoading(
            label: 'Checking your earnings...',
            fullScreen: false,
          ),
          error: (error, _) => MortErrorState(
            title: 'Financial check unavailable',
            message: 'Your financial check could not be loaded. Try again.',
          ),
          data: (data) {
            if (data.alerts.isEmpty) {
              return const MortEmptyState(
                title: 'No financial checks right now',
                message:
                    'When your tracked earnings approach a threshold you '
                    'asked MORT to monitor, a check will appear here.',
                icon: Icons.fact_check_outlined,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final alert in data.alerts) ...[
                  _AlertCard(alert: alert),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortSectionTitle(
          title: 'Keep earning',
          subtitle:
              'Income Continuity Mode: MORT never automatically blocks income '
              'because an informational threshold was crossed.',
        ),
        const IncomeContinuityActions(),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final FinancialAlert alert;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: alert.isStale
          ? MortColors.warning.withValues(alpha: 0.10)
          : MortColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alertHeadline(alert.level),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MortBadge(
                label: alert.isStale ? 'Rule needs review' : alert.label,
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            alertCopy(alert.level),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (alert.thresholdCents != null) ...[
            const SizedBox(height: MortSpacing.sm),
            FinancialMoneyRow(
              label: 'Tracked gross',
              cents: alert.percent >= 100
                  ? alert.thresholdCents!
                  : alert.thresholdCents! * alert.percent ~/ 100,
            ),
            FinancialMoneyRow(
              label: 'Tracked threshold',
              cents: alert.thresholdCents!,
            ),
            Text(
              '${alert.percent}% of the tracked threshold',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (alert.isStale) ...[
            const SizedBox(height: MortSpacing.sm),
            const MortSafetyBanner(
              message:
                  "We can't verify the current rule right now. Review the "
                  'official program information before making a financial '
                  'decision.',
            ),
          ],
          if (alert.sourceUrl != null && alert.sourceUrl!.isNotEmpty) ...[
            const SizedBox(height: MortSpacing.sm),
            MortSourceLink(
              label: 'Official source: ${alert.sourceAgency ?? 'agency'}',
              url: alert.sourceUrl!,
            ),
          ],
        ],
      ),
    );
  }
}

class MortSourceLink extends StatelessWidget {
  const MortSourceLink({super.key, required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = safeExternalHttpsUri(url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            MortToast.show(context, 'This source link could not be opened.');
          }
        }
      },
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 18,
            color: MortColors.safetyBlue,
          ),
          const SizedBox(width: MortSpacing.xs),
          Expanded(child: Text(label)),
          const Icon(Icons.open_in_new, size: 16),
        ],
      ),
    );
  }
}

/// Income Continuity Mode actions. Every option stays available no matter
/// which alert level is active — nothing here is ever disabled by a threshold.
class IncomeContinuityActions extends StatelessWidget {
  const IncomeContinuityActions({super.key});

  @override
  Widget build(BuildContext context) {
    return MortActionRow(
      actions: const [
        MortAction(
          label: 'Continue earning',
          icon: Icons.work_outline,
          route: '/teen/jobs',
        ),
        MortAction(
          label: 'Review earnings',
          icon: Icons.paid_outlined,
          route: '/financial',
        ),
        MortAction(
          label: 'Review expenses',
          icon: Icons.receipt_long_outlined,
          route: '/financial/expenses',
        ),
        MortAction(
          label: 'Set personal earning target',
          icon: Icons.flag_outlined,
          route: '/financial/targets',
        ),
        MortAction(
          label: 'Download records',
          icon: Icons.ios_share,
          route: '/financial/records',
        ),
        MortAction(
          label: 'Review official rule',
          icon: Icons.menu_book_outlined,
          route: '/financial/learn',
        ),
        MortAction(
          label: 'Talk with guardian',
          icon: Icons.family_restroom,
          route: '/settings/guardian-mode',
        ),
        MortAction(
          label: 'Ask MORT Guide',
          icon: Icons.assistant_outlined,
          route: '/guide',
        ),
        MortAction(
          label: 'Find official assistance',
          icon: Icons.support_outlined,
          route: '/financial/learn',
        ),
        MortAction(
          label: 'Contact support',
          icon: Icons.support_agent,
          route: '/support',
        ),
      ],
    );
  }
}

/// Keep Earning screen (Income Continuity Mode).
class FinancialKeepEarningScreen extends StatelessWidget {
  const FinancialKeepEarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Income continuity mode',
          title: 'Keep Earning',
          subtitle:
              'Some teens rely on MORT work for meaningful income. Reaching '
              'a financial check never stops you from working.',
        ),
        const MortSafetyBanner(
          message:
              'A financial check is not a work ban. Discover, applications, '
              'accepted jobs, messages, completion, reviews, and your account '
              'all stay available.',
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'What you can do right now: keep accepting work, review your '
            'earnings and expenses, read the official rule you want to '
            'check, set a personal earning target, adjust alert preferences, '
            'download your records, or talk with your guardian or MORT '
            'Guide.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const IncomeContinuityActions(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BENEFITS CHECK
// ---------------------------------------------------------------------------

/// Optional Benefits Check. Participation is never required to use MORT;
/// selections are private and never influence matching or ranking.
class FinancialBenefitsScreen extends ConsumerStatefulWidget {
  const FinancialBenefitsScreen({super.key});

  @override
  ConsumerState<FinancialBenefitsScreen> createState() =>
      _FinancialBenefitsScreenState();
}

class _FinancialBenefitsScreenState
    extends ConsumerState<FinancialBenefitsScreen> {
  Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await ref
          .read(financialRepositoryProvider)
          .getPreferences();
      if (mounted)
        setState(() => _selected = preferences.benefitPrograms.toSet());
    } catch (_) {
      // Default to no selections; saving still works.
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(financialRepositoryProvider)
          .setPreferences(benefitPrograms: _selected.toList(growable: false));
      ref.invalidate(financialPreferencesProvider);
      ref.invalidate(financialRulesProvider);
      if (mounted) {
        MortToast.show(context, 'Your benefits check preferences are saved.');
      }
    } catch (_) {
      if (mounted) {
        MortToast.show(
          context,
          'Your preferences could not be saved. Try again.',
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(financialRulesProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Benefits Check',
          subtitle:
              'Optional. Only you can see your selections, and participation '
              'is never required to use MORT.',
        ),
        const MortSafetyBanner(
          message:
              'MORT cannot determine your household eligibility for any '
              'program. MORT shows your records and the current official '
              'information for programs you choose to monitor.',
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Text(
            'Privacy: your benefit selections are never shown to job posters, '
            'businesses, other teens, or public profiles. They never affect '
            'job matching, ranking, or reviews.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        Wrap(
          spacing: MortSpacing.sm,
          runSpacing: MortSpacing.sm,
          children: [
            for (final entry
                in FinancialPreferences.benefitProgramChoices.entries)
              FilterChip(
                label: Text(entry.value),
                selected: _selected.contains(entry.key),
                onSelected: (selected) => setState(() {
                  selected
                      ? _selected.add(entry.key)
                      : _selected.remove(entry.key);
                }),
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save selections',
          busy: _saving,
          onPressed: _saving ? null : _save,
        ),
        const SizedBox(height: MortSpacing.md),
        rules.when(
          loading: () => const MortLoading(
            label: 'Loading program information...',
            fullScreen: false,
          ),
          error: (error, _) => const MortErrorState(
            title: 'Program information unavailable',
            message:
                "We can't verify the current rules right now. Review the "
                'official program information before making a financial '
                'decision.',
          ),
          data: (allRules) {
            final relevant = allRules
                .where((rule) => _selected.contains(rule.program))
                .toList(growable: false);
            if (relevant.isEmpty) {
              return const MortEmptyState(
                title: 'No programs selected',
                message:
                    'Select a program above and MORT will show the official '
                    'information it has for it.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final rule in relevant) ...[
                  _RuleCard(rule: rule),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A versioned rule rendered with CHECK RECOMMENDED language. Stale rules
/// fail closed: the threshold is never presented as current fact.
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});

  final FinancialRule rule;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: rule.isStale
          ? MortColors.warning.withValues(alpha: 0.10)
          : MortColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${rule.program} · ${rule.displayLabel}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MortBadge(
                label: rule.isStale ? 'RULE NEEDS REVIEW' : 'CHECK RECOMMENDED',
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.xs),
          if (rule.isStale)
            const Text(
              "We can't verify the current rule right now. Review the "
              'official program information before making a financial '
              'decision.',
            )
          else
            Text(
              'RULE MAY APPLY — earnings may matter for this program. MORT '
              'cannot determine eligibility.',
            ),
          if (rule.thresholdCents != null && !rule.isStale) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(
              'Tracked reference amount: ${formatUsdCents(rule.thresholdCents!)} '
              '(${rule.grossOrNetBasis ?? 'gross'})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: MortSpacing.xs),
          Text(rule.notes, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: MortSpacing.sm),
          MortSourceLink(
            label: 'Official source: ${rule.sourceAgency}',
            url: rule.sourceUrl,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PERSONAL TARGETS
// ---------------------------------------------------------------------------

/// Voluntary personal earning targets with 70/85/95/100 alerts. Always
/// labeled PERSONAL TARGET — never an IRS, government, or benefits threshold.
class FinancialTargetsScreen extends ConsumerStatefulWidget {
  const FinancialTargetsScreen({super.key});

  @override
  ConsumerState<FinancialTargetsScreen> createState() =>
      _FinancialTargetsScreenState();
}

class _FinancialTargetsScreenState
    extends ConsumerState<FinancialTargetsScreen> {
  late int _year = currentFinancialYear();
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _saveTarget({int? existingCents}) async {
    final cents = MortServiceFee.tryParseAdultAmount(_amount.text);
    if (cents == null || cents <= 0) {
      MortToast.show(context, 'Enter a valid target amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(financialRepositoryProvider)
          .upsertTarget(year: _year, amountCents: cents);
      _invalidateFinancialData(ref, _year);
      if (mounted) {
        MortToast.show(context, 'Your personal target for $_year is saved.');
      }
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'Your target could not be saved. Try again.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteTarget() async {
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Remove this personal target?',
      message: 'Alerts for this personal target will stop.',
      confirmLabel: 'Remove target',
    );
    if (!confirmed) return;
    try {
      await ref.read(financialRepositoryProvider).deleteTarget(_year);
      _invalidateFinancialData(ref, _year);
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'The target could not be removed. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(financialSummaryProvider(_year));
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Personal Targets',
          subtitle:
              'Voluntary goals for your own records. These are personal '
              'targets — not government thresholds.',
        ),
        FinancialYearSelector(
          selected: _year,
          onChanged: (year) => setState(() => _year = year),
        ),
        const SizedBox(height: MortSpacing.md),
        summary.when(
          loading: () => const MortLoading(
            label: 'Loading your target...',
            fullScreen: false,
          ),
          error: (error, _) => const MortErrorState(
            title: 'Targets unavailable',
            message: 'Your targets could not be loaded. Try again.',
          ),
          data: (data) {
            final target = data.personalTargets.isEmpty
                ? null
                : data.personalTargets.first;
            if (target == null) {
              return MortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERSONAL TARGET',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: MortSpacing.sm),
                    MortTextField(
                      label: 'Target amount for $_year (USD)',
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: MortSpacing.md),
                    MortButton(
                      label: 'Save target',
                      busy: _busy,
                      onPressed: _busy ? null : _saveTarget,
                    ),
                  ],
                ),
              );
            }
            final percent = percentOfThreshold(
              amountCents: data.grossTrackedCents,
              thresholdCents: target.amountCents,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              target.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const MortBadge(label: 'PERSONAL TARGET'),
                        ],
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      FinancialMoneyRow(
                        label: 'Gross tracked',
                        cents: data.grossTrackedCents,
                      ),
                      FinancialMoneyRow(
                        label: 'Personal target',
                        cents: target.amountCents,
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      Semantics(
                        label: '$percent percent of your personal target',
                        child: MortProgressBar(value: percent / 100),
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      Text(
                        '$percent% of your personal target',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      Text(
                        'This is your own goal — not an IRS threshold, a '
                        'government threshold, or a benefits limit. Reaching '
                        'it never blocks your work.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.md),
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alert points',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      const Text(
                        '70% HEADS UP · 85% FINANCIAL CHECK · 95% REVIEW '
                        'RECOMMENDED · 100% THRESHOLD REACHED',
                      ),
                      const SizedBox(height: MortSpacing.xs),
                      const Text(
                        'Alerts are informational and never block or limit '
                        'your ability to keep working.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.md),
                MortTextField(
                  label: 'Change target amount (USD)',
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Update target',
                  busy: _busy,
                  onPressed: _busy ? null : _saveTarget,
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Remove target',
                  style: MortButtonStyle.secondary,
                  onPressed: _deleteTarget,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// RECORDS & EXPORTS
// ---------------------------------------------------------------------------

/// Records & exports: CSV + PDF annual records. Never imitates official IRS
/// forms and never labeled a tax return.
class FinancialRecordsScreen extends ConsumerWidget {
  const FinancialRecordsScreen({super.key});

  Future<void> _export(
    WidgetRef ref,
    BuildContext context, {
    required int year,
    required _ExportKind kind,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await ref.read(financialYearReportProvider(year).future);
      switch (kind) {
        case _ExportKind.pdfEarnings:
          final bytes = await FinancialExportService.buildEarningsSummaryPdf(
            report,
          );
          await FinancialExportService.sharePdfBytes(
            bytes,
            fileName: 'mort-earnings-summary-$year.pdf',
          );
        case _ExportKind.csvEarnings:
          await FinancialExportService.shareTextFile(
            FinancialExportService.buildEarningsCsv(report),
            fileName: 'mort-earnings-$year.csv',
          );
        case _ExportKind.csvExpenses:
          await FinancialExportService.shareTextFile(
            FinancialExportService.buildExpensesCsv(report),
            fileName: 'mort-expenses-$year.csv',
          );
        case _ExportKind.csvReceipts:
          await FinancialExportService.shareTextFile(
            FinancialExportService.buildReceiptIndexCsv(report),
            fileName: 'mort-receipt-index-$year.csv',
          );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The export could not be created. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = currentFinancialYear();
    final report = ref.watch(financialYearReportProvider(year));
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Records & Exports',
          subtitle:
              'Your annual records, ready to share with your family or a '
              'professional.',
        ),
        const MortSafetyBanner(
          message:
              'These exports are records only. They are not tax returns and '
              'not official IRS forms.',
        ),
        const SizedBox(height: MortSpacing.md),
        report.maybeWhen(
          data: (data) => MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year records',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MortSpacing.sm),
                FinancialMoneyRow(
                  label: 'Gross tracked',
                  cents: data.earningsTotalCents,
                ),
                FinancialMoneyRow(
                  label: 'Recorded expenses',
                  cents: data.expensesTotalCents,
                ),
                FinancialMoneyRow(
                  label: 'Estimated net',
                  cents: data.estimatedNetCents,
                ),
                FinancialCountRow(label: 'Receipts', count: data.receiptsCount),
              ],
            ),
          ),
          orElse: () =>
              const MortLoading(label: 'Loading records...', fullScreen: false),
        ),
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'PDF earnings summary',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () => _export(
                ref,
                context,
                year: year,
                kind: _ExportKind.pdfEarnings,
              ),
            ),
            MortAction(
              label: 'CSV earnings report',
              icon: Icons.table_chart_outlined,
              onPressed: () => _export(
                ref,
                context,
                year: year,
                kind: _ExportKind.csvEarnings,
              ),
            ),
            MortAction(
              label: 'CSV expense report',
              icon: Icons.receipt_long_outlined,
              onPressed: () => _export(
                ref,
                context,
                year: year,
                kind: _ExportKind.csvExpenses,
              ),
            ),
            MortAction(
              label: 'Receipt index',
              icon: Icons.inventory_2_outlined,
              onPressed: () => _export(
                ref,
                context,
                year: year,
                kind: _ExportKind.csvReceipts,
              ),
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        Text(
          FinancialExportService.earningsDisclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

enum _ExportKind { pdfEarnings, csvEarnings, csvExpenses, csvReceipts }

// ---------------------------------------------------------------------------
// LEARN / OFFICIAL RESOURCES
// ---------------------------------------------------------------------------

/// Learn: neutral education about tracking, records, and official resources.
/// Includes the no-evasion statement and neutral teen/custodial account
/// education. Never recommends a specific bank or promises tax outcomes.
class FinancialLearnScreen extends ConsumerWidget {
  const FinancialLearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(financialRulesProvider);
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Earnings safety',
          title: 'Learn',
          subtitle:
              'How earnings tracking works, and where the official '
              'information lives.',
        ),
        const MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How tracking works'),
              SizedBox(height: MortSpacing.xs),
              Text(
                'Your earnings come from your completed jobs. Cash, external '
                'electronic payments, and any future processed payouts all '
                'count toward the same tracked total. Changing payment '
                'method never resets your earnings.',
              ),
              SizedBox(height: MortSpacing.sm),
              Text('Expenses and receipts'),
              SizedBox(height: MortSpacing.xs),
              Text(
                'Recorded expenses and receipt photos stay private to you. '
                'They are recorded expenses and potential business expenses '
                '— MORT does not decide whether they are deductible.',
              ),
              SizedBox(height: MortSpacing.sm),
              Text('What MORT never does'),
              SizedBox(height: MortSpacing.xs),
              Text(
                'MORT never helps hide income, avoid reporting, or structure '
                'payments to evade thresholds. MORT does not calculate your '
                'taxes or determine benefits eligibility.',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accounts and guardians'),
              SizedBox(height: MortSpacing.xs),
              Text(
                'Teen checking accounts, custodial accounts, and '
                'guardian-managed accounts each work differently. MORT does '
                'not recommend a specific bank, and no account type makes '
                'income tax-free. A linked guardian can see your financial '
                'summary only if you turn that on.',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        rules.when(
          loading: () => const MortLoading(
            label: 'Loading official resources...',
            fullScreen: false,
          ),
          error: (error, _) => const MortErrorState(
            title: 'Resources unavailable',
            message:
                "We can't verify the current rules right now. Review the "
                'official program information before making a financial '
                'decision.',
          ),
          data: (allRules) {
            final sources = <String, String>{};
            for (final rule in allRules) {
              sources.putIfAbsent(rule.sourceUrl, () => rule.sourceAgency);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MortSectionTitle(title: 'Official resources'),
                for (final entry in sources.entries) ...[
                  MortCard(
                    child: MortSourceLink(label: entry.value, url: entry.key),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const MortGuideEntryButton(),
      ],
    );
  }
}
