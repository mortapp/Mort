import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/navigation/role_profile_destination_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final role in [UserRole.adult, UserRole.guardian]) {
    testWidgets('${role.name} Profile shows account and direct Settings gear', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => RoleProfileDestinationScreen(role: role),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('Settings target')),
          ),
          GoRoute(
            path: '/settings/profile',
            builder: (_, _) => const Scaffold(body: Text('Edit target')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWithValue(
              AsyncValue.data(_profile(role)),
            ),
          ],
          child: MaterialApp.router(
            theme: MortTheme.classic(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sample member'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings target'), findsOneWidget);
    });
  }
}

Profile _profile(UserRole role) => Profile(
  id: 'synthetic-profile',
  role: role,
  displayName: 'Sample member',
  username: 'sample_member',
  dob: DateTime(1990),
  city: 'Test City',
  state: 'TS',
  onboardingCompleted: true,
  accountStatus: 'active',
  verificationStatus: 'not_started',
  paymentPreference: 'none',
);
