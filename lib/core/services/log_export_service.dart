import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../utils/logger.dart';

/// Saves the current log file, in its original .log format, at a user-chosen
/// location via the system save dialog.
class LogExportService {
  LogExportService._();

  /// Returns true when the user picked a location and the log was written.
  static Future<bool> export() async {
    await fileLogOutput.flush();
    final files = await fileLogOutput.collectLogFiles();
    if (files.isEmpty) return false;

    // collectLogFiles is newest first; export the current generation.
    final bytes = Uint8List.fromList(await files.first.readAsBytes());

    // saveFile writes [bytes] to the chosen location itself (on desktop it
    // uses a portal/native dialog and returns a file URI).
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export Logs',
      fileName: 'keestone.log',
      mimeType: 'text/plain',
      bytes: bytes,
    );
    return result != null;
  }
}
