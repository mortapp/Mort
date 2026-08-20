import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/oauth_flow.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../data/repositories/providers.dart';

/// Mirrors `GoogleAuthSection` in `google_auth_screens.dart` -- same
/// browser-based Supabase PKCE flow, Apple's own provider and branding.
class AppleAuthSection extends ConsumerStatefulWidget {
  const AppleAuthSection({super.key, this.successRoute = '/account-status'});

  final String successRoute;

  @override
  ConsumerState<AppleAuthSection> createState() => _AppleAuthSectionState();
}

class _AppleAuthSectionState extends ConsumerState<AppleAuthSection> {
  StreamSubscription<OAuthFlowSnapshot>? _subscription;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(authRepositoryProvider).oauthStates.listen((
      state,
    ) {
      if (!mounted || state.stage != OAuthFlowStage.success || _navigated) {
        return;
      }
      _navigated = true;
      context.go(widget.successRoute);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _launch() async {
    _navigated = false;
    await ref.read(authRepositoryProvider).signInWithApple();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.appleAuthEnabled) return const SizedBox.shrink();
    final repository = ref.watch(authRepositoryProvider);
    final state = ref
        .watch(oauthFlowStateProvider)
        .when(
          data: (value) => value,
          loading: () => repository.oauthState,
          error: (_, _) => const OAuthFlowSnapshot(
            OAuthFlowStage.internalFailure,
            'Apple sign-in status is unavailable. Use email and password.',
          ),
        );
    final enabled = !state.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MortSpacing.sm),
        Semantics(
          button: true,
          enabled: enabled,
          label: 'Continue with Apple',
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: enabled ? _launch : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF1F1F1F),
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.isBusy)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.apple, size: 20, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    state.isBusy
                        ? 'Connecting to Apple...'
                        : 'Continue with Apple',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.message.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: MortSpacing.xs),
              child: Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: state.isError
                      ? MortColors.warning
                      : MortColors.textMuted,
                ),
              ),
            ),
          ),
        if (state.canCancel)
          TextButton(
            onPressed: repository.cancelOAuthFlow,
            child: const Text('Cancel Apple sign-in'),
          ),
      ],
    );
  }
}
