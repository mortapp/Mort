import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'mort_atmosphere_tuning.dart';

typedef MortFragmentProgramLoader = Future<ui.FragmentProgram> Function();

enum MortCloudFallbackReason { unsupported, loadError, performance }

/// Float-slot order is the public Dart/GLSL contract. Keep this in the same
/// order as the declarations in `shaders/mort_cloud_bank.frag`.
enum MortCloudUniform {
  time,
  resolutionX,
  resolutionY,
  drift,
  density,
  peakAlpha,
  bandY,
  bandHeight,
  tintR,
  tintG,
  tintB,
  lift,
  quality,
  layerSeed,
}

class MortCloudShaderController {
  MortCloudShaderController({MortFragmentProgramLoader? programLoader})
    : _programLoader =
          programLoader ??
          (() => ui.FragmentProgram.fromAsset('shaders/mort_cloud_bank.frag'));

  final MortFragmentProgramLoader _programLoader;
  final List<ui.FragmentShader> _shaders = [];
  MortCloudFallbackReason? _fallbackReason;

  bool get isReady => _shaders.length == 4;
  MortCloudFallbackReason? get fallbackReason => _fallbackReason;

  Future<void> load() async {
    if (isReady || _fallbackReason != null) return;
    try {
      final program = await _programLoader();
      _shaders.addAll(List.generate(4, (_) => program.fragmentShader()));
    } on UnsupportedError catch (error) {
      _fallbackReason = MortCloudFallbackReason.unsupported;
      debugPrint('MORT atmosphere shader fallback: unsupported ($error)');
    } catch (error) {
      _fallbackReason = MortCloudFallbackReason.loadError;
      debugPrint('MORT atmosphere shader fallback: load error ($error)');
    }
  }

  void usePerformanceFallback() {
    _fallbackReason = MortCloudFallbackReason.performance;
    _shaders.clear();
    debugPrint('MORT atmosphere shader fallback: measured performance');
  }

  void paintLayer(
    Canvas canvas,
    Size size, {
    required int layerIndex,
    required MortCloudLayerSpec spec,
    required Duration elapsed,
    required double opacityMultiplier,
    required double lift,
    required bool lowComplexity,
  }) {
    if (!isReady || layerIndex < 0 || layerIndex >= _shaders.length) return;
    final shader = _shaders[layerIndex];
    final signedDrift = spec.driftRight
        ? spec.driftPxPerSec
        : -spec.driftPxPerSec;
    final tint = spec.tint;
    final values = <double>[
      elapsed.inMicroseconds / 1e6,
      size.width,
      size.height,
      signedDrift,
      spec.density,
      spec.peakAlpha * opacityMultiplier,
      spec.bandY,
      spec.bandHeight,
      tint.r,
      tint.g,
      tint.b,
      lift,
      lowComplexity ? 1 : 0,
      spec.layerSeed,
    ];
    for (var index = 0; index < values.length; index++) {
      shader.setFloat(index, values[index]);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }
}
