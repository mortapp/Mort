import 'package:flutter/material.dart';

import '../../../core/theme/mort_colors.dart';

/// Presentation data only. Prices are supplied by the current RevenueCat offering.
class MortProPlan {
  const MortProPlan({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final String price;

  bool get isLifetime => id == r'$rc_lifetime';
  bool get isAnnual => id == r'$rc_annual';

  String get detail => isLifetime
      ? 'One-time purchase. No renewal.'
      : 'Renews at $price/${switch (id) {
          r'$rc_weekly' => 'wk',
          r'$rc_monthly' => 'mo',
          _ => 'yr',
        }} until canceled.';
}

class MortProPaywallContent extends StatefulWidget {
  const MortProPaywallContent({
    super.key,
    required this.plans,
    required this.loading,
    required this.busy,
    required this.onPurchase,
    required this.onRestore,
    required this.onRetry,
    required this.onClose,
    required this.onTerms,
    required this.onPrivacy,
    this.isPro = false,
    this.isTeen = false,
    this.message,
  });

  final List<MortProPlan> plans;
  final bool loading;
  final bool busy;
  final bool isPro;
  final bool isTeen;
  final String? message;
  final ValueChanged<String> onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<MortProPaywallContent> createState() => _MortProPaywallContentState();
}

class _MortProPaywallContentState extends State<MortProPaywallContent> {
  String? _selectedId;

