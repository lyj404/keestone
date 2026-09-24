import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:keestone/features/totp/data/qr_image_decode.dart';
import 'package:qr/qr.dart';

const _sampleUri =
    'otpauth://totp/KeeStone:demo@example.com'
    '?secret=JBSWY3DPEHPK3PXP&issuer=KeeStone&algorithm=SHA1&digits=6&period=30';

Uint8List _encodeQrPng(String payload, {int scale = 10, int quiet = 6}) {
  final qr = QrCode(
    payload: QrPayload.fromString(payload),
    errorCorrectLevel: QrErrorCorrectLevel.medium,
  );
  final qrImage = QrImage(qr);
  final modules = qrImage.moduleCount;
  final size = (modules + quiet * 2) * scale;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var row = 0; row < modules; row++) {
    for (var col = 0; col < modules; col++) {
      final dark = qrImage.isDark(row, col);
      final x0 = (col + quiet) * scale;
      final y0 = (row + quiet) * scale;
      final color = dark
          ? img.ColorRgb8(0, 0, 0)
          : img.ColorRgb8(255, 255, 255);
      for (var y = 0; y < scale; y++) {
        for (var x = 0; x < scale; x++) {
          image.setPixelRgb(x0 + x, y0 + y, color.r, color.g, color.b);
        }
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('QrImageDecode', () {
    test('decodes otpauth:// from a generated QR PNG', () async {
      final bytes = _encodeQrPng(_sampleUri);
      final result = await QrImageDecode.decodeOtpAuthFromBytes(bytes);
      expect(result.status, QrImageDecodeStatus.success);
      expect(result.uri, _sampleUri);
    });

    test('rejects non-otpauth QR payloads', () async {
      final bytes = _encodeQrPng('https://example.com');
      final result = await QrImageDecode.decodeOtpAuthFromBytes(bytes);
      expect(result.status, QrImageDecodeStatus.notOtpAuth);
      expect(result.uri, isNull);
    });

    test('reports noQrCode for non-image or blank bytes', () async {
      final result = await QrImageDecode.decodeOtpAuthFromBytes(
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(
        result.status,
        anyOf(QrImageDecodeStatus.noQrCode, QrImageDecodeStatus.error),
      );
    });

    test('accepts only otpauth totp/hotp schemes', () {
      expect(QrImageDecode.isOtpAuthUri(_sampleUri), isTrue);
      expect(
        QrImageDecode.isOtpAuthUri('otpauth://hotp/Example?secret=ABC'),
        isTrue,
      );
      expect(QrImageDecode.isOtpAuthUri('https://example.com'), isFalse);
      expect(QrImageDecode.isOtpAuthUri('otpauth://foo/bar'), isFalse);
    });

    test('fixture PNG on disk decodes when present', () async {
      final file = File('test/fixtures/sample_totp_qr.png');
      if (!file.existsSync()) return;
      final result = await QrImageDecode.decodeOtpAuthFromFile(file.path);
      expect(result.status, QrImageDecodeStatus.success);
      expect(result.uri, contains('otpauth://totp/'));
      expect(result.uri, contains('secret=JBSWY3DPEHPK3PXP'));
    });
  });
}
