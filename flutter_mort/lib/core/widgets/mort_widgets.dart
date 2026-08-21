import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

export 'mort_brand.dart';
export 'mort_design_components.dart';
export 'mort_liquid_glass.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import '../theme/mort_tokens.dart';
import 'mort_brand.dart';
import 'mort_liquid_glass.dart';

/// Floor for bottom safe-area clearance -- see the comment at its use
/// site in [MortScreen]. Sized to comfortably clear a real 3-button
/// Android navigation bar (including the extra accessibility-shortcut
/// icon some OEMs add to it) even when the OS under-reports the inset.
const double _minimumBottomSafeArea = 48;

class MortScreen extends StatelessWidget {
  const MortScreen({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.bottom,
    this.scroll = true,
    this.onWillPop,
    this.scrollController,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Widget? bottom;
  final bool scroll;
  final Future<bool> Function(BuildContext context)? onWillPop;
  final ScrollController? scrollController;

  bool get _hasHeader =>
      children.any((child) => child is MortHeader || child is MortGlassHeader);

  Future<bool> _handleWillPop(BuildContext context) async {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardVisible && primaryFocus != null && primaryFocus.hasFocus) {
      primaryFocus.unfocus();
      return false;
    }
    if (onWillPop != null) {
      return await onWillPop!(context);
    }

    final goRouter = GoRouter.maybeOf(context);
    final location = goRouter?.state.uri.path ?? '/';
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    if (!canPop &&
        goRouter != null &&
        !MortBackNavigation.isRootLocation(location)) {
      final fallback = MortBackNavigation.fallbackRoute(location);
      if (fallback != location) {
        goRouter.go(fallback);
        return false;
      }
    }

    return true;
  }

  Future<void> _handlePopInvoked(
    BuildContext context, {
    required bool didPop,
  }) async {
    if (didPop) return;
    final shouldPop = await _handleWillPop(context);
    if (!context.mounted || !shouldPop) return;

    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
      return;
    }

    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '/';
    if (MortBackNavigation.isRootLocation(location)) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '/';
    final showFloatingBack =
        !_hasHeader && !MortBackNavigation.isRootLocation(location);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final allowImmediatePop =
        onWillPop == null &&
        !keyboardVisible &&
        ((Navigator.maybeOf(context)?.canPop() ?? false) ||
            MortBackNavigation.isRootLocation(location));
    // A physically-confirmed bug: on at least one real Android 15 device,
    // MediaQuery's reported bottom viewPadding did not reliably reflect
    // the actual system navigation bar height even after opting into
    // edge-to-edge explicitly (see main.dart), leaving SafeArea with
    // nothing to inset by -- the last interactive element on a screen
    // could render (and receive touches) behind the system nav bar.
    // `minimum` guarantees a floor regardless of what the OS reports.
    final content = SafeArea(
      minimum: const EdgeInsets.only(bottom: _minimumBottomSafeArea),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MortSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (AppConfig.showReleaseStageLabel) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: MortBadge(
                      label: AppConfig.stageName,
                      color: MortColors.warning,
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );

    final body = scroll
        ? SingleChildScrollView(controller: scrollController, child: content)
        : content;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: bottom,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: MortGradients.background),
        child: PopScope<Object?>(
          canPop: allowImmediatePop,
          onPopInvokedWithResult: (didPop, _) =>
              _handlePopInvoked(context, didPop: didPop),
          child: showFloatingBack
              ? Stack(
                  children: [
                    body,
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(MortSpacing.sm),
                          child: MortBackButton(
                            fallbackRoute: MortBackNavigation.fallbackRoute(
                              location,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}

class MortHeader extends StatelessWidget {
  const MortHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.leading,
    this.showBackButton,
    this.backFallbackRoute,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final bool? showBackButton;
  final String? backFallbackRoute;

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '/';
    final showBack =
        showBackButton ??
        ((Navigator.maybeOf(context)?.canPop() ?? false) ||
            !MortBackNavigation.isRootLocation(location));
    final back =
        leading ??
        (showBack
            ? MortBackButton(
                fallbackRoute:
                    backFallbackRoute ??
                    MortBackNavigation.fallbackRoute(location),
              )
            : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (back != null) ...[back, const SizedBox(width: MortSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  MortBadge(label: eyebrow!, color: MortColors.neon),
                if (eyebrow != null) const SizedBox(height: MortSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: MortSpacing.sm),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MortSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class MortBackNavigation {
  static const _rootLocations = {
    '/',
    '/splash',
    '/welcome',
    '/account-status',
    '/teen/home',
    '/teen/jobs',
    '/teen/saved',
    '/teen/applications',
    '/teen/safety',
    '/teen/messages',
    '/teen/profile',
    '/teen/portfolio',
    '/teen/skills',
    '/teen/availability',
    '/adult/home',
    '/adult/jobs',
    '/adult/applicants',
    '/adult/profile',
    '/guardian/home',
    '/guardian/linked-teens',
    '/guardian/approvals',
    '/guardian/permissions',
    '/guardian/safety-pings',
    '/guardian/activity',
    '/admin/home',
    '/support',
    '/messages',
    '/notifications',
    '/guide',
    '/monetization',
    '/legal-center',
    '/settings',
    '/partner/home',
    '/review',
    '/review/teen',
    '/review/adult',
    '/review/guardian',
    '/review/support',
    '/review/admin',
  };

  static String _normalizeLocation(String location) {
    try {
      return Uri.parse(location).replace(query: '').path;
    } catch (_) {
      return location;
    }
  }

  static bool isRootLocation(String location) {
    return _rootLocations.contains(_normalizeLocation(location));
  }

  static String fallbackRoute(String location) {
    final normalized = _normalizeLocation(location);
    if (normalized == '/auth/sign-in' || normalized == '/auth/sign-up') {
      return '/splash';
    }
    if (normalized == '/auth/forgot-password' ||
        normalized == '/auth-callback' ||
        normalized == '/auth-confirm' ||
        normalized == '/auth-recovery' ||
        normalized == '/auth/confirm' ||
        normalized == '/auth/recovery') {
      return '/auth/sign-in';
    }
    if (normalized == '/onboarding/age') return '/onboarding';
    if (normalized == '/onboarding/role') return '/onboarding/age';
    if (normalized == '/onboarding/profile') return '/onboarding/role';
    if (normalized == '/onboarding/skills') return '/onboarding/profile';
    if (normalized == '/onboarding/availability') return '/onboarding/skills';
    if (normalized == '/onboarding/transportation')
      return '/onboarding/availability';
    if (normalized == '/onboarding/payment')
      return '/onboarding/transportation';
    if (normalized == '/onboarding/guardian') return '/onboarding/payment';
    if (normalized == '/onboarding/preferences') return '/onboarding/guardian';
    if (normalized == '/onboarding/safety') return '/onboarding/preferences';
    if (normalized == '/onboarding/review') return '/onboarding/preferences';
    if (normalized.startsWith('/teen/jobs/')) return '/teen/home';
    if (normalized == '/teen/profile/edit') return '/teen/profile';
    if (normalized.startsWith('/teen/safety/applications/')) {
      return '/teen/safety';
    }
    if (normalized.startsWith('/teen/messages/')) return '/teen/messages';
    if (normalized.startsWith('/teen/applications/'))
      return '/teen/applications';
    if (normalized.startsWith('/teen/proof/')) return '/teen/applications';
    if (normalized.startsWith('/adult/post-job')) return '/adult/home';
    if (normalized.startsWith('/adult/jobs/') && normalized.endsWith('/edit')) {
      final segments = normalized.split('/');
      if (segments.length >= 4) {
        return '/adult/jobs/${segments[3]}';
      }
      return '/adult/jobs';
    }
    if (normalized.startsWith('/adult/jobs/')) return '/adult/home';
    if (normalized.startsWith('/adult/applicants/')) return '/adult/home';
    if (normalized.startsWith('/adult/proof-review/')) return '/adult/home';
    if (normalized.startsWith('/guardian/approvals/')) return '/guardian/home';
    if (normalized.startsWith('/guardian/')) return '/guardian/home';
    if (normalized.startsWith('/admin/reports/')) return '/admin/home';
    if (normalized.startsWith('/admin/verifications/')) return '/admin/home';
    if (normalized.startsWith('/admin/support/ticket/')) return '/admin/home';
    if (normalized.startsWith('/admin/')) return '/admin/home';
    if (normalized.startsWith('/messages/')) return '/messages';
    if (normalized.startsWith('/support/chat/')) return '/support/chat';
    if (normalized == '/support/chat/history') return '/support/chat';
    if (normalized == '/support/new' ||
        normalized.startsWith('/support/ticket/')) {
      return '/support';
    }
    if (normalized.startsWith('/guide/conversation/')) return '/guide';
    if (normalized == '/guide/delete-history') return '/guide/history';
    if (normalized == '/legal/terms' ||
        normalized == '/legal/privacy' ||
        normalized == '/legal/community-rules' ||
        normalized == '/legal/payment-disclaimer' ||
        normalized == '/legal/verification-disclaimer' ||
        normalized == '/legal/ad-disclosure' ||
        normalized == '/legal/subscription-disclosure' ||
        normalized == '/legal/teen-safety' ||
        normalized == '/legal/guardian-guide') {
      return '/legal-center';
    }
    if (normalized.startsWith('/contracts/')) return '/contracts';
    if (normalized.startsWith('/payments/')) return '/account-status';
    if (normalized.startsWith('/disputes/')) return '/account-status';
    if (normalized.startsWith('/trust/')) return '/trust/foundations';
    if (normalized.startsWith('/settings/')) return '/settings';
    if (normalized.startsWith('/mission/')) return '/account-status';
    if (normalized.startsWith('/partner/')) return '/partner/home';
    if (normalized.startsWith('/monetization/')) return '/monetization';
    if (normalized.startsWith('/review/')) return '/review';
    return '/account-status';
  }
}

class MortCard extends StatelessWidget {
  const MortCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.color = MortColors.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MortGlassCard(
      padding: padding,
      color: color,
      onTap: onTap,
      child: child,
    );
  }
}

class MortGlassCard extends StatelessWidget {
  const MortGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.color = MortColors.card,
    this.onTap,
    this.blur = false,
    this.infoAccent = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final bool blur;
  final bool infoAccent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      padding: padding,
      tint: infoAccent ? MortColors.lightBlue : color,
      liveBlur: blur,
      // Callers that explicitly opt into blur (MortGlassSheet, and any
      // future caller passing blur: true) get real blur on Android too,
      // not the flat-translucency fallback -- this stays scoped to
      // surfaces that already chose blur, not every card app-wide, so
      // scrolling lists of cards are untouched.
      allowAndroidBlur: blur,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

class MortGlassSheet extends StatelessWidget {
  const MortGlassSheet({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    blur: true,
    padding: padding ?? const EdgeInsets.all(MortSpacing.lg),
    child: child,
  );
}

enum MortButtonStyle { primary, secondary, danger, ghost, disabled }

class MortButton extends StatelessWidget {
  const MortButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = MortButtonStyle.primary,
    this.fullWidth = true,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MortButtonStyle style;
  final bool fullWidth;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final enabled =
        onPressed != null && style != MortButtonStyle.disabled && !busy;
    final bg = switch (style) {
      MortButtonStyle.primary => MortColors.roseGold,
      MortButtonStyle.secondary => MortColors.cardAlt,
      MortButtonStyle.danger => MortColors.danger,
      MortButtonStyle.ghost => Colors.transparent,
      MortButtonStyle.disabled => MortColors.line,
    };
    final fg = switch (style) {
      MortButtonStyle.primary => MortColors.godBlack,
      MortButtonStyle.secondary => MortColors.text,
      MortButtonStyle.danger => Colors.white,
      MortButtonStyle.ghost => MortColors.roseGold,
      MortButtonStyle.disabled => MortColors.textMuted,
    };

    final button = ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(busy ? busyLabel ?? label : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: style == MortButtonStyle.primary
            ? Colors.transparent
            : bg,
        foregroundColor: fg,
        disabledBackgroundColor: MortColors.line,
        disabledForegroundColor: MortColors.textMuted,
        minimumSize: const Size(48, 52),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: style == MortButtonStyle.secondary
            ? const BorderSide(color: MortColors.lineStrong)
            : BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MortRadii.medium),
        ),
      ),
    );

    final decorated = AnimatedOpacity(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MortMotion.quick,
      opacity: enabled ? 1 : 0.58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: style == MortButtonStyle.primary
              ? MortGradients.metallic
              : null,
          color: style == MortButtonStyle.primary ? null : bg,
          borderRadius: BorderRadius.circular(MortRadii.medium),
          boxShadow: style == MortButtonStyle.primary ? MortShadows.glow : null,
        ),
        child: button,
      ),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, child: decorated)
        : decorated;
  }
}

class MortPrimaryButton extends StatelessWidget {
  const MortPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) =>
      MortButton(label: label, icon: icon, onPressed: onPressed, busy: busy);
}

class MortSecondaryButton extends StatelessWidget {
  const MortSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => MortButton(
    label: label,
    icon: icon,
    onPressed: onPressed,
    style: MortButtonStyle.secondary,
  );
}

class MortIconButton extends StatelessWidget {
  const MortIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: MortColors.glass,
        foregroundColor: MortColors.roseGoldLight,
        side: const BorderSide(color: MortColors.lineStrong),
        minimumSize: const Size.square(MortSpacing.minTouchTarget),
      ),
    );
  }
}

class MortBackButton extends StatelessWidget {
  const MortBackButton({
    super.key,
    this.fallbackRoute,
    this.onPressed,
    this.confirmExit,
  });

