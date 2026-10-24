import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Writes error-level logs to a file with automatic rotation.
///
/// Log files are stored in the app's documents directory under `logs/`:
/// - `app.log`     — current log (max [_maxSize] bytes)
/// - `app.log.old` — previous log after rotation
///
/// Call [init] once during app startup before using the logger.
class FileLogOutput extends LogOutput {
  static const _maxSize = 2 * 1024 * 1024; // 2 MB
  static const _fileName = 'keestone-error.log';

  final Level _minLevel;
  IOSink? _sink;
  File? _file;

  /// Buffered events written before [init] completes.
  final List<OutputEvent> _buffer = [];
  static const _maxBufferSize = 100;
  bool _ready = false;
  bool _initFailed = false;

  FileLogOutput({this._minLevel = Level.error});

  /// Initializes the log file. Must be called once before any log output.
  @override
  Future<void> init() async {
    try {
      final dir = await _logDir();
      _file = File('${dir.path}/$_fileName');
      await _rotateIfNeeded();
      _sink = _file!.openWrite(mode: FileMode.append);
      _ready = true;
      // Flush buffered events.
      for (final event in _buffer) {
        _writeEvent(event);
      }
      _buffer.clear();
      // Write a startup marker so we know the log is working.
      _sink?.writeln(
        '${DateTime.now()} [INFO] FileLogOutput initialized, path=${_file?.path}',
      );
      unawaited(_sink?.flush());
    } catch (_) {
      // If file init fails, stop buffering to avoid unbounded memory growth.
      _initFailed = true;
      _buffer.clear();
    }
  }

  @override
  void output(OutputEvent event) {
    if (event.level.index < _minLevel.index) return;

    if (!_ready) {
      if (_initFailed) return;
      if (_buffer.length < _maxBufferSize) {
        _buffer.add(event);
      }
      return;
    }
    _writeEvent(event);
  }

  void _writeEvent(OutputEvent event) {
    final sink = _sink;
    if (sink == null) return;
    for (final line in event.lines) {
      sink.writeln(line);
    }
    sink.flush();
  }

  Future<Directory> _logDir() async {
    final String base;
    if (Platform.isLinux) {
      // Use XDG_DATA_HOME (~/.local/share) directly to avoid APPLICATION_ID prefix.
      final xdg = Platform.environment['XDG_DATA_HOME'];
      base = xdg ?? '${Platform.environment['HOME']}/.local/share/keestone';
    } else if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      base = ext?.path ?? (await getApplicationSupportDirectory()).path;
    } else {
      base = (await getApplicationSupportDirectory()).path;
    }
    final logDir = Directory('$base/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  Future<void> _rotateIfNeeded() async {
    final f = _file;
    if (f == null || !await f.exists()) return;
    final size = await f.length();
    if (size < _maxSize) return;

    final oldFile = File('${f.parent.path}/$_fileName.old');
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
    await f.rename(oldFile.path);
    _file = File('${f.parent.path}/$_fileName');
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
