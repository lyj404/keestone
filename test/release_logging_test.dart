import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/utils/file_log_output.dart';
import 'package:keestone/core/utils/logger.dart';

void main() {
  test('application logger writes errors and stack traces to file', () async {
    final dir = await Directory.systemTemp.createTemp('keestone_logger');
    FileLogOutput.baseDirOverride = () async => dir;
    try {
      await log.init;
      log.e(
        'diagnostic failure',
        error: StateError('test error'),
        stackTrace: StackTrace.fromString('diagnostic stack'),
      );
      await fileLogOutput.flush();
      final content = await File('${dir.path}/KeeStone/logs/keestone-error.log')
          .readAsString();
      expect(content, contains('diagnostic failure'));
      expect(content, contains('test error'));
      expect(content, contains('diagnostic stack'));
    } finally {
      await log.close();
      FileLogOutput.baseDirOverride = null;
      await dir.delete(recursive: true);
    }
  });
}
