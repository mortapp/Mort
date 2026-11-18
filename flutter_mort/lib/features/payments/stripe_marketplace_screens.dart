import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/stripe_payment_models.dart';
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
      if (!mounted) return;
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
                            ? MortColors.accent
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
  MortFundingQuote? _pendingQuote;
  String? _paymentRequestId;
  String? _providerPaymentIntentId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future.wait([
      ref.read(stripeMarketplaceRepositoryProvider).runtimeStatus(),
      ref
          .read(stripeMarketplaceRepositoryProvider)
          .paymentSummary(widget.contractId),
    ]).then((values) => {'runtime': values[0], 'summary': values[1]});
  }

  Future<void> _requestQuote() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final repository = ref.read(stripeMarketplaceRepositoryProvider);
      if (_providerPaymentIntentId != null) {
        _notice =
            'A previous payment is awaiting status verification. Refresh payment status before requesting a new quote.';
        return;
      }
      final quote = await repository.createFundingQuote(
        contractId: widget.contractId,
      );
      if (quote.state != 'ACTIVE' ||
          quote.totalCents != quote.basePayCents + quote.serviceFeeCents) {
        throw MortCodedError(
          'funding_quote_invalid',
          'The server could not verify this funding quote. No payment was started.',
        );
      }
      _pendingQuote = quote;
      _paymentRequestId = null;
      _notice = quote.paymentEligibility
          ? 'Review the server-generated amount and fee below. No charge has been started.'
          : 'This quote is not payable until the recipient account is verified and approved. No charge has been started.';
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _notice = userFacingError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fund() async {
    if (_busy) return;
    final quote = _pendingQuote;
    if (quote == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final repository = ref.read(stripeMarketplaceRepositoryProvider);
      if (_providerPaymentIntentId != null) {
        final prior = await repository.refreshPaymentStatus(
          _providerPaymentIntentId!,
        );
        final priorState = prior['state']
            ?.toString()
            .replaceAll('_', '')
            .toUpperCase();
        if (priorState == 'SUCCEEDED') {
          _pendingQuote = null;
          _paymentRequestId = null;
          _providerPaymentIntentId = null;
          _notice = 'Payment confirmed by MORT. This job is funded.';
          if (mounted) setState(_reload);
          return;
        }
        if (priorState == 'CANCELED' ||
            priorState == 'CANCELLED' ||
            priorState == 'FAILED') {
          _pendingQuote = null;
          _paymentRequestId = null;
          _providerPaymentIntentId = null;
          _notice =
              'The prior payment attempt ended without a confirmed charge. Request a fresh quote before trying again.';
          return;
        }
        if (priorState != 'REQUIRESPAYMENTMETHOD' && priorState != 'DECLINED') {
          _notice =
              'MORT is still verifying this payment. Refresh its status before attempting another payment.';
          return;
        }
      }
      if (!quote.expiresAt.isAfter(DateTime.now().toUtc())) {
        _pendingQuote = null;
        _paymentRequestId = null;
        _providerPaymentIntentId = null;
        _notice =
            'This quote expired. Request a new quote and review its amount before paying.';
        return;
      }
      if (quote.state != 'ACTIVE' ||
          quote.totalCents != quote.basePayCents + quote.serviceFeeCents) {
        throw MortCodedError(
          'funding_quote_invalid',
          'The server could not verify this funding quote. No payment was started.',
        );
      }
      if (!quote.paymentEligibility) {
        _notice =
            'Payment is blocked until the recipient account is verified and approved. No charge was started.';
        return;
      }
      if (_savePaymentMethod) {
        await repository.recordSavedPaymentConsent(widget.contractId);
      }
      _paymentRequestId ??= const Uuid().v4();
      final initialization = await repository.createPaymentSheet(
        quoteId: quote.quoteId,
        requestId: _paymentRequestId!,
        savePaymentMethod: _savePaymentMethod,
        savedPaymentConsentVersion: _savePaymentMethod
            ? StripeMarketplaceRepository.savedPaymentConsentVersion
            : null,
      );
      final paymentIntentId =
          initialization['provider_payment_intent_id'] ??
          initialization['payment_intent_id'];
      if (paymentIntentId is! String || !paymentIntentId.startsWith('pi_')) {
        throw MortCodedError(
          'payment_intent_reference_invalid',
          'The payment service did not return a verifiable payment reference. No payment was confirmed.',
        );
      }
      _providerPaymentIntentId = paymentIntentId;

      final completed = await const StripePaymentSheetService().present(
        initialization,
      );
      final state = await repository.refreshPaymentStatus(paymentIntentId);
      if (!mounted) return;
      final normalizedState = state['state']
          ?.toString()
          .replaceAll('_', '')
          .toUpperCase();
      if (normalizedState == 'SUCCEEDED') {
        _pendingQuote = null;
        _paymentRequestId = null;
        _providerPaymentIntentId = null;
        _notice = 'Payment confirmed by MORT. This job is funded.';
        _reload();
      } else if (!completed && normalizedState == 'REQUIRESPAYMENTMETHOD') {
        _notice =
            'Payment Sheet was canceled. No funded status was recorded; you can retry this same payment safely.';
      } else {
        _notice =
            'MORT is waiting for verified provider confirmation before showing this job as funded.';
      }
    } catch (error) {
      if (!mounted) return;
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
            final runtime = snapshot.data?['runtime'] as Map<String, dynamic>;
            final summary = snapshot.data?['summary'] as Map<String, dynamic>;
            final quote = _pendingQuote;
            final fundingEnabled =
                runtime['payments_enabled'] == true &&
                runtime['job_funding_enabled'] == true;
            final nativeSupported =
                AppConfig.supportsStripePaymentSheet && !kIsWeb;
            final alreadyFunded = summary['funding_status'] == 'funded';
            final canContinue =
                fundingEnabled &&
                nativeSupported &&
                !alreadyFunded &&
                !_busy &&
                (quote == null || quote.paymentEligibility);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (quote == null)
                        const Text(
                          'Request a server-generated quote to review the exact agreed gig amount and fixed service fee. No charge begins while you review it.',
                        ),
                      if (quote != null) ...[
                        _MoneyRow(
                          label: 'Agreed gig amount',
                          cents: quote.basePayCents,
                          currency: quote.currencyCode,
                        ),
                        _MoneyRow(
                          label: 'MORT fixed service fee',
                          cents: quote.serviceFeeCents,
                          currency: quote.currencyCode,
                        ),
                        const Divider(),
                        _MoneyRow(
                          label: 'Total adult charge',
                          cents: quote.totalCents,
                          currency: quote.currencyCode,
                          emphasize: true,
                        ),
                        Text(
                          'Quote expires ${DateFormat.yMMMd().add_jm().format(quote.expiresAt.toLocal())}.',
                        ),
                      ],
                      const SizedBox(height: MortSpacing.sm),
                      MortBadge(
                        label:
                            'Funding: ${_label(summary['funding_status'] ?? 'unfunded')}',
                        color: summary['funding_status'] == 'funded'
                            ? MortColors.accent
                            : MortColors.warning,
                      ),
                    ],
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _savePaymentMethod,
                  onChanged:
                      fundingEnabled &&
                          nativeSupported &&
                          !_busy &&
                          quote == null &&
                          !alreadyFunded
                      ? (value) => setState(() => _savePaymentMethod = value)
                      : null,
                  title: const Text('Save payment method'),
                  subtitle: const Text(
                    'Save this payment method for faster funding of future MORT jobs that you choose to confirm. It will not authorize a new charge based only on a review decision.',
                  ),
                ),
                MortButton(
                  label: quote == null
                      ? 'Get server-generated quote'
                      : 'Confirm amount and continue to Stripe',
                  icon: Icons.lock_outline,
                  onPressed: canContinue
                      ? quote == null
                            ? _requestQuote
                            : _fund
                      : null,
                ),
                if (alreadyFunded)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.sm),
                    child: Text(
                      'MORT already reports this agreement as funded. No additional charge can be started here.',
                    ),
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
                if (quote != null && !quote.paymentEligibility)
                  const Padding(
                    padding: EdgeInsets.only(top: MortSpacing.sm),
                    child: Text(
                      'Funding is blocked until the approved recipient account is ready. No payment can be started from this quote.',
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
