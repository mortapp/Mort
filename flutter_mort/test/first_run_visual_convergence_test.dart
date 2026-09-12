import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mort/core/auth/oauth_flow.dart';
import 'package:flutter_mort/core/reviewer/reviewer_session.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/data/models/onboarding_progress.dart';
import 'package:flutter_mort/data/repositories/auth_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/auth/google_auth_screens.dart';
import 'package:flutter_mort/features/auth/unified_auth_screen.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/mort_widget_harness.dart';

void main() {
  testWidgets('splash is calm, canonical, and safe on an iPhone SE viewport', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const SplashScreen(),
      size: const Size(320, 568),
      disableAnimations: true,
    );

    expect(find.byType(MortSpaceBackground), findsOneWidget);
    expect(find.byType(MortAnimatedBrandMark), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MortAnimatedBrandMark),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(find.text('Enter MORT'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    final enter = tester.widget<MortButton>(
      find.widgetWithText(MortButton, 'Enter MORT'),
    );
    final signIn = tester.widget<MortButton>(
      find.widgetWithText(MortButton, 'Sign in'),
    );
    expect(enter.style, MortButtonStyle.primary);
    expect(signIn.style, MortButtonStyle.ghost);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome keeps safe pinned actions and monochrome features', (
    tester,
  ) async {
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      await _pumpFirstRun(
        tester,
        const WelcomeScreen(),
        size: size,
        disableAnimations: true,
        bottomSystemInset: 24,
      );

      expect(find.byType(MortSpaceBackground), findsOneWidget);
      expect(find.byType(MortLogo), findsOneWidget);
      expect(find.text('Welcome to MORT'), findsOneWidget);
      final createFinder = find.widgetWithText(MortButton, 'Create account');
      final signInFinder = find.widgetWithText(
        MortButton,
        'I already have an account',
      );
      final create = tester.widget<MortButton>(createFinder);
      final signIn = tester.widget<MortButton>(signInFinder);
      expect(create.style, MortButtonStyle.primary);
      expect(signIn.style, MortButtonStyle.secondary);
      expect(createFinder, findsOneWidget);
      expect(signInFinder, findsOneWidget);
      expect(createFinder.hitTestable(), findsOneWidget);
      expect(signInFinder.hitTestable(), findsOneWidget);
      for (final finder in [createFinder, signInFinder]) {
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
      }
      expect(
        tester.widget<Icon>(find.byIcon(Icons.schedule_rounded)).color,
        MortColors.silver,
      );
      final safetyCard = find.ancestor(
        of: find.text('Safety stays free'),
        matching: find.byType(MortGlassCard),
      );
      expect(tester.widget<MortGlassCard>(safetyCard).infoAccent, isTrue);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: safetyCard,
                matching: find.byIcon(Icons.shield_outlined),
              ),
            )
            .color,
        MortColors.lightBlue,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.pin_outlined)).color,
        MortColors.silver,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('splash reports connected backend state honestly', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const SplashScreen(),
      size: const Size(390, 844),
      disableAnimations: true,
      backendStatus: Future.value(true),
    );

    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_done)).color,
      MortColors.accent,
    );
    expect(
      find.text(
        'Connected securely. Marketplace actions may still require account eligibility or verification.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry connection'), findsNothing);
  });

  testWidgets('splash reports disconnected backend state with retry', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const SplashScreen(),
      size: const Size(390, 844),
      disableAnimations: true,
      backendStatus: Future.value(false),
    );

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_off)).color,
      MortColors.warning,
    );
    expect(
      find.text(
        'MORT cannot connect right now. Account features remain unavailable until service returns.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry connection'), findsOneWidget);
  });

  testWidgets('splash exposes a distinct checking backend state', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await _pumpFirstRun(
      tester,
      const SplashScreen(),
      size: const Size(390, 844),
      disableAnimations: true,
      backendStatus: pending.future,
      settle: false,
    );

    expect(find.byIcon(Icons.cloud_sync), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_sync)).color,
      MortColors.silver,
    );
    expect(
      find.text('Checking the secure service connection...'),
      findsOneWidget,
    );
    expect(find.text('Retry connection'), findsNothing);
  });

  test(
    'active splash and welcome source contains no legacy primary tokens',
    () {
      final source = File(
        '${Directory.current.path}/lib/features/mort_screens.dart',
      ).readAsStringSync();
      final entry = _slice(
        source,
        'class SplashScreen',
        'class SetupRequiredScreen',
      );
      final backend = source.substring(
        source.indexOf('class _BackendStatusCard'),
      );
      final activeSource = '$entry\n$backend';

      expect(activeSource, isNot(contains('MortColors.roseGold')));
      expect(activeSource, isNot(contains('MortColors.godPink')));
      expect(activeSource, isNot(contains('MortColors.neon')));
    },
  );

  testWidgets('auth keeps canonical native controls at 200 percent text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpFirstRun(
      tester,
      const UnifiedAuthScreen(),
      size: const Size(320, 568),
      disableAnimations: true,
      textScaler: TextScaler.linear(2),
      keyboardInset: 220,
    );

    expect(find.byType(MortLogo), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(EditableText), findsNWidgets(2));
    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    expect(find.bySemanticsLabel('Password'), findsOneWidget);
    semantics.dispose();
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(
      find.text(' ($mortOnboardingAcknowledgementVersion)'),
      findsOneWidget,
    );
    expect(find.text('Google Play Review Mode'), findsNothing);
    expect(find.text('Continue as Play Reviewer'), findsNothing);
    final password = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Password'),
    );
    expect(password.enabled, isTrue);
    final keyboardTop = 568 - 220;
    for (final control in [
      find.widgetWithText(MortButton, 'Sign in'),
      find.text('Privacy Policy'),
    ]) {
      await tester.ensureVisible(control);
      await tester.pumpAndSettle();
      expect(control.hitTestable(), findsOneWidget);
      expect(tester.getRect(control).bottom, lessThanOrEqualTo(keyboardTop));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('production defaults never activate the reviewer harness', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const UnifiedAuthScreen(),
      size: const Size(390, 844),
      disableAnimations: true,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      playReviewerIdentifier,
    );
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Google Play Review Mode'), findsNothing);
    expect(find.text('Continue as Play Reviewer'), findsNothing);
  });

  testWidgets('sign-up keeps password rules and legal acknowledgement visible', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const UnifiedAuthScreen(initialMode: UnifiedAuthMode.signUp),
      size: const Size(390, 844),
      disableAnimations: true,
    );

    expect(
      find.text(
        'Use at least 12 characters with uppercase, lowercase, a number, and a symbol.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'person@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'short',
    );
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pump();
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('forgot password uses the canonical first-run brand', (
    tester,
  ) async {
    await _pumpFirstRun(
      tester,
      const ForgotPasswordScreen(),
      size: const Size(320, 568),
      disableAnimations: true,
    );

    expect(find.byType(MortLogo), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.text('Send reset email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('active auth and reset source contains no legacy primary tokens', () {
    final auth = File(
      '${Directory.current.path}/lib/features/auth/unified_auth_screen.dart',
    ).readAsStringSync();
    final screens = File(
      '${Directory.current.path}/lib/features/mort_screens.dart',
    ).readAsStringSync();
    final reset = _slice(
      screens,
      'class ForgotPasswordScreen',
      'class OnboardingHubScreen',
    );

    for (final source in [auth, reset]) {
      expect(source, isNot(contains('MortColors.roseGold')));
      expect(source, isNot(contains('MortColors.godPink')));
      expect(source, isNot(contains('MortColors.neon')));
    }
  });

  test('active account-status source contains no legacy primary tokens', () {
    final screens = File(
      '${Directory.current.path}/lib/features/mort_screens.dart',
    ).readAsStringSync();
    final accountStatus = _slice(
      screens,
      'class AccountStatusScreen',
      'class WrongRoleScreen',
    );

    expect(accountStatus, isNot(contains('MortColors.roseGold')));
    expect(accountStatus, isNot(contains('MortColors.godPink')));
    expect(accountStatus, isNot(contains('MortColors.neon')));
  });

  test('active compact onboarding uses canonical monochrome controls', () {
    final onboarding = File(
      '${Directory.current.path}/lib/features/onboarding/compact_onboarding.dart',
    ).readAsStringSync();

    expect(onboarding, contains('MortDateField('));
    expect(onboarding, contains('MortSelect<String>('));
    expect(onboarding, isNot(contains('MortColors.roseGold')));
    expect(onboarding, isNot(contains('MortColors.godPink')));
    expect(onboarding, isNot(contains('MortColors.neon')));
  });

  test(
    'provider and callback contracts remain explicit and production-gated',
    () {
      final google = File(
        '${Directory.current.path}/lib/features/auth/google_auth_screens.dart',
      ).readAsStringSync();
      final apple = File(
        '${Directory.current.path}/lib/features/auth/apple_auth_screens.dart',
      ).readAsStringSync();
      final config = File(
        '${Directory.current.path}/lib/core/config/app_config.dart',
      ).readAsStringSync();

      expect(google, contains('Continue with Google'));
      expect(apple, contains('Continue with Apple'));
      expect(google, contains('class OAuthCallbackScreen'));
      expect(google, contains('Verifying the sign-in response...'));
      expect(google, contains('Checking your MORT account...'));
      expect(google, contains('Sign-in needs attention'));
      expect(google, contains("context.go('/account-status')"));
      expect(config, contains("'com.mortapp.mobile://app/auth-callback'"));
      for (final disabledByDefaultFlag in [
        'GOOGLE_AUTH_ENABLED',
        'APPLE_AUTH_ENABLED',
        'PLAY_REVIEW_MODE_ENABLED',
      ]) {
        expect(config, contains("'$disabledByDefaultFlag'"));
      }
      expect(config, contains('defaultValue: false'));
    },
  );

  testWidgets('OAuth callback renders loading then a safe error state', (
    tester,
  ) async {
    final callback = Completer<OAuthFlowSnapshot>();
    final repository = _CallbackAuthRepository(
      initialState: const OAuthFlowSnapshot(
        OAuthFlowStage.processingCallback,
        'Verifying the sign-in response...',
      ),
      callback: (_) => callback.future,
    );
    addTearDown(repository.dispose);

    await _pumpOAuthCallback(tester, repository);

    expect(find.text('Finishing sign-in'), findsOneWidget);
    expect(find.text('Checking your MORT account...'), findsOneWidget);

    callback.complete(
      const OAuthFlowSnapshot(
        OAuthFlowStage.invalidRedirect,
        'MORT rejected an unrecognized sign-in response.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign-in needs attention'), findsOneWidget);
    expect(find.text('MORT could not finish sign-in'), findsOneWidget);
    expect(
      find.text('MORT rejected an unrecognized sign-in response.'),
      findsWidgets,
    );
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('OAuth callback success reaches account status', (tester) async {
    final repository = _CallbackAuthRepository(
      initialState: const OAuthFlowSnapshot(
        OAuthFlowStage.processingCallback,
        'Verifying the sign-in response...',
      ),
      callback: (_) async => const OAuthFlowSnapshot(
        OAuthFlowStage.success,
        'Signed in securely.',
      ),
    );
    addTearDown(repository.dispose);

    await _pumpOAuthCallback(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Account status destination'), findsOneWidget);
    expect(find.byType(OAuthCallbackScreen), findsNothing);
  });
}

class _CallbackAuthRepository extends AuthRepository {
  _CallbackAuthRepository({
    required OAuthFlowSnapshot initialState,
    required this.callback,
  }) : _state = initialState;

  final Future<OAuthFlowSnapshot> Function(Uri uri) callback;
  final StreamController<OAuthFlowSnapshot> _states =
      StreamController<OAuthFlowSnapshot>.broadcast(sync: true);
  OAuthFlowSnapshot _state;

  @override
  OAuthFlowSnapshot get oauthState => _state;

  @override
  Stream<OAuthFlowSnapshot> get oauthStates => _states.stream;

  @override
  Future<OAuthFlowSnapshot> handleOAuthCallback(Uri callbackUri) async {
    final next = await callback(callbackUri);
    _state = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  @override
  void dispose() {
    _states.close();
    super.dispose();
  }
}

Future<void> _pumpOAuthCallback(
  WidgetTester tester,
  AuthRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/auth-callback',
    routes: [
      GoRoute(
        path: '/auth-callback',
        builder: (_, _) => OAuthCallbackScreen(
          callbackUri: Uri.parse(
            'com.mortapp.mobile://app/auth-callback?code=synthetic',
          ),
        ),
      ),
      GoRoute(
        path: '/account-status',
        builder: (_, _) =>
            const Scaffold(body: Text('Account status destination')),
      ),
      GoRoute(
        path: '/auth/sign-in',
        builder: (_, _) => const Scaffold(body: Text('Sign-in destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        theme: mortTestTheme(MortTheme.dark()),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpFirstRun(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool disableAnimations,
  Future<bool>? backendStatus,
  bool settle = true,
  double bottomSystemInset = 0,
  TextScaler textScaler = TextScaler.noScaling,
  double keyboardInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: backendStatus == null
          ? const []
          : [
              backendConnectionStatusProvider.overrideWith(
                (ref) => backendStatus,
              ),
            ],
      child: MaterialApp(
        theme: mortTestTheme(MortTheme.dark()),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
            textScaler: textScaler,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            padding: EdgeInsets.only(bottom: bottomSystemInset),
            viewPadding: EdgeInsets.only(bottom: bottomSystemInset),
          ),
          child: child,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String _slice(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Unable to locate $start through $end');
  }
  return source.substring(startIndex, endIndex);
}