  final String? fallbackRoute;
  final VoidCallback? onPressed;
  final Future<bool> Function(BuildContext context)? confirmExit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          if (onPressed != null) {
            onPressed!();
            return;
          }

          final goRouter = GoRouter.maybeOf(context);
          final isGoRouterPresent = goRouter != null;
          final navigator = Navigator.maybeOf(context);
          final canPop = isGoRouterPresent
              ? context.canPop()
              : (navigator?.canPop() ?? false);
          final fallback = fallbackRoute;

          if (confirmExit != null) {
            final shouldExit = await confirmExit!(context);
            if (!shouldExit) return;
          }

          if (canPop) {
            if (goRouter != null) {
              goRouter.pop();
            } else if (navigator != null) {
              navigator.pop();
            }
            return;
          }

          if (fallback != null) {
            if (goRouter != null) {
              goRouter.go(fallback);
            } else if (navigator != null) {
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
              );
            }
          }
        },
        style: IconButton.styleFrom(
          backgroundColor: MortColors.glass,
          foregroundColor: MortColors.text,
          minimumSize: const Size.square(48),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

class MortTextField extends StatelessWidget {
  const MortTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;
  final bool autocorrect;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      maxLength: maxLength,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
    );
  }
}

class MortTextArea extends StatelessWidget {
  const MortTextArea({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.maxLines = 4,
    this.maxLength,
    this.validator,
    this.enabled = true,
    this.errorText,
    this.focusNode,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final bool enabled;
  final String? errorText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
      ),
    );
  }
}

