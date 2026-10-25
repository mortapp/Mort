import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../errors/mort_error.dart';
import 'image_decode_limits.dart';

class SafeImageProcessor {
  const SafeImageProcessor._();

  static Uint8List avatar(Uint8List source, {required int maximumBytes}) {
    final decoded = _decode(
      source,
      maximumBytes: maximumBytes,
      maximumPixels: 16000000,
      sizeCode: 'avatar_file_size_invalid',
      typeCode: 'avatar_file_type_invalid',
      dimensionsCode: 'avatar_image_dimensions_invalid',
      sizeMessage: 'Choose a JPEG, PNG, or WebP image smaller than 5 MB.',
    );
    final oriented = img.bakeOrientation(decoded);
    final side = oriented.width < oriented.height
        ? oriented.width
        : oriented.height;
    final square = img.copyCrop(
      oriented,
      x: (oriented.width - side) ~/ 2,
      y: (oriented.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(
      square,
      width: 512,
      height: 512,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  static Uint8List proof(Uint8List source, {required int maximumBytes}) {
    final decoded = _decode(
      source,
      maximumBytes: maximumBytes,
      maximumPixels: maximumImageDecodePixels,
      sizeCode: 'proof_file_size_invalid',
      typeCode: 'proof_file_type_invalid',
      dimensionsCode: 'proof_image_dimensions_invalid',
      sizeMessage: 'Choose a JPEG, PNG, or WebP image smaller than 10 MB.',
    );
    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longestSide <= 1600
        ? oriented
        : oriented.width >= oriented.height
        ? img.copyResize(
            oriented,
            width: 1600,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            oriented,
            height: 1600,
            interpolation: img.Interpolation.average,
          );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  static Uint8List verification(Uint8List source, {required int maximumBytes}) {
    final decoded = _decode(
      source,
      maximumBytes: maximumBytes,
      maximumPixels: maximumImageDecodePixels,
      sizeCode: 'verification_file_size_invalid',
      typeCode: 'verification_file_type_invalid',
      dimensionsCode: 'verification_image_dimensions_invalid',
      sizeMessage:
          'Choose a JPEG, PNG, or WebP verification image smaller than 10 MB.',
    );
    final oriented = img.bakeOrientation(decoded);
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longestSide <= 2000
        ? oriented
        : oriented.width >= oriented.height
        ? img.copyResize(
            oriented,
            width: 2000,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            oriented,
            height: 2000,
            interpolation: img.Interpolation.average,
          );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 86));
  }

  static img.Image _decode(
    Uint8List source, {
    required int maximumBytes,
    required int maximumPixels,
    required String sizeCode,
    required String typeCode,
    required String dimensionsCode,
    required String sizeMessage,
  }) {
    if (source.isEmpty || source.length > maximumBytes) {
      throw MortCodedError(sizeCode, sizeMessage);
    }
    if (!_hasSupportedSignature(source)) {
      throw MortCodedError(
        typeCode,
        'Choose a supported JPEG, PNG, or WebP image.',
      );
    }
    try {
      final decoder = _decoderFor(source);
      if (decoder == null) {
        throw MortCodedError(
          typeCode,
          'Choose a supported JPEG, PNG, or WebP image.',
        );
      }
      final info = decoder.startDecode(source);
      if (info == null ||
          !imageDimensionsWithinDecodeLimits(
            info.width,
            info.height,
            maximumPixels: maximumPixels,
          )) {
        throw MortCodedError(
          dimensionsCode,
          'Choose an image no larger than $maximumPixels pixels per image.',
        );
      }
      final decoded = decoder.decodeFrame(0);
      if (decoded != null) return decoded;
    } on MortCodedError {
      rethrow;
    } catch (_) {
      // Decoder details are intentionally normalized below.
    }
    throw MortCodedError(
      typeCode,
      'Choose a supported JPEG, PNG, or WebP image.',
    );
  }

  static img.Decoder? _decoderFor(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return img.JpegDecoder();
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return img.PngDecoder();
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return img.WebPDecoder();
    }
    return null;
  }

  static bool _hasSupportedSignature(Uint8List bytes) {
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final webp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
    return jpeg || png || webp;
  }
}
