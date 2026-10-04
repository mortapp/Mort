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
import '../providers/revenuecat_providers.dart';

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
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  Future<void> _evaluate() async {
    final isSubscriber = await ref
        .read(isMortProProvider.future)
        .catchError((_) => false);
    final engine = ref.read(premiumSuggestionEngineProvider);
    final show = await engine.shouldShow(
      userId: widget.userId,
      suggestion: widget.suggestion,
      isSubscriber: isSubscriber,
      isSafetyCriticalSurface: widget.isSafetyCriticalSurface,
    );
    if (!mounted) return;
    setState(() {
      _checked = true;
      _visible = show;
    });
    if (show) {
      await engine.recordImpression(widget.userId, widget.suggestion);
      unawaited(
        MortProductAnalytics.instance.record(
          eventName: 'premium_suggestion_impression',
          surface: widget.suggestion.surface.name,
          outcome: widget.suggestion.id,
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
        outcome: widget.suggestion.id,
      ),
    );
    if (mounted) setState(() => _visible = false);
  }

  void _open() {
    unawaited(
      MortProductAnalytics.instance.record(
        eventName: 'premium_suggestion_clicked',
        surface: widget.suggestion.surface.name,
        outcome: widget.suggestion.id,
      ),
    );
    context.push('/monetization/paywall');
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_visible) return const SizedBox.shrink();
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
