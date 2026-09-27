import 'dart:typed_data';
import 'package:flutter_mort/core/utils/safe_image.dart';
import 'package:flutter_mort/core/errors/mort_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Small evidence image remains usable after metadata stripping', () {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    );
    final result = SafeImageProcessor.proof(source, maximumBytes: 100000);
    expect(img.decodeJpg(result)?.width, 2);
  });
  test('Oversized evidence dimensions are rejected before pixel decoding', () {
    final source = Uint8List.fromList(
      img.encodePng(img.Image(width: 2, height: 2)),
    );
    ByteData.sublistView(source).setUint32(16, 20000);
    var crc = 0xffffffff;
    for (final byte in source.sublist(12, 29)) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    ByteData.sublistView(source).setUint32(29, crc ^ 0xffffffff);
    expect(
      () => SafeImageProcessor.proof(source, maximumBytes: 100000),
      throwsA(
        isA<MortCodedError>().having(
          (e) => e.code,
          'code',
          'proof_file_size_invalid',
        ),
      ),
    );
  });
}
