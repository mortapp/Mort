import 'package:flutter/material.dart';

import '../../data/services/supabase_service.dart';
import '../../services/app_lock_controller.dart';
import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import 'mort_widgets.dart';

class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = AppLockController.instance;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final signedIn =
            SupabaseService.isInitialized &&
            SupabaseService.client.auth.currentUser != null;
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (controller.privacyCovered ||
                (signedIn && !controller.initialized))
              const Positioned.fill(child: _PrivacyCover()),
            if (signedIn && controller.isLocked)
              Positioned.fill(child: _LockedView(controller: controller)),
          ],
        );
      },
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MortColors.bg,
      child: const Center(
        child: Icon(Icons.shield, color: MortColors.neon, size: 52),
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView({required this.controller});

  final AppLockController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MortColors.bg,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MortSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_person_outlined,
                    color: MortColors.neon,
                    size: 52,
                  ),
                  const SizedBox(height: MortSpacing.lg),
                  Text(
                    'MORT is locked',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  Text(
                    'Unlock to view private account, safety, and marketplace information.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: MortSpacing.lg),
                  MortButton(
                    label: 'Unlock MORT',
                    icon: Icons.fingerprint,
                    busy: controller.authenticating,
                    busyLabel: 'Authenticating...',
                    onPressed: controller.unlock,
                  ),
                  if (controller.failureMessage != null) ...[
                    const SizedBox(height: MortSpacing.md),
                    Text(
                      controller.failureMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: MortColors.warning),
                    ),
                  ],
                  const SizedBox(height: MortSpacing.md),
                  Text(
                    'Face, fingerprint, PIN, pattern, or passcode checks stay on this device. They do not verify legal identity, age, or safety.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