  MortProPlan? get _selected {
    if (widget.plans.isEmpty) return null;
    for (final plan in widget.plans) {
      if (plan.id == _selectedId) return plan;
    }
    for (final plan in widget.plans) {
      if (plan.isAnnual) return plan;
    }
    return widget.plans.first;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return ColoredBox(
      color: MortColors.ink2,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close MORT Pro',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 22),
                      style: IconButton.styleFrom(
                        foregroundColor: MortColors.silverBright,
                        backgroundColor: MortColors.graphite3,
                        side: const BorderSide(color: MortColors.borderSilver),
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: MortColors.graphite2,
                        border: Border.all(color: MortColors.silverDark),
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: const [
                          BoxShadow(color: Color(0x151A5A9A), blurRadius: 18),
                        ],
                      ),
                      child: const Center(
                        child: CustomPaint(
                          size: Size(38, 38),
                          painter: _CrownPainter(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 19),
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'MORT ',
                          style: TextStyle(color: MortColors.white),
                        ),
                        TextSpan(
                          text: 'Pro',
                          style: TextStyle(color: MortColors.silverBright),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Optional convenience and style.\nCore work and safety stay free.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MortColors.textSecondary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _BenefitsPanel(
                    stack:
                        textScale > 1.4 ||
                        MediaQuery.sizeOf(context).width < 350,
                  ),
                  if (widget.isTeen) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Ask your guardian before making purchases.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MortColors.silver, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (widget.isPro)
                    const _StateMessage('MORT Pro is active on this account.')
                  else if (widget.loading)
                    const _StateMessage('Loading plans…')
                  else if (widget.plans.isEmpty) ...[
                    _StateMessage(
                      widget.message ??
                          'MORT Pro plans are unavailable right now.',
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: widget.onRetry,
                      style: TextButton.styleFrom(
                        foregroundColor: MortColors.silverBright,
                      ),
                      child: const Text('Try again'),
                    ),
                  ] else ...[
                    for (final plan in widget.plans) ...[
                      _PlanCard(
                        plan: plan,
                        selected: selected?.id == plan.id,
                        enabled: !widget.busy,
                        onTap: () => setState(() => _selectedId = plan.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 60),
                      child: FilledButton(
                        key: const Key('pro-continue'),
                        onPressed: widget.busy || selected == null
                            ? null
                            : () => widget.onPurchase(selected.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: MortColors.ice1,
                          foregroundColor: MortColors.ink2,
                          disabledBackgroundColor: MortColors.graphite4,
                          disabledForegroundColor: MortColors.silverDark,
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                        child: widget.busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MortColors.silver,
                                ),
                              )
                            : Text(
                                selected!.isLifetime
                                    ? 'Unlock Lifetime'
                                    : 'Continue with ${selected.name}',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                  if (widget.message != null && widget.plans.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _StateMessage(widget.message!),
                  ],
                  const SizedBox(height: 19),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: [
                      TextButton(
                        onPressed: widget.busy ? null : widget.onRestore,
                        style: TextButton.styleFrom(
                          foregroundColor: MortColors.textSecondary,
                        ),
                        child: const Text('Restore Purchases'),
                      ),
                      const Text(
                        '·',
                        style: TextStyle(color: MortColors.silverDark),
                      ),
                      TextButton(
                        onPressed: widget.onTerms,
                        style: TextButton.styleFrom(
                          foregroundColor: MortColors.textSecondary,
                        ),
                        child: const Text('Terms'),
                      ),
                      const Text(
                        '·',
                        style: TextStyle(color: MortColors.silverDark),
                      ),
                      TextButton(
                        onPressed: widget.onPrivacy,
                        style: TextButton.styleFrom(
                          foregroundColor: MortColors.textSecondary,
                        ),
                        child: const Text('Privacy'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Applying, messaging, reporting, blocking, Safety Ping, and basic Guardian Mode remain free.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MortColors.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: MortColors.textSecondary),
    ),
  );
}

class _BenefitsPanel extends StatelessWidget {
  const _BenefitsPanel({required this.stack});
  final bool stack;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.visibility_off_outlined,
        'Ad-free eligible browsing',
        'Hide supported display ads while Pro is active.',
      ),
      (
        Icons.brush_outlined,
        'Profile style',
        'Personalize your profile appearance.',
      ),
      (
        Icons.bar_chart_rounded,
        'Personal analytics',
        'See your own activity insights.',
      ),
    ];
    Widget benefit((IconData, String, String) item) => Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: MortColors.graphite4,
            child: Icon(item.$1, color: MortColors.ice1, size: 20),
          ),
          const SizedBox(height: 9),
          Text(
            item.$2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MortColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.$3,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MortColors.textSecondary,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: MortColors.graphite2,
        border: Border.all(color: MortColors.borderSilver),
        borderRadius: BorderRadius.circular(20),
      ),
      child: stack
          ? Column(children: [for (final item in items) benefit(item)])
          : IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: MortColors.borderStrong,
                      ),
                    Expanded(child: benefit(items[i])),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final MortProPlan plan;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? MortColors.ink2 : MortColors.white;
    final secondary = selected
        ? MortColors.graphite4
        : MortColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${plan.name} plan, ${plan.price}, ${plan.detail}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('plan-${plan.id}'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            constraints: const BoxConstraints(minHeight: 90),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [MortColors.ice2, MortColors.silverBright],
                    )
                  : null,
              color: selected ? null : MortColors.graphite2,
              border: Border.all(
                color: selected
                    ? MortColors.paymentInfoSoft
                    : MortColors.borderSilver,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: selected ? MortColors.silver : MortColors.graphite4,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    plan.isLifetime
                        ? Icons.all_inclusive_rounded
                        : Icons.calendar_month_outlined,
                    color: foreground,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (plan.isAnnual) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? MortColors.paymentInfoSoft
                                    : MortColors.graphite4,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Best value',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? MortColors.ink2
                                      : MortColors.silverBright,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.price,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.detail,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? MortColors.paymentInfoDeep
                      : MortColors.silverDark,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 38, size.height / 38);
    final paint = Paint()
      ..color = MortColors.ice1
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(5, 12)
        ..lineTo(9, 27)
        ..lineTo(29, 27)
        ..lineTo(33, 12)
        ..lineTo(25, 19)
        ..lineTo(19, 8)
        ..lineTo(13, 19)
        ..close(),
      paint,
    );
    canvas.drawLine(const Offset(9, 31), const Offset(29, 31), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
