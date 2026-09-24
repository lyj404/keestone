import 'package:material_ui/material_ui.dart';

/// Web / non-IO stub. Camera and file-based QR decode are desktop+mobile only.
bool get useMobileQrScanner => false;

class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<String?> openQrScanner(BuildContext context) async => null;

Future<String?> openQrImageFromFilePicker(BuildContext context) async => null;
