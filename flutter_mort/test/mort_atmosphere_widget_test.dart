import 'package:flutter/material.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmosphere_tuning.dart';
import 'package:flutter_mort/core/atmosphere/mort_atmospheric_background.dart';
import 'package:flutter_mort/core/atmosphere/mort_wordmark_reveal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    MortWordmarkPlayback.hasPlayedThisLaunch = false;
  });

  testWidgets('MortAtmosphericBackground paints every frame without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: MortAtmosphericBackground(
            intensity: MortAtmosphereIntensity.midnight,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    // Advance well past a meteor spawn window and a full aurora breathe
    // cycle so every draw branch (stars, clouds, aurora, meteors, dither,
    // vignette) actually executes at least once.
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MortAtmosphericBackground honors reduced motion without throwing',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SizedBox(
              width: 400,
              height: 800,
              child: MortAtmosphericBackground(
                intensity: MortAtmosphereIntensity.quiet,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every atmosphere intensity preset renders without throwing', (
    tester,
  ) async {
    for (final intensity in MortAtmosphereIntensity.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            height: 720,
            child: MortAtmosphericBackground(intensity: intensity),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'intensity: $intensity');
    }
  });

  testWidgets(
    'MortWordmarkReveal completes its trace and settles once per launch',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: MortWordmarkReveal())),
      );
      expect(tester.takeException(), isNull);
      expect(MortWordmarkPlayback.hasPlayedThisLaunch, isFalse);

      await tester.pump(
        MortAtmosphereTuning.wordmarkTotal + const Duration(milliseconds: 100),
      );
      expect(tester.takeException(), isNull);
      expect(MortWordmarkPlayback.hasPlayedThisLaunch, isTrue);

      // A second mount within the same launch must settle immediately, not
      // replay the trace -- this is the "once per launch, not per rebuild"
      // contract.
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: MortWordmarkReveal())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('MortWordmarkReveal settles instantly under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Center(child: MortWordmarkReveal())),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(MortWordmarkPlayback.hasPlayedThisLaunch, isTrue);
  });
}
