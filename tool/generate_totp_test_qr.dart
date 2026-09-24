// Generates a sample otpauth:// QR PNG for manual desktop testing.
// Usage: dart run tool/generate_totp_test_qr.dart [output.png]
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

const sampleUri =
    'otpauth://totp/KeeStone:demo@example.com'
    '?secret=JBSWY3DPEHPK3PXP&issuer=KeeStone&algorithm=SHA1&digits=6&period=30';

void main(List<String> args) {
  final outPath = args.isNotEmpty
      ? args.first
      : 'test/fixtures/sample_totp_qr.png';

  final qr = QrCode(
    payload: QrPayload.fromString(sampleUri),
    errorCorrectLevel: QrErrorCorrectLevel.medium,
  );
  final qrImage = QrImage(qr);
  const scale = 10;
  const quiet = 6;
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

  final file = File(outPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote $outPath ($sampleUri)');
}
