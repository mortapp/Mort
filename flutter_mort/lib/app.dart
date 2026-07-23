import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';
import 'core/theme/mort_theme.dart';
import 'core/widgets/app_lock_gate.dart';
import 'services/app_lock_controller.dart';

class MortApp extends ConsumerStatefulWidget {
  const MortApp({super.key});

  @override
  ConsumerState<MortApp> createState() => _MortAppState();
}

class _MortAppState extends ConsumerState<MortApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLockController.instance.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLockController.instance.handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: MortTheme.dark(),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
