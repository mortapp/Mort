import 'package:flutter_mort/core/atmosphere/mort_atmosphere_tuning.dart';
import 'package:flutter_mort/core/atmosphere/mort_cloud_shader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('four cloud depths keep the approved alpha and drift contract', () {
    final layers = MortAtmosphereTuning.cloudLayers;
    expect(layers, hasLength(4));
    expect(layers.map((layer) => layer.peakAlpha).toList(), const [
      0.10,
      0.14,
      0.19,
      0.24,
    ]);
    expect(
      layers
          .map(
            (layer) =>
                layer.driftRight ? layer.driftPxPerSec : -layer.driftPxPerSec,
          )
          .toList(),
      const [2.0, -3.0, 5.0, -8.0],
    );
  });

  testWidgets('the production fragment shader asset loads', (tester) async {
    final controller = MortCloudShaderController();
    await controller.load();

    expect(controller.isReady, isTrue);
    expect(controller.fallbackReason, isNull);
  });

  test('a loader error selects a truthful fallback reason', () async {
    final controller = MortCloudShaderController(
      programLoader: () async => throw UnsupportedError('no fragment shader'),
    );
    await controller.load();

    expect(controller.isReady, isFalse);
    expect(controller.fallbackReason, MortCloudFallbackReason.unsupported);
  });

  test('uniform schema binds every approved cloud input', () {
    expect(MortCloudUniform.time.index, 0);
    expect(MortCloudUniform.resolutionX.index, 1);
    expect(MortCloudUniform.resolutionY.index, 2);
    expect(MortCloudUniform.drift.index, 3);
    expect(MortCloudUniform.density.index, 4);
    expect(MortCloudUniform.peakAlpha.index, 5);
    expect(MortCloudUniform.bandY.index, 6);
    expect(MortCloudUniform.bandHeight.index, 7);
    expect(MortCloudUniform.tintR.index, 8);
    expect(MortCloudUniform.tintG.index, 9);
    expect(MortCloudUniform.tintB.index, 10);
    expect(MortCloudUniform.lift.index, 11);
    expect(MortCloudUniform.quality.index, 12);
    expect(MortCloudUniform.layerSeed.index, 13);
  });

  test('fallback painter remains capable of rendering a frame', () {
    expect(
      MortCloudFallbackReason.values,
      contains(MortCloudFallbackReason.loadError),
    );
  });
}
