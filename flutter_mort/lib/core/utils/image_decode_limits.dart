const int maximumImageDimension = 12000;
const int maximumImageDecodePixels = 24000000;

bool imageDimensionsWithinDecodeLimits(
  int width,
  int height, {
  int maximumPixels = maximumImageDecodePixels,
}) {
  if (width <= 0 || height <= 0 || maximumPixels <= 0) return false;
  if (width > maximumImageDimension || height > maximumImageDimension) {
    return false;
  }
  return width <= maximumPixels ~/ height;
}
