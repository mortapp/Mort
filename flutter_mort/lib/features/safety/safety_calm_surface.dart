import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/providers.dart';

/// Safety presentation stays calm even when the account enables decoration.
class SafetyCalmSurface extends ConsumerWidget {
  const SafetyCalmSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: KeyedSubtree(
      // Clear event/contact presentation immediately on account transition.
      key: ValueKey(ref.watch(currentProfileProvider).asData?.value?.id),
      child: child,
    ),
  );
}
