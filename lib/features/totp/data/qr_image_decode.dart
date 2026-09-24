import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/zxing.dart';

import '../../../core/utils/logger.dart';

/// Outcome of decoding a QR image for TOTP setup.
enum QrImageDecodeStatus {
  /// Found an `otpauth://` URI ([QrImageDecodeResult.uri] is set).
  success,

  /// Image bytes could not be parsed, or no barcode was found.
  noQrCode,

  /// A barcode was found but its payload is not a TOTP `otpauth://` URI.
  notOtpAuth,

  /// Unexpected decoder/IO failure.
  error,
}

class QrImageDecodeResult {
  final QrImageDecodeStatus status;
  final String? uri;

  const QrImageDecodeResult._(this.status, [this.uri]);

  const QrImageDecodeResult.success(String uri)
    : this._(QrImageDecodeStatus.success, uri);

  const QrImageDecodeResult.noQrCode() : this._(QrImageDecodeStatus.noQrCode);

  const QrImageDecodeResult.notOtpAuth()
    : this._(QrImageDecodeStatus.notOtpAuth);

  const QrImageDecodeResult.error() : this._(QrImageDecodeStatus.error);
}

/// Decodes QR images (PNG/JPEG/WebP bytes) into TOTP `otpauth://` URIs.
///
/// Used on desktop platforms where `mobile_scanner.analyzeImage` is not
/// available. Pure Dart (`image` + `zxing_lib`), so it works on Windows, Linux,
/// and macOS without a camera plugin.
class QrImageDecode {
  QrImageDecode._();

  /// Accepts `otpauth://` TOTP or HOTP. Rejects other schemes so a random QR
  /// never becomes a vault field or an auto-opened link.
  static bool isOtpAuthUri(String text) {
    final value = text.trim().toLowerCase();
    return value.startsWith('otpauth://totp/') ||
        value.startsWith('otpauth://hotp/');
  }

  static Future<QrImageDecodeResult> decodeOtpAuthFromBytes(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) return const QrImageDecodeResult.noQrCode();
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return const QrImageDecodeResult.noQrCode();
      final text = _decodeQrText(decoded);
      if (text == null || text.isEmpty) {
        return const QrImageDecodeResult.noQrCode();
      }
      if (!isOtpAuthUri(text)) {
        return const QrImageDecodeResult.notOtpAuth();
      }
      return QrImageDecodeResult.success(text);
    } catch (e, st) {
      log.w('QR image decode failed', error: e, stackTrace: st);
      return const QrImageDecodeResult.error();
    }
  }

  static Future<QrImageDecodeResult> decodeOtpAuthFromFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return await decodeOtpAuthFromBytes(bytes);
    } catch (e, st) {
      log.w('QR image read failed: $path', error: e, stackTrace: st);
      return const QrImageDecodeResult.error();
    }
  }

  static String? _decodeQrText(img.Image image) {
    final width = image.width;
    final height = image.height;
    final luminances = Uint8List(width * height);

    // Build a single-channel luminance matrix (1 byte / pixel) for zxing.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        luminances[y * width + x] = RGBLuminanceSource.getLuminance(
          p.r.toInt(),
          p.g.toInt(),
          p.b.toInt(),
        );
      }
    }

    final source = RGBLuminanceSource.orig(width, height, luminances);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = MultiFormatReader();
    final hints = DecodeHint(
      possibleFormats: const [BarcodeFormat.qrCode],
      tryHarder: true,
      alsoInverted: true,
      pureBarcode: false,
    );

    try {
      return reader.decode(bitmap, hints).text;
    } on NotFoundException {
      // Retry with inverted polarity (light-on-dark screenshots).
      try {
        return reader
            .decode(
              BinaryBitmap(HybridBinarizer(source.invert())),
              DecodeHint(
                possibleFormats: const [BarcodeFormat.qrCode],
                tryHarder: true,
                alsoInverted: true,
              ),
            )
            .text;
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}
