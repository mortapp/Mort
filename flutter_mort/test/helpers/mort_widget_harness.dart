import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs a widget contract with the Windows Material defaults used by the
/// desktop test renderer. Production keeps its platform-specific theme.
void testMortWidgets(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  dynamic tags,
  int? retry,
}) {
  testWidgets(
    description,
    callback,
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    tags: tags,
    retry: retry,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

/// Keeps visual tests faithful to the MORT color and typography theme while
/// selecting a shader-free splash implementation for the desktop test engine.
ThemeData mortTestTheme(ThemeData theme) {
  return theme.copyWith(splashFactory: InkRipple.splashFactory);
}
