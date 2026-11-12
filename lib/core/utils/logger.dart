import 'package:logger/logger.dart';

import 'file_log_output.dart';

/// File-based log output — captures info, warnings and errors so that
/// user-reported issues (e.g. keestone#2) come with enough context to
/// diagnose. Rotation keeps total size bounded (5 generations x 2 MB).
/// Call [fileLogOutput.init()] during app startup.
final fileLogOutput = FileLogOutput(minLevel: Level.info);

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  output: MultiOutput([ConsoleOutput(), fileLogOutput]),
);
