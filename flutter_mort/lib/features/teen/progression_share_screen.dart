import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/progression.dart';
import '../../data/repositories/providers.dart';
import 'teen_shell.dart';

class ProgressionShareScreen extends ConsumerStatefulWidget {
  const ProgressionShareScreen({super.key});

  @override
  ConsumerState<ProgressionShareScreen> createState() =>
      _ProgressionShareScreenState();
}

class _ProgressionShareScreenState
    extends ConsumerState<ProgressionShareScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Milestone card is not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not render milestone card.');
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'mort-milestone.png',
            ),
          ],
          text: 'GET IN MOTION · MORT',
        ),
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progression = ref.watch(myProgressionProvider);
    return MortScreen(
      children: [
        const MortTeenDestinationHeader(
          eyebrow: 'YOUR MILESTONE',
          title: 'Share the motion',
          subtitle: 'Your card includes only your MORT rank and level.',
        ),
        const SizedBox(height: MortSpacing.md),
        progression.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Milestone unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(myProgressionProvider),
            ),
          ),
          data: (snapshot) => snapshot.xpTotal == 0
              ? const MortEmptyState(
                  title: 'First milestone ahead',
                  message: 'Complete a legitimate job to create a share card.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RepaintBoundary(
                      key: _cardKey,
                      child: _MilestoneCard(snapshot: snapshot),
                    ),
                    const SizedBox(height: MortSpacing.md),
                    MortButton(
                      label: _sharing ? 'Preparing card…' : 'Share image',
                      icon: Icons.ios_share_outlined,
                      onPressed: _sharing ? null : _share,
                    ),
                    const SizedBox(height: MortSpacing.sm),
                    Text(
                      'Your username, age, school, earnings, job details, and location are excluded.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.snapshot});
  final ProgressionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final nightSignal = snapshot.cosmetics.any(
      (cosmetic) => cosmetic.key == 'night_signal' && cosmetic.equipped,
    );
    final iceTrace = snapshot.cosmetics.any(
      (cosmetic) => cosmetic.key == 'ice_trace' && cosmetic.equipped,
    );
    final accent = iceTrace ? MortColors.lightBlue : MortColors.silverBright;
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: MortColors.softBlack,
        gradient: nightSignal
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MortColors.godBlack,
                  MortColors.softBlack,
                  MortColors.black,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: iceTrace ? MortColors.lightBlue : MortColors.silverDark,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              'MORT',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: accent,
                letterSpacing: 5,
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/gamification/ranks/${snapshot.rank}.svg',
            width: 152,
            height: 152,
          ),
          Column(
            children: [
              Text(
                snapshot.rankLabel.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: accent,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(
                'LEVEL ${snapshot.level}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const Text('EARN NEARBY. MOVE SMART.'),
        ],
      ),
    );
  }
}
