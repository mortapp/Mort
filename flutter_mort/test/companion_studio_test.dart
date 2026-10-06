import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mort/features/companion/companion_catalog.dart';
import 'package:flutter_mort/features/companion/companion_store.dart';
import 'package:flutter_mort/features/companion/companion_avatar.dart';
import 'package:flutter_mort/features/companion/companion_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('catalog has fourteen distinct companions and only Wix is free', () {
    expect(companions.length, 14);
    expect(companions.map((pet) => pet.id).toSet().length, 14);
    expect(companions.where((pet) => !pet.requiresPro).single.id, 'wix');
    expect(canSelectCompanion('milo', hasPro: false), isFalse);
    expect(canSelectCompanion('milo', hasPro: true), isTrue);
    expect(canSelectCompanion('unknown', hasPro: true), isFalse);
  });

  test('pet artwork has vibrant colors independent of neutral app chrome', () {
    for (final pet in companions) {
      expect(
        HSLColor.fromColor(pet.baseColor).saturation,
        greaterThan(.3),
        reason: pet.id,
      );
    }
    for (final id in ['coral', 'sunshine', 'mint', 'lavender', 'sky']) {
      expect(companionColors.any((option) => option.id == id), isTrue);
    }
  });

  test('saved looks are scoped to an account and cannot grant Pro', () async {
    final store = CompanionStore();
    final look = CompanionLook(
      companionId: 'milo',
      colorId: 'silver',
      accessoryId: 'scarf',
      itemId: 'book',
      auraId: 'stars',
      environmentId: 'moon_base',
    );
    await store.save('user-a', look, hasPro: true);
    expect((await store.load('user-a', hasPro: true)).companionId, 'milo');
    expect((await store.load('user-a', hasPro: false)).companionId, 'wix');
    expect((await store.load('user-b', hasPro: true)).companionId, 'wix');
    expect(() => store.save('user-a', look, hasPro: false), throwsStateError);
  });

  test('unknown cosmetic tokens fall back to safe defaults', () async {
    final store = CompanionStore();
    await store.save(
      'user-a',
      const CompanionLook(
        companionId: 'wix',
        colorId: 'silver',
        accessoryId: 'scarf',
        itemId: 'book',
        auraId: 'stars',
        environmentId: 'moon_base',
      ),
      hasPro: false,
    );
    final prefs = await SharedPreferences.getInstance();
    final key = CompanionStore.storageKey('user-a');
    await prefs.setString(
      key,
      prefs.getString(key)!.replaceFirst('silver', 'injected-token'),
    );
    final loaded = await store.load('user-a', hasPro: false);
    expect(loaded.colorId, 'default');
  });

  test('saved looks stay account scoped and locked looks are hidden', () async {
    final store = CompanionStore();
    await store.addSavedLook(
      'user-a',
      const CompanionLook(companionId: 'wix', colorId: 'silver'),
      hasPro: false,
    );
    await store.addSavedLook(
      'user-a',
      const CompanionLook(companionId: 'milo', colorId: 'ice'),
      hasPro: true,
    );
    expect((await store.savedLooks('user-a', hasPro: true)).length, 2);
    expect(
      (await store.savedLooks('user-a', hasPro: false)).single.companionId,
      'wix',
    );
    expect(await store.savedLooks('user-b', hasPro: true), isEmpty);
    await store.removeSavedLook('user-a', 0);
    expect(
      (await store.savedLooks('user-a', hasPro: true)).single.companionId,
      'milo',
    );
  });

  test('focus duration choices are bounded and have no reward path', () {
    expect(focusMinutes, [15, 25, 45, 60]);
    expect(focusMinutes.contains(0), isFalse);
  });

  testWidgets('every companion renders with an accessible name', (
    tester,
  ) async {
    for (final pet in companions) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompanionAvatar(
              companion: pet,
              look: const CompanionLook(),
              reducedMotion: true,
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('${pet.name}, ${pet.kind} companion'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion stops the companion animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompanionAvatar(
            companion: CompanionDefinition(
              'wix',
              'Wix',
              'Fox-cat',
              'Curious',
              'Curious little explorer.',
              Color(0xFFF8FAFC),
              requiresPro: false,
            ),
            look: CompanionLook(),
            reducedMotion: true,
          ),
        ),
      ),
    );
    final state = tester.state<CompanionAvatarState>(
      find.byType(CompanionAvatar),
    );
    expect(state.isAnimating, isFalse);
  });

  testWidgets('interaction pose has accessible text with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompanionAvatar(
            companion: CompanionDefinition(
              'wix',
              'Wix',
              'Fox-cat',
              'Curious',
              'Curious little explorer.',
              Color(0xFFF8FAFC),
              requiresPro: false,
            ),
            look: CompanionLook(),
            action: CompanionAction.wave,
            reducedMotion: true,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Wix, Fox-cat companion, waving'),
      findsOneWidget,
    );
    expect(
      tester
          .state<CompanionAvatarState>(find.byType(CompanionAvatar))
          .isAnimating,
      isFalse,
    );
  });

  testWidgets('free member cannot select a Pro companion', (tester) async {
    var paywallOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CompanionStudioBody(
            userId: 'user-a',
            hasPro: false,
            store: CompanionStore(),
            onOpenPro: () => paywallOpens++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wix'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('companion-milo')));
    await tester.tap(find.byKey(const Key('companion-milo')));
    await tester.pump();
    expect(paywallOpens, 1);
    expect(
      (await CompanionStore().load('user-a', hasPro: true)).companionId,
      'wix',
    );
  });

  testWidgets('focus offers the four supported timers without a reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CompanionStudioBody(
            userId: 'user-a',
            hasPro: false,
            store: CompanionStore(),
            onOpenPro: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final focusButton = find.text('Focus with Wix');
    await tester.ensureVisible(focusButton);
    await tester.tap(focusButton);
    await tester.pumpAndSettle();
    for (final minutes in focusMinutes) {
      expect(find.text('$minutes min'), findsOneWidget);
    }
    expect(
      find.textContaining('No streaks, tokens or rewards.'),
      findsOneWidget,
    );
  });

  testWidgets('saved look can be removed from the Studio', (tester) async {
    final store = CompanionStore();
    await store.addSavedLook('user-a', const CompanionLook(), hasPro: false);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CompanionStudioBody(
            userId: 'user-a',
            hasPro: false,
            store: store,
            onOpenPro: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saved looks'));
    await tester.tap(find.text('Saved looks'));
    await tester.pumpAndSettle();
    expect(find.text('Look 1: Wix'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove look 1'));
    await tester.pumpAndSettle();
    expect(find.text('No saved looks yet.'), findsOneWidget);
    expect(await store.savedLooks('user-a', hasPro: false), isEmpty);
  });

  testWidgets('interact changes only the cosmetic pose', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CompanionStudioBody(
            userId: 'user-a',
            hasPro: false,
            store: CompanionStore(),
            onOpenPro: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Interact'));
    await tester.tap(find.text('Interact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wave'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Wix, Fox-cat companion, waving'),
      findsOneWidget,
    );
    expect(
      (await CompanionStore().load('user-a', hasPro: true)).companionId,
      'wix',
    );
  });

  testWidgets('compact phone can reach Studio controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 740),
            disableAnimations: true,
          ),
          child: CompanionStudioBody(
            userId: 'user-a',
            hasPro: false,
            store: CompanionStore(),
            onOpenPro: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Focus with Wix'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
