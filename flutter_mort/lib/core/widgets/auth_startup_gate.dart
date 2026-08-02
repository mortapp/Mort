import 'package:flutter/material.dart';

import '../../l10n/mort_l10n.dart';
import '../auth/auth_startup.dart';
import '../theme/mort_spacing.dart';
import 'mort_widgets.dart';

class AuthStartupGate extends StatelessWidget {
  const AuthStartupGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final AuthStartupController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final strings = context.mortL10n;
    final snapshot = controller.snapshot;
    if (!snapshot.blocksNavigation) return child;

    if (snapshot.stage == MortAuthStartupStage.offline) {
      return MortScreen(
        children: [
          MortHeader(
            eyebrow: strings.sessionProtected,
            title: strings.offlineTitle,
            subtitle: strings.offlineSessionPreserved,
          ),
          MortErrorState(
            title: 'Account check paused',
            message: snapshot.message ?? strings.reconnectAndRetry,
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: strings.retryAccountCheck,
            icon: Icons.refresh,
            onPressed: controller.retry,
          ),
        ],
      );
    }

    if (snapshot.stage == MortAuthStartupStage.fatalConfiguration) {
      return MortScreen(
        children: [
          MortHeader(
            eyebrow: strings.configurationRequired,
            title: strings.secureStartupFailed,
            subtitle: strings.publicBackendConfigurationInvalid,
          ),
          MortErrorState(
            title: 'Secure startup stopped',
            message: snapshot.message ?? strings.installConfiguredBuild,
          ),
        ],
      );
    }

    final label = switch (snapshot.stage) {
      MortAuthStartupStage.refreshing => strings.refreshingSession,
      MortAuthStartupStage.restoring => strings.restoringSession,
      _ => strings.startingSecurely,
    };
    return MortScreen(
      children: [
        const SizedBox(height: MortSpacing.xl),
        MortHeader(
          eyebrow: strings.secureStartup,
          title: strings.appTitle,
          subtitle: strings.checkingDevice,
        ),
        MortLoading(label: label, fullScreen: false),
      ],
    );
  }
}
