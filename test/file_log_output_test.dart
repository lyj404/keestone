import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/utils/file_log_output.dart';
import 'package:logger/logger.dart';

/// Tests for the file log output: level filtering, rotation, size cap and
/// legacy cleanup. Redirected to a temp dir via [FileLogOutput.baseDirOverride].
void main() {
  late Directory tempBase;
  late FileLogOutput output;

  setUp(() async {
    tempBase = await Directory.systemTemp.createTemp('keestone_log_test');
    FileLogOutput.baseDirOverride = () async => tempBase;
    output = FileLogOutput(minLevel: Level.warning);
  });

  tearDown(() async {
    await output.destroy();
    FileLogOutput.baseDirOverride = null;
    await tempBase.delete(recursive: true);
  });

  test('init creates the log directory and writes a startup marker', () async {
    await output.init();

    final logFile = File('${tempBase.path}/KeeStone/logs/keestone-error.log');
    expect(logFile.existsSync(), isTrue);
    expect(logFile.readAsStringSync(), contains('FileLogOutput initialized'));
  });

  test('writes warning and error events, filters lower levels', () async {
    await output.init();
    output.output(OutputEvent(LogEvent(Level.info, 'info line'), ['info line']));
    output.output(
      OutputEvent(LogEvent(Level.warning, 'warn line'), ['warn line']),
    );
    output.output(
      OutputEvent(LogEvent(Level.error, 'error line'), ['error line']),
    );
    await output.flush();

    final content = File(
      '${tempBase.path}/KeeStone/logs/keestone-error.log',
    ).readAsStringSync();
    expect(content, contains('warn line'));
    expect(content, contains('error line'));
    expect(content, isNot(contains('info line')));
  });

  test('removes the legacy single-.old log file on init', () async {
    final logDir = Directory('${tempBase.path}/KeeStone/logs')
      ..createSync(recursive: true);
    File('${logDir.path}/keestone-error.log.old').writeAsStringSync('legacy');

    await output.init();

    expect(File('${logDir.path}/keestone-error.log.old').existsSync(), isFalse);
  });

  test('collectLogFiles lists generations newest first', () async {
    await output.init();
    final logDir = Directory('${tempBase.path}/KeeStone/logs');
    File('${logDir.path}/keestone-error.log.1').writeAsStringSync('gen1');
    File('${logDir.path}/keestone-error.log.2').writeAsStringSync('gen2');

    final files = await output.collectLogFiles();

    expect(files.length, 3);
    expect(files[0].path, endsWith('keestone-error.log'));
    expect(files[1].path, endsWith('keestone-error.log.1'));
    expect(files[2].path, endsWith('keestone-error.log.2'));
  });

  test('rotates generations and keeps total size capped', () async {
    await output.init();

    // 4 KB per event; enough total volume to force ~7 rotations, which is
    // more than the 5 allowed generations so the oldest must be deleted.
    final chunk = 'x' * 4096;
    for (var i = 0; i < 3300; i++) {
      output.output(OutputEvent(LogEvent(Level.error, chunk), [chunk]));
    }
    // flush() waits for all pending flushes and rotation cycles.
    await output.flush();

    final logDir = Directory('${tempBase.path}/KeeStone/logs');
    // Exactly the 5 generations remain; nothing beyond .4.
    expect(File('${logDir.path}/keestone-error.log.5').existsSync(), isFalse);

    final files = await output.collectLogFiles();
    expect(files.length, 5);

    // 5 × 2 MB cap, plus one event of overshoot and the startup marker.
    final total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
    expect(total, lessThan(10 * 1024 * 1024 + 100 * 1024));
  });
}
