import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

import 'qr_scan_mobile.dart' as mobile;
import 'qr_scan_stub.dart' as stub;

/// Camera-based QR scanning is only wired for mobile. Desktop platforms get
/// the stub (no camera) even though `dart.library.io` is true there.
bool get _useMobileScanner =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

Future<String?> openQrScanner(BuildContext context) {
  if (_useMobileScanner) return mobile.openQrScanner(context);
  return stub.openQrScanner(context);
}
