import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../data/qr_image_decode.dart';
import 'qr_scan_mobile.dart' as mobile;

/// Camera scanning is only wired for Android/iOS. Desktop uses static-image
/// decoding (`mobile_scanner` has no Windows/Linux implementation).
bool get useMobileQrScanner =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Opens the platform QR entrypoint and returns an `otpauth://` URI, or null
/// when the user cancels or nothing usable was found (errors are toasted).
Future<String?> openQrScanner(BuildContext context) {
  if (useMobileQrScanner) return mobile.openQrScanner(context);
  return openQrImageFromFilePicker(context);
}

/// Desktop: pick a QR screenshot/file, decode `otpauth://`, toast on failure.
Future<String?> openQrImageFromFilePicker(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
    );
  } catch (e, st) {
    log.w('QR image pick failed', error: e, stackTrace: st);
    if (context.mounted) _toast(context, l10n.totpQrNoCode);
    return null;
  }
  if (picked.isEmpty) return null;
  final path = picked.first.path;
  if (path == null || path.isEmpty) {
    if (context.mounted) _toast(context, l10n.totpQrNoCode);
    return null;
  }

  final result = await QrImageDecode.decodeOtpAuthFromFile(path);
  if (result.status == QrImageDecodeStatus.success) {
    return result.uri;
  }
  if (!context.mounted) return null;
  switch (result.status) {
    case QrImageDecodeStatus.noQrCode:
    case QrImageDecodeStatus.error:
      _toast(context, l10n.totpQrNoCode);
    case QrImageDecodeStatus.notOtpAuth:
      _toast(context, l10n.totpQrNotOtpAuth);
    case QrImageDecodeStatus.success:
      break;
  }
  return null;
}

void _toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
