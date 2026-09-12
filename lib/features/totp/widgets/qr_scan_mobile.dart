import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../l10n/app_localizations.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _scannerCtrl = MobileScannerController();
  final _picker = ImagePicker();
  bool _closing = false;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish(String value) async {
    if (_closing || !mounted) return;
    _closing = true;
    try {
      await _scannerCtrl.stop();
    } catch (_) {
      // The camera may already have stopped while this route is closing.
    }
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_closing) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.startsWith('otpauth://')) {
        _finish(value);
        return;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    try {
      final result = await _scannerCtrl.analyzeImage(picked.path);
      for (final barcode in result?.barcodes ?? []) {
        final value = barcode.rawValue;
        if (value != null && value.startsWith('otpauth://')) {
          await _finish(value);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.totpInvalidUri)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.totpInvalidUri)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQrCode),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerCtrl,
            builder: (context, state, child) {
              final isOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                tooltip: l10n.toggleFlashlight,
                onPressed: _closing ? null : () => _scannerCtrl.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: l10n.switchCamera,
            onPressed: _closing ? null : () => _scannerCtrl.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerCtrl,
              onDetect: _onDetectBarcode,
              errorBuilder: (context, error) {
                return ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      error.errorDetails?.message ?? 'Camera unavailable',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.scanQrHint,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black54,
              onPressed: _closing ? null : _pickFromGallery,
              child: const Icon(
                Icons.photo_library_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> openQrScanner(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute(builder: (_) => const QrScanScreen()),
  );
}