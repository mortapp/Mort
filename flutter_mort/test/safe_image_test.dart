import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_mort/core/utils/image_decode_limits.dart';
import 'package:flutter_mort/core/utils/safe_image.dart';

void main() {
  group('image decode dimensions', () {
    test('allows ordinary and supported high resolution phone photos', () {
      expect(imageDimensionsWithinDecodeLimits(4032, 3024), isTrue);
    });

    test('rejects excessive pixels and either oversized axis safely', () {
      expect(imageDimensionsWithinDecodeLimits(6001, 4000), isFalse);
      expect(imageDimensionsWithinDecodeLimits(1, 12001), isFalse);
      expect(imageDimensionsWithinDecodeLimits(0, 100), isFalse);
    });

    test('rejects oversized PNG before allocating decoded pixels', () {
      final encoded = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      // Preserve the valid PNG structure while declaring a very large canvas.
      _writeBigEndianUint32(encoded, 16, 100000);
      _writeBigEndianUint32(encoded, 20, 100000);
      _writeBigEndianUint32(encoded, 29, _pngIhdrCrc(encoded));

      expect(
        () => SafeImageProcessor.proof(encoded, maximumBytes: 1024 * 1024),
        throwsA(
          isA<MortCodedError>().having(
            (error) => error.code,
            'code',
            'proof_image_dimensions_invalid',
          ),
        ),
      );
    });

    test('keeps normal proof and avatar image processing compatible', () {
      final source = img.Image(width: 2400, height: 1200)
        ..clear(img.ColorRgb8(30, 90, 210));
      final proof = img.decodeJpg(
        SafeImageProcessor.proof(
          Uint8List.fromList(img.encodePng(source)),
          maximumBytes: 1024 * 1024,
        ),
      );
      final avatar = img.decodeJpg(
        SafeImageProcessor.avatar(
          Uint8List.fromList(img.encodePng(source)),
          maximumBytes: 1024 * 1024,
        ),
      );

      expect(proof?.width, 1600);
      expect(proof?.height, 800);
      expect(avatar?.width, 512);
      expect(avatar?.height, 512);
    });
  });
}

void _writeBigEndianUint32(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xff;
  bytes[offset + 1] = (value >> 16) & 0xff;
  bytes[offset + 2] = (value >> 8) & 0xff;
  bytes[offset + 3] = value & 0xff;
}

int _pngIhdrCrc(Uint8List png) {
  var crc = 0xffffffff;
  for (var index = 12; index < 29; index++) {
    crc ^= png[index];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
