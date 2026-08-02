import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/stripe_marketplace_repository.dart';
import 'stripe_payment_sheet_service.dart';

class StripePayoutSetupScreen extends ConsumerStatefulWidget {
  const StripePayoutSetupScreen({super.key});

  @override
  ConsumerState<StripePayoutSetupScreen> createState() =>
      _StripePayoutSetupScreenState();
}

class _StripePayoutSetupScreenState
    extends ConsumerState<StripePayoutSetupScreen> {
  late Future<Map<String, dynamic>> _load;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future.wait([
      ref.read(stripeMarketplaceRepositoryProvider).runtimeStatus(),
      ref.read(stripeMarketplaceRepositoryProvider).payoutStatus(),
    ]).then((values) => {'runtime': values[0], 'payout': values[1]});
  }

  Future<void> _startOnboarding() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final repository = ref.read(stripeMarketplaceRepositoryProvider);
      await repository.createConnectedAccount();
      final origin = AppConfig.publicWebOrigin;
      final link = await repository.createOnboardingLink(
        returnUrl: '$origin/stripe/onboarding-return',
        refreshUrl: '$origin/stripe/onboarding-refresh',
      );
      final uri = safeStripeConnectUri(
        link['onboarding_url']?.toString() ?? '',
      );
      if (uri == null) {
        throw StateError('Invalid Stripe onboarding URL.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open Stripe onboarding.');
      _notice =
          'Stripe onboarding opened in your browser. Return here and refresh status after finishing.';
    } catch (error) {
      _notice = userFacingError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _synchronize() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await ref
          .read(stripeMarketplaceRepositoryProvider)
          .synchronizePayoutStatus();
      setState(_reload);
    } catch (error) {
      _notice = userFacingError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Teen earnings',
          title: 'Stripe payout setup',
          subtitle:
              'Stripe-hosted onboarding handles payout details and any provider-required guardian steps. MORT does not collect bank credentials or Stripe identity documents.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Payout status unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final runtime = snapshot.data?['runtime'] as Map<String, dynamic>;
            final payout = snapshot.data?['payout'] as Map<String, dynamic>;
            final enabled = runtime['connected_onboarding_enabled'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MortBadge(
                        label: _label(payout['status'] ?? 'not_started'),
                        color: payout['payouts_enabled'] == true
                            ? MortColors.neon
                            : MortColors.warning,
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      Text(
                        payout['payouts_enabled'] == true
                            ? 'Stripe reports this payout account can receive payouts.'
                            : enabled
                            ? 'Finish the Stripe-hosted requirements before a transfer can be requested.'
                            : 'Sandbox onboarding is currently off. No payout account can be created.',
                      ),
                      if (payout['guardian_requirement_status'] != null)
                        Text(
                          'Provider guardian status: ${_label(payout['guardian_requirement_status'])}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Open Stripe-hosted onboarding',
                  icon: Icons.open_in_new,
                  onPressed: enabled && !_busy ? _startOnboarding : null,
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Refresh payout status',
                  icon: Icons.refresh,
                  style: MortButtonStyle.secondary,
                  onPressed: enabled && !_busy ? _synchronize : null,
                ),
                if (_notice != null) ...[
                  const SizedBox(height: MortSpacing.sm),
                  MortCard(color: MortColors.cardAlt, child: Text(_notice!)),
                ],
                const SizedBox(height: MortSpacing.sm),
                const MortSafetyBanner(
                  message:
                      'Guardian Mode in MORT is optional and separate from any guardian or age requirement Stripe may apply to a payout account.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class StripeJobFundingScreen extends ConsumerStatefulWidget {
  const StripeJobFundingScreen({super.key, required this.contractId});

  final String contractId;

  @override
  ConsumerState<StripeJobFundingScreen> createState() =>
      _StripeJobFundingScreenState();
}

class _StripeJobFundingScreenState
    extends ConsumerState<StripeJobFundingScreen> {
  late Future<Map<String, dynamic>> _load;
  bool _busy = false;
  bool _savePaymentMethod = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future.wait([
      ref
          .read(stripeMarketplaceRepositoryProvider)
          .fundingPreview(widget.contractId),
      ref
          .read(stripeMarketplaceRepositoryProvider)
          .paymentSummary(widget.contractId),
    ]).then((values) => {'preview': values[0], 'summary': values[1]});
  }

  Future<void> _fund() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final repository = ref.read(stripeMarketplaceRepositoryProvider);
      if (_savePaymentMethod) {
        await repository.recordSavedPaymentConsent(widget.contractId);
      }
      final initialization = await repository.createPaymentSheet(
        contractId: widget.contractId,
        savePaymentMethod: _savePaymentMethod,
        savedPaymentConsentVersion: _savePaymentMethod
            ? StripeMarketplaceRepository.savedPaymentConsentVersion
            : null,
      );
      final completed = await const StripePaymentSheetService().present(
        initialization,
      );
      _notice = completed
          ? 'Payment Sheet finished. MORT is waiting for Stripe webhook confirmation before showing this job as funded.'
          : 'Payment Sheet was canceled. No funded status was recorded by the app.';
      setState(_reload);
    } catch (error) {
      _notice = userFacingError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Real-world job payment',
          title: 'Review job funding',
          subtitle:
              'Stripe processes the charge. The accepted MORT contract controls the amount; the phone cannot change it.',
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Funding preview unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final preview = snapshot.data?['preview'] as Map<String, dynamic>;
            final summary = snapshot.data?['summary'] as Map<String, dynamic>;
            final fundingEnabled = preview['funding_enabled'] == true;
            final nativeSupported =
                AppConfig.supportsStripePaymentSheet && !kIsWeb;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoneyRow(
                        label: 'Agreed job earnings',
                        cents: preview['earnings_amount_cents'],
                        currency: preview['currency_code'],
                      ),
                      _MoneyRow(
                        label: 'MORT service fee',
                        cents: preview['service_fee_cents'],
                        currency: preview['currency_code'],
                      ),
                      const Divider(),
                      _MoneyRow(
                        label: 'Total adult charge',
                        cents: preview['total_amount_cents'],
                        currency: preview['currency_code'],
                        emphasize: true,
                      ),
                      _MoneyRow(
                        label: 'Expected teen transfer',
                        cents: preview['expected_teen_transfer_cents'],
                        currency: preview['currency_code'],
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      MortBadge(
                        label:
                            'Funding: ${_label(summary['funding_status'] ?? 'unfunded')}',
                        color: summary['funding_status'] == 'funded'
                            ? MortColors.neon
                            : MortColors.warning,
                      ),
                    ],
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _savePaymentMethod,
                  onChanged: fundingEnabled && nativeSupported && !_busy
                      ? (value) => setState(() => _savePaymentMethod = value)
                      : null,
                  title: const Text('Save payment method'),
                  subtitle: const Text(
                    'Save this payment method for faster funding of future MORT jobs that you choose to confirm. It will not authorize a new charge based only on a review decision.',
                  ),
                ),
                MortButton(
                  label: 'Open Stripe Payment Sheet',
                  icon: Icons.lock_outline,
                  onPressed: fundingEnabled && nativeSupported && !_busy
                      ? _fund
                      : null,
                ),
                if (!nativeSupported)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.sm),
                    child: Text(
                      'This build does not include Stripe Payment Sheet. No job funding can start from this app.',
                    ),
                  ),
                if (!fundingEnabled)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.sm),
                    child: Text(
                      'Stripe job funding is off at the server. No live or sandbox charge can start.',
                    ),
                  ),
                if (_notice != null) ...[
                  const SizedBox(height: MortSpacing.sm),
                  MortCard(color: MortColors.cardAlt, child: Text(_notice!)),
                ],
                const SizedBox(height: MortSpacing.sm),
                const MortSafetyBanner(
                  message:
                      'MORT is not a bank or licensed escrow provider. Transfers, refunds, disputes, and payout timing depend on Stripe, the accepted agreement, and authorized review.',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.cents,
    required this.currency,
    this.emphasize = false,
  });

  final String label;
  final Object? cents;
  final Object? currency;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final amount = cents is num ? (cents as num).toDouble() / 100 : 0.0;
    final code = currency?.toString() ?? 'USD';
    final value = NumberFormat.simpleCurrency(name: code).format(amount);
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

String _label(Object? value) => value
    .toString()
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
