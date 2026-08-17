import 'package:flutter_mort/core/utils/image_decode_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates physical decode pixels for ordinary displays', () {
    expect(
      boundedImageDecodePixels(
        logicalPixels: 96,
        devicePixelRatio: 3,
        maximum: 512,
      ),
      288,
    );
  });

  test('bounds very large source targets for lower-memory devices', () {
    expect(
      boundedImageDecodePixels(logicalPixels: 1440, devicePixelRatio: 4),
      2048,
    );
  });

  test('replaces non-finite and invalid dimensions with safe values', () {
    expect(
      boundedImageDecodePixels(
        logicalPixels: double.nan,
        devicePixelRatio: double.infinity,
        minimum: 16,
      ),
      16,
    );
    expect(
      boundedImageDecodePixels(
        logicalPixels: double.negativeInfinity,
        devicePixelRatio: -1,
      ),
      1,
    );
  });
}
