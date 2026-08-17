import 'package:flutter/widgets.dart';

int boundedImageDecodePixels({
  required double logicalPixels,
  required double devicePixelRatio,
  int minimum = 1,
  int maximum = 2048,
}) {
  assert(minimum > 0);
  assert(maximum >= minimum);
  final safeLogicalPixels = logicalPixels.isFinite && logicalPixels > 0
      ? logicalPixels
      : minimum.toDouble();
  final safeDevicePixelRatio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return (safeLogicalPixels * safeDevicePixelRatio).ceil().clamp(
    minimum,
    maximum,
  );
}

int imageDecodePixelsForContext(
  BuildContext context,
  double logicalPixels, {
  int minimum = 1,
  int maximum = 2048,
}) {
  return boundedImageDecodePixels(
    logicalPixels: logicalPixels,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    minimum: minimum,
    maximum: maximum,
  );
}
