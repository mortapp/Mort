import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/core/widgets/mort_brand.dart';
import 'package:image/image.dart' as image;

void main() {
  const logoPath = 'assets/branding/mort_logo_silver_double_arrow.png';
  const sourceHash =
      'eb8d3207309fef505dfd3da1fb78c88136b9f46f297ddcbc0f80061498e7d686';

  test('uses the supplied double-arrow artwork unchanged', () {
    final bytes = File(logoPath).readAsBytesSync();

    expect(
      MortLogo.assetPath,
      'assets/branding/mort_logo_silver_double_arrow.png',
    );
    expect(sha256.convert(bytes).toString(), sourceHash);
    final decoded = image.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(
      decoded!.getBytes(order: image.ChannelOrder.rgba).toSet().length,
      greaterThan(32),
    );
  });

  test('native launch surfaces use the dark double-arrow branding', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final nativeGenerator = File(
      'flutter_launcher_icons_native.yaml',
    ).readAsStringSync();
    final androidLaunch = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final androidLaunchV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();
    final launchColors = File(
      'android/app/src/main/res/values/mort_launch_colors.xml',
    ).readAsStringSync();
    final storyboard = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();

    expect(androidLaunch, contains('@drawable/ic_launcher_foreground'));
    expect(androidLaunch, contains('@color/mort_launch_background'));
    expect(androidLaunch, isNot(contains('android:drawable="#050914"')));
    expect(androidLaunch, isNot(contains('@mipmap/ic_launcher')));
    expect(androidLaunch, isNot(contains('color/white')));
    expect(androidLaunchV21, contains('@drawable/ic_launcher_foreground'));
    expect(androidLaunchV21, contains('@color/mort_launch_background'));
    expect(
      androidLaunchV21,
      isNot(contains('android:drawable="#050914"')),
    );
    expect(androidLaunchV21, isNot(contains('@mipmap/ic_launcher')));
    expect(
      pubspec,
      contains('image_path: assets/branding/mort_logo_silver_double_arrow.png'),
    );
    expect(
      nativeGenerator,
      contains('image_path: assets/branding/mort_logo_silver_double_arrow.png'),
    );
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, isNot(contains('red="1" green="1" blue="1"')));
    expect(
      sha256
          .convert(
            File(
              'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
            ).readAsBytesSync(),
          )
          .toString(),
      sourceHash,
    );

    for (final path in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final api31Styles = File(path).readAsStringSync();
      expect(api31Styles, contains('windowSplashScreenBackground'));
      expect(api31Styles, contains('#050914'));
      expect(api31Styles, contains('windowSplashScreenAnimatedIcon'));
    }

    final adaptiveIcon = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptiveIcon, isNot(contains('<monochrome>')));
    expect(launchColors, contains('name="mort_launch_background"'));
    expect(launchColors, contains('#050914'));
  });

  test('generated launcher icons are dark and contain non-rose-gold art', () {
    final iconPaths = [
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    ];

    for (final path in iconPaths) {
      final icon = image.decodePng(File(path).readAsBytesSync());
      expect(icon, isNotNull, reason: path);
      final pixels = icon!.getBytes(order: image.ChannelOrder.rgba);
      var darkPixels = 0;
      var silverPixels = 0;
      var roseGoldPixels = 0;
      for (var index = 0; index < pixels.length; index += 4) {
        final red = pixels[index];
        final green = pixels[index + 1];
        final blue = pixels[index + 2];
        if (red < 48 && green < 48 && blue < 64) darkPixels++;
        if (red > 120 && green > 120 && blue > 120 && (red - blue).abs() < 35)
          silverPixels++;
        if (red > 120 && green > 65 && green < red && blue < green) {
          roseGoldPixels++;
        }
      }
      expect(
        darkPixels,
        greaterThan(icon.width * icon.height ~/ 4),
        reason: path,
      );
      expect(silverPixels, greaterThan(0), reason: path);
      expect(
        roseGoldPixels,
        lessThan(icon.width * icon.height ~/ 100),
        reason: path,
      );
    }
  });
}
