import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import '../widgets/mort_widgets.dart';
import 'mort_atmosphere_tuning.dart';
import 'mort_atmospheric_background.dart';
import 'mort_wordmark_reveal.dart';

/// Debug-only controls around the exact production atmosphere renderer.
class MortAtmospherePreviewScreen extends StatefulWidget {
  const MortAtmospherePreviewScreen({super.key});

  @override
  State<MortAtmospherePreviewScreen> createState() =>
      _MortAtmospherePreviewScreenState();
}

class _MortAtmospherePreviewScreenState
    extends State<MortAtmospherePreviewScreen> {
  MortAtmosphereIntensity _intensity = MortAtmosphereIntensity.midnight;
  MortAtmosphereQuality _quality = MortAtmosphereQuality.full;
  double _lift = MortAtmosphereTuning.atmosphereLift;
  bool _exposure = false;
  bool _reducedMotion = false;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: MortColors.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MortAtmosphericBackground(
            intensity: _intensity,
            quality: _quality,
            debugLift: _lift,
            cloudExposure: _exposure ? 8 : 1,
            forceReducedMotion: _reducedMotion,
            focalLayer: const Align(
              alignment: Alignment(0, -0.28),
              child: MortWordmarkReveal(width: 240, height: 84),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MortSpacing.md),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  padding: const EdgeInsets.all(MortSpacing.md),
                  decoration: BoxDecoration(
                    color: MortColors.surfaceRaised.withValues(alpha: 0.96),
                    border: Border.all(color: MortColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MortHeader(
                        eyebrow: 'DEBUG ONLY',
                        title: 'Atmosphere preview',
                        showBackButton: true,
                        backFallbackRoute: '/settings',
                      ),
                      MortDropdown<MortAtmosphereIntensity>(
                        label: 'Preset',
                        value: _intensity,
                        items: {
                          for (final value in MortAtmosphereIntensity.values)
                            value: value.name,
                        },
                        onChanged: (value) {
                          if (value != null) setState(() => _intensity = value);
                        },
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      MortDropdown<MortAtmosphereQuality>(
                        label: 'Quality',
                        value: _quality,
                        items: {
                          for (final value in MortAtmosphereQuality.values)
                            value: value.name,
                        },
                        onChanged: (value) {
                          if (value != null) setState(() => _quality = value);
                        },
                      ),
                      const SizedBox(height: MortSpacing.sm),
                      MortSegmentedControl<double>(
                        value: _lift,
                        options: const [
                          MortSegmentOption(
                            value: .03,
                            label: 'Lift .03',
                            icon: Icons.looks_one_outlined,
                          ),
                          MortSegmentOption(
                            value: .05,
                            label: 'Lift .05',
                            icon: Icons.looks_two_outlined,
                          ),
                          MortSegmentOption(
                            value: .08,
                            label: 'Lift .08',
                            icon: Icons.looks_3_outlined,
                          ),
                        ],
                        onChanged: (value) => setState(() => _lift = value),
                      ),
                      SwitchListTile(
                        value: _exposure,
                        title: const Text('+3 stop cloud exposure'),
                        onChanged: (value) => setState(() => _exposure = value),
                      ),
                      SwitchListTile(
                        value: _reducedMotion,
                        title: const Text('Reduced motion'),
                        onChanged: (value) =>
                            setState(() => _reducedMotion = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
