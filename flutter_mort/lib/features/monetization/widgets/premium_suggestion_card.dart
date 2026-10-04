import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/observability/product_analytics.dart';
import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../domain/premium_suggestion.dart';
import '../providers/premium_suggestion_providers.dart';

class PremiumSuggestionCard extends ConsumerStatefulWidget {
  const PremiumSuggestionCard({
    super.key,
    required this.userId,
    required this.suggestion,
    this.isSafetyCriticalSurface = false,
  });

  final String userId;
  final PremiumSuggestion suggestion;
  final bool isSafetyCriticalSurface;

  @override
  ConsumerState<PremiumSuggestionCard> createState() =>
      _PremiumSuggestionCardState();
}

class _PremiumSuggestionCardState extends ConsumerState<PremiumSuggestionCard> {
  bool _visible = false;
  bool _evaluationScheduled = false;
  String? _evaluatedFreeUserId;
  String? _lastEligibilityKey;

  @override
  void didUpdateWidget(covariant PremiumSuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.suggestion.id != widget.suggestion.id ||
        oldWidget.isSafetyCriticalSurface != widget.isSafetyCriticalSurface) {
      _visible = false;
      _evaluatedFreeUserId = null;
      _lastEligibilityKey = null;
    }
  }

  void _scheduleEvaluation(PremiumMarketingEligibility eligibility) {
    final userId = widget.userId;
    final suggestionId = widget.suggestion.id;
    final key =
        '$userId:$suggestionId:${widget.isSafetyCriticalSurface}:${eligibility.name}';
    if (_lastEligibilityKey == key || _evaluationScheduled) return;
    _lastEligibilityKey = key;
    _evaluationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _evaluationScheduled = false;
      if (!mounted) return;
      final currentEligibility = ref.read(premiumMarketingEligibilityProvider);
      if (widget.userId != userId ||
          widget.suggestion.id != suggestionId ||
          currentEligibility != eligibility) {
        _lastEligibilityKey = null;
        _scheduleEvaluation(currentEligibility);
        return;
      }
      if (eligibility != PremiumMarketingEligibility.free) {
        if (eligibility == PremiumMarketingEligibility.subscriber) {
          _evaluatedFreeUserId = null;
        }
        if (_visible) setState(() => _visible = false);
        return;
      }
      if (_evaluatedFreeUserId == widget.userId) return;
      await _evaluateFreeUser();
    });
  }

  Future<void> _evaluateFreeUser() async {
    final evaluatedUserId = widget.userId;
    _evaluatedFreeUserId = evaluatedUserId;
    final engine = ref.read(premiumSuggestionEngineProvider);
    bool show;
    try {
      show = await engine.claimImpression(
        userId: evaluatedUserId,
        suggestion: widget.suggestion,
        isSubscriber: false,
        isSafetyCriticalSurface: widget.isSafetyCriticalSurface,
      );
    } catch (_) {
      // Local frequency history is optional; storage errors suppress marketing.
      return;
    }
    if (!mounted ||
        widget.userId != evaluatedUserId ||
        widget.isSafetyCriticalSurface) {
      return;
    }
    if (ref.read(premiumMarketingEligibilityProvider) !=
        PremiumMarketingEligibility.free) {
      return;
    }
    setState(() => _visible = show);
    if (show) {
      unawaited(
        MortProductAnalytics.instance.record(
          eventName: 'premium_suggestion_impression',
          surface: widget.suggestion.surface.name,
          outcome: 'displayed',
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    await ref
        .read(premiumSuggestionEngineProvider)
        .recordDismissal(widget.userId, widget.suggestion);
    unawaited(
      MortProductAnalytics.instance.record(
        eventName: 'premium_suggestion_dismissed',
        surface: widget.suggestion.surface.name,
        outcome: 'dismissed',
      ),
    );
    if (mounted) setState(() => _visible = false);
  }

  void _open() {
    unawaited(
      MortProductAnalytics.instance.record(
        eventName: 'premium_suggestion_clicked',
        surface: widget.suggestion.surface.name,
        outcome: 'clicked',
      ),
    );
    context.push('/monetization/paywall');
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = ref.watch(premiumMarketingEligibilityProvider);
    _scheduleEvaluation(eligibility);
    if (eligibility != PremiumMarketingEligibility.free || !_visible) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      label: 'Optional MORT Pro benefit',
      child: MortGlassSoftSurface(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: MortColors.lightBlue,
            ),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.suggestion.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  Text(widget.suggestion.message),
                  const SizedBox(height: MortSpacing.xs),
                  TextButton(
                    onPressed: _open,
                    child: Text(widget.suggestion.cta),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss premium suggestion',
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