class MortDropdown<T> extends StatelessWidget {
  const MortDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      dropdownColor: MortColors.cardAlt,
      items: items.entries
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry.key,
              child: Text(
                entry.value,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class MortSearchableDropdown<T> extends StatelessWidget {
  const MortSearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.searchHint = 'Search',
    this.errorText,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final String searchHint;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MortColors.cardAlt,
      builder: (context) => _MortSearchPicker<T>(
        title: label,
        selected: value,
        items: items,
        searchHint: searchHint,
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '$label. ${items[value] ?? value.toString()}. Opens searchable list.',
    child: InkWell(
      borderRadius: BorderRadius.circular(MortRadii.medium),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.search),
        ),
        child: Text(items[value] ?? value.toString()),
      ),
    ),
  );
}

class _MortSearchPicker<T> extends StatefulWidget {
  const _MortSearchPicker({
    required this.title,
    required this.selected,
    required this.items,
    required this.searchHint,
  });

  final String title;
  final T selected;
  final Map<T, String> items;
  final String searchHint;

  @override
  State<_MortSearchPicker<T>> createState() => _MortSearchPickerState<T>();
}

class _MortSearchPickerState<T> extends State<_MortSearchPicker<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = widget.items.entries
        .where(
          (entry) => entry.value.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList(growable: false);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MortSpacing.md,
          MortSpacing.md,
          MortSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + MortSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MortSpacing.sm),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: MortSpacing.sm),
            Expanded(
              child: entries.isEmpty
                  ? const MortEmptyState(
                      title: 'No matches',
                      message: 'Try a different search.',
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          minTileHeight: MortSpacing.minTouchTarget,
                          title: Text(entry.value),
                          trailing: entry.key == widget.selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: MortColors.success,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(entry.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MortBadge extends StatelessWidget {
  const MortBadge({
    super.key,
    required this.label,
    this.color = MortColors.safetyBlue,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class MortAvatar extends StatelessWidget {
  const MortAvatar({super.key, this.label, this.radius = 24});

  final String? label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = (label == null || label!.trim().isEmpty)
        ? 'M'
        : label!
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return CircleAvatar(
      radius: radius,
      backgroundColor: MortColors.neonDeep,
      child: Text(
        initials,
        style: TextStyle(
          color: MortColors.neon,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class MortProfileAvatar extends MortAvatar {
  const MortProfileAvatar({super.key, super.label, super.radius});
}

class MortToast {
  const MortToast._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class MortLoading extends StatelessWidget {
  const MortLoading({
    super.key,
    this.label = 'Loading MORT',
    this.fullScreen = true,
  });

  final String label;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    if (!fullScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MortSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                color: MortColors.roseGold,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(width: MortSpacing.sm),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    return MortScreen(
      scroll: false,
      children: [
        const Spacer(),
        const Center(child: MortAnimatedBrandMark(size: 104)),
        const SizedBox(height: MortSpacing.md),
        Center(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Spacer(),
      ],
    );
  }
}

class MortEmptyState extends StatelessWidget {
  const MortEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon,
  });

  final String title;
  final String message;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MortGlassCard(
      infoAccent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon == null)
            const MortBrandMark(size: 64)
          else
            Icon(icon, color: MortColors.lightBlue, size: 34),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: MortSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class MortErrorState extends StatelessWidget {
  const MortErrorState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.danger.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: MortColors.danger),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: MortSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class MortSkeletonCard extends StatelessWidget {
  const MortSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (index) => Container(
            height: index == 0 ? 18 : 12,
            width: index == 0 ? 180 : 260,
            margin: const EdgeInsets.only(bottom: MortSpacing.sm),
            decoration: BoxDecoration(
              color: MortColors.line.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class MortSafetyBanner extends StatelessWidget {
  const MortSafetyBanner({
    super.key,
    this.message = AppConstants.teenSafetyDisclaimer,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MortGlassCard(
      color: MortColors.lightBlueDeep.withValues(alpha: 0.28),
      infoAccent: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: MortColors.safetyBlue),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class MortSafetyCard extends MortSafetyBanner {
  const MortSafetyCard({super.key, super.message});
}

class MortPaymentDisclaimer extends StatelessWidget {
  const MortPaymentDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(message: AppConstants.paymentDisclaimer);
  }
}

class MortVerificationDisclaimer extends StatelessWidget {
  const MortVerificationDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(message: AppConstants.verificationDisclaimer);
  }
}

class MortGuardianBanner extends StatelessWidget {
  const MortGuardianBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(
      message:
          'Guardian Mode can supervise approvals, messages, pings, and teen activity. Teens can still use free safety tools.',
    );
  }
}

class MortAdBannerSlot extends StatelessWidget {
  const MortAdBannerSlot({
    super.key,
    required this.placement,
    this.sensitive = false,
  });

  final String placement;
  final bool sensitive;

  @override
  Widget build(BuildContext context) {
    if (sensitive || !AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    return MortCard(
      color: MortColors.cardAlt,
      child: Row(
        children: [
          const Icon(Icons.ads_click_outlined, color: MortColors.textMuted),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              'Sponsored content',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class MortRewardedAdButton extends StatelessWidget {
  const MortRewardedAdButton({
    super.key,
    required this.label,
    this.onRewardReady,
    this.enabled = false,
  });

  final String label;
  final VoidCallback? onRewardReady;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MortButton(
      label: enabled ? label : '$label - Unavailable',
      icon: Icons.play_circle_outline,
      style: enabled ? MortButtonStyle.secondary : MortButtonStyle.disabled,
      onPressed: enabled ? onRewardReady : null,
    );
  }
}

class MortPaywallCard extends StatelessWidget {
  const MortPaywallCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onUpgrade,
  });

  final String title;
  final String subtitle;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.premium.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MortPremiumBadge(),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: MortSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Upgrade if you want',
            icon: Icons.auto_awesome,
            onPressed: onUpgrade,
          ),
        ],
      ),
    );
  }
}

class MortPlanCard extends StatelessWidget {
  const MortPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.features,
    this.onPressed,
  });

  final String title;
  final String price;
  final List<String> features;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(price, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: MortSpacing.sm),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: MortColors.neon,
                    size: 17,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(
                    child: Text(
                      feature,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: onPressed == null ? 'Dashboard setup needed' : 'Choose plan',
            onPressed: onPressed,
            style: onPressed == null
                ? MortButtonStyle.disabled
                : MortButtonStyle.primary,
          ),
        ],
      ),
    );
  }
}

class MortFeatureLockCard extends StatelessWidget {
  const MortFeatureLockCard({
    super.key,
    required this.feature,
    required this.reason,
  });

  final String feature;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.premium.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: MortColors.premium),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MortSpacing.xs),
                Text(reason, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MortPremiumBadge extends StatelessWidget {
  const MortPremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Premium optional',
      color: MortColors.premium,
      icon: Icons.auto_awesome,
    );
  }
}

class MortAdFreeBadge extends StatelessWidget {
  const MortAdFreeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Ad-free eligible',
      color: MortColors.neon,
      icon: Icons.visibility_off_outlined,
    );
  }
}

class MortJobStatusBadge extends StatelessWidget {
  const MortJobStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open' => MortColors.neon,
      'closed' || 'removed' => MortColors.danger,
      'paused' => MortColors.warning,
      _ => MortColors.safetyBlue,
    };
    return MortBadge(label: status.replaceAll('_', ' '), color: color);
  }
}

class MortTrustBadge extends StatelessWidget {
  const MortTrustBadge({super.key, required this.label, this.verified = false});

  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return MortBadge(
      label: label,
      color: verified ? MortColors.neon : MortColors.textMuted,
      icon: verified ? Icons.verified : Icons.info_outline,
    );
  }
}

