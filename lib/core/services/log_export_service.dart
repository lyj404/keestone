import 'package:share_plus/share_plus.dart';

import '../utils/logger.dart';

/// Exports the rolling log files via the platform share sheet.
///
/// Used on platforms where the log directory is not directly reachable by the
/// user (macOS sandbox container, Android app-private external storage).
class LogExportService {
  LogExportService._();

  /// Returns true when the share sheet was invoked with at least one file and
  /// the user completed the share.
  static Future<bool> export() async {
    await fileLogOutput.flush();
    final files = await fileLogOutput.collectLogFiles();
    if (files.isEmpty) return false;

    final result = await SharePlus.instance.share(
      ShareParams(files: [for (final f in files) XFile(f.path)]),
    );
    return result.status == ShareResultStatus.success;
  }
}
