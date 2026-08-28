import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'core/auth/auth_startup.dart';
import 'core/routing/app_router.dart';
import 'core/routing/notification_destination.dart';
import 'core/theme/mort_theme.dart';
import 'core/widgets/app_lock_gate.dart';
import 'core/widgets/auth_startup_gate.dart';
import 'core/widgets/mort_widgets.dart';
import 'core/observability/product_analytics.dart';
import 'core/preferences/mort_experience_preferences.dart';
import 'data/repositories/providers.dart';
import 'services/app_lock_controller.dart';
import 'services/push/push_notification_coordinator.dart';

class MortApp extends ConsumerStatefulWidget {
  const MortApp({super.key});

  @override
  ConsumerState<MortApp> createState() => _MortAppState();
}

class _MortAppState extends ConsumerState<MortApp> with WidgetsBindingObserver {
  String? _lastStartupNavigationKey;
  StreamSubscription? _foregroundPushSubscription;
  StreamSubscription? _openedPushSubscription;
  late final _router = ref.read(appRouterProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router.routerDelegate.addListener(_recordCurrentSurface);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLockController.instance.initialize();
      _recordCurrentSurface();
    });
    final push = PushNotificationCoordinator.instance;
    _foregroundPushSubscription = push.foregroundMessages.listen((_) {
      if (!mounted) return;
      ref.invalidate(notificationsRepositoryProvider);
      MortToast.show(
        context,
        'New MORT update. Open Notifications for details.',
      );
    });
    _openedPushSubscription = push.openedMessages.listen((message) async {
      try {
        final profile = await ref.read(currentProfileProvider.future);
        if (!mounted) return;
        ref
            .read(appRouterProvider)
            .go(notificationDestination(message.data, profile?.role));
      } catch (_) {
        if (mounted) ref.read(appRouterProvider).go('/account-status');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_recordCurrentSurface);
    _foregroundPushSubscription?.cancel();
    _openedPushSubscription?.cancel();
    super.dispose();
  }

  void _recordCurrentSurface() {
    final configuration = _router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;
    unawaited(
      MortProductAnalytics.instance.recordScreenPath(configuration.uri.path),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLockController.instance.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final startup = ref.watch(authStartupProvider);
    final experience = ref
        .watch(mortExperiencePreferencesProvider)
        .asData
        ?.value;
    final snapshot = startup.snapshot;
    if (!snapshot.blocksNavigation &&
        snapshot.destination != null &&
        snapshot.navigationKey != _lastStartupNavigationKey) {
      _lastStartupNavigationKey = snapshot.navigationKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) router.go(snapshot.destination!);
      });
    }
    return MaterialApp.router(
      onGenerateTitle: (context) => MortLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: MortTheme.dark(),
      localizationsDelegates: const [
        MortLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      routerConfig: router,
      builder: (context, child) {
        final preferences = experience ?? const MortExperiencePreferences();
        final deviceMedia = MediaQuery.of(context);
        return MediaQuery(
          data: deviceMedia.copyWith(
            disableAnimations:
                deviceMedia.disableAnimations || preferences.reducedMotion,
            highContrast: deviceMedia.highContrast || preferences.highContrast,
          ),
          child: MortExperiencePreferencesScope(
            preferences: preferences,
            child: AuthStartupGate(
              controller: startup,
              child: AppLockGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
    );
  }
}
