import 'package:logger/logger.dart';

import 'file_log_output.dart';

/// File-based log output — captures warnings and errors.
/// Call [fileLogOutput.init()] during app startup.
final fileLogOutput = FileLogOutput(minLevel: Level.warning);

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  output: MultiOutput([ConsoleOutput(), fileLogOutput]),
);