class MortCategoryPill extends StatelessWidget {
  const MortCategoryPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: MortColors.neonDeep,
      backgroundColor: MortColors.cardAlt,
      labelStyle: TextStyle(
        color: selected ? MortColors.neon : MortColors.textSoft,
      ),
      side: BorderSide(color: selected ? MortColors.neon : MortColors.line),
    );
  }
}

/// A "Get set up" checklist card (a real, non-cosmetic completion nudge --
/// each item reflects an actual missing profile field, not a fake progress
/// illustration) rather than a bare percentage bar.
class MortProfileCompletionMeter extends StatelessWidget {
  const MortProfileCompletionMeter({
    super.key,
    required this.value,
    this.items = const [],
    this.onTap,
  });

  final double value;
  final List<({String label, bool complete})> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.complete).length;
    final total = items.length;
    final allComplete = total == 0 ? value >= 1 : done == total;
    final remaining = items
        .where((item) => !item.complete)
        .take(3)
        .toList(growable: false);
    return MortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  allComplete ? 'Profile complete' : 'Get set up',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (total > 0)
                Text(
                  '$done of $total',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: MortColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          MortProgressBar(value: value),
          if (!allComplete && remaining.isNotEmpty) ...[
            const SizedBox(height: MortSpacing.sm),
            for (final item in remaining)
              Padding(
                padding: const EdgeInsets.only(top: MortSpacing.xxs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: MortColors.textMuted,
                    ),
                    const SizedBox(width: MortSpacing.xs),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class MortStatCard extends StatelessWidget {
  const MortStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.trending_up,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MortColors.neon),
          const SizedBox(height: MortSpacing.sm),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class MortAction {
  const MortAction({
    required this.label,
    this.icon = Icons.arrow_forward,
    this.route,
    this.onPressed,
    this.enabled = true,
    this.style = MortButtonStyle.secondary,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final IconData icon;
  final String? route;
  final VoidCallback? onPressed;
  final bool enabled;
  final MortButtonStyle style;
  final bool busy;
  final String? busyLabel;
}

class MortActionRow extends StatelessWidget {
  const MortActionRow({super.key, required this.actions});

  final List<MortAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MortSpacing.sm,
      runSpacing: MortSpacing.sm,
      children: actions.map((action) {
        return MortButton(
          label: action.enabled
              ? action.label
              : '${action.label} - Unavailable',
          icon: action.icon,
          fullWidth: false,
          busy: action.busy,
          busyLabel: action.busyLabel,
          style: action.enabled ? action.style : MortButtonStyle.disabled,
          onPressed: action.enabled
              ? action.onPressed ??
                    (action.route == null
                        ? null
                        : () => context.go(action.route!))
              : null,
        );
      }).toList(),
    );
  }
}

/// A row of icon-in-circle quick actions (label under a badge, not a
/// text button) -- the pattern real finance/marketplace apps (Klarna,
/// Cash App) use for a compact "top actions" strip, rather than a bank
/// of full-width buttons competing for attention with page content.
class MortQuickActionGrid extends StatelessWidget {
  const MortQuickActionGrid({super.key, required this.actions});

  final List<MortAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MortSpacing.md,
      runSpacing: MortSpacing.md,
      children: actions.map((action) {
        final enabled = action.enabled;
        final onTap = enabled
            ? (action.onPressed ??
                  (action.route == null
                      ? null
                      : () => context.go(action.route!)))
            : null;
        return SizedBox(
          width: 74,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MortRadii.pill),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: MortColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: MortColors.line),
                  ),
                  child: Icon(
                    action.icon,
                    color: enabled
                        ? MortColors.roseGoldLight
                        : MortColors.textDisabled,
                  ),
                ),
                const SizedBox(height: MortSpacing.xxs),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: enabled ? null : MortColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class MortNotificationBell extends StatelessWidget {
  const MortNotificationBell({super.key, this.count = 0, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MortIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: MortColors.danger,
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class MortProgressBar extends StatelessWidget {
  const MortProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 9,
        value: value.clamp(0, 1),
        backgroundColor: MortColors.line,
        valueColor: const AlwaysStoppedAnimation<Color>(MortColors.neon),
      ),
    );
  }
}

class MortStepper extends StatelessWidget {
  const MortStepper({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index <= current;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(
              right: index == total - 1 ? 0 : MortSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: active ? MortColors.neon : MortColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class MortConfirmSheet {
  const MortConfirmSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MortSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: MortSpacing.sm),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: MortSpacing.lg),
              MortButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'Cancel',
                style: MortButtonStyle.ghost,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }
}

class MortBottomSheet {
  const MortBottomSheet._();

  static Future<T?> show<T>(BuildContext context, Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MortSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class MortSectionTitle extends StatelessWidget {
  const MortSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: MortSpacing.lg,
        bottom: MortSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
