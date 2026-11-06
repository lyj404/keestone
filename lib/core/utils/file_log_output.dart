import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Writes warn/error-level logs to files with rolling rotation.
///
/// Log files live in a per-platform user-visible directory (see [_logDir])
/// under `logs/`:
/// - `keestone-error.log`      — current log (rotates at [_maxFileBytes])
/// - `keestone-error.log.1..4` — older generations
///
/// At most [_maxGenerations] files of [_maxFileBytes] each are kept, so the
/// total on-disk footprint never exceeds 10 MB.
///
/// Call [init] once during app startup before using the logger.
class FileLogOutput extends LogOutput {
  static const _maxFileBytes = 2 * 1024 * 1024; // 2 MB per file
  static const _maxGenerations = 5; // 5 files -> 10 MB total
  static const _fileName = 'keestone-error.log';

  final Level _minLevel;
  IOSink? _sink;
  File? _file;

  /// Bytes already written to [_file]; avoids a stat() on every log call.
  int _bytesWritten = 0;

  /// IOSink forbids both a second flush and any writeln while a flush is in
  /// flight, so flushes are serialized through [_pendingFlush] and writes that
  /// arrive mid-flush are queued in [_queue] and replayed afterwards.
  Future<void> _pendingFlush = Future<void>.value();
  bool _flushInFlight = false;

  /// Events queued while the sink is not writable (mid-flush, pre-init or
  /// mid-rotation).
  final List<OutputEvent> _queue = [];
  static const _maxQueueSize = 100;
  bool _rotating = false;
  Future<void>? _rotationFuture;
  bool _ready = false;
  bool _initFailed = false;

  FileLogOutput({this._minLevel = Level.error});

  /// Test hook: overrides the platform base directory for logs, so tests can
  /// redirect output to a temp directory instead of the real Documents folder.
  static Future<Directory> Function()? baseDirOverride;

  /// Log directory for the current platform, created on demand.
  Future<Directory> logDirectory() => _logDir();

  /// All log files that currently exist, newest first.
  Future<List<File>> collectLogFiles() async {
    try {
      final dir = await _logDir();
      final files = <File>[];
      for (var i = 0; i < _maxGenerations; i++) {
        final name = i == 0 ? _fileName : '$_fileName.$i';
        final f = File('${dir.path}/$name');
        if (await f.exists()) files.add(f);
      }
      return files;
    } catch (_) {
      return const [];
    }
  }

  /// Waits until everything written so far is on disk (no flush or rotation
  /// in flight). Call before reading the log files back, e.g. on export.
  Future<void> flush() async {
    while (_flushInFlight || _rotating) {
      await _pendingFlush;
      await _rotationFuture;
    }
    // Cover data written outside a flush cycle (e.g. the init marker).
    await _sink?.flush();
  }

  @override
  void output(OutputEvent event) {
    if (event.level.index < _minLevel.index) return;

    if (!_ready) {
      if (_initFailed) return;
      if (_queue.length < _maxQueueSize) {
        _queue.add(event);
      }
      return;
    }
    // The sink rejects writes while a flush is in flight or mid-rotation;
    // queue the event and replay it once the sink is writable again.
    if (_flushInFlight || _rotating) {
      _queue.add(event);
      return;
    }
    _writeLines(event);
    if (_bytesWritten >= _maxFileBytes) {
      _startRotate();
      return;
    }
    _scheduleFlush();
  }

  /// Serializes IOSink flushes and replays queued events afterwards.
  /// Never throws: log persistence is best-effort.
  void _scheduleFlush() {
    if (_flushInFlight) return;
    _flushInFlight = true;
    _pendingFlush = Future<void>.sync(() => _sink?.flush())
        .catchError((_) {})
        .whenComplete(() {
          _flushInFlight = false;
          if (_queue.isNotEmpty && !_rotating) _drainQueue();
        });
  }

  /// Writes queued events while under the size cap, then either flushes them
  /// or starts a rotation; the rotation's completion drains what is left.
  void _drainQueue() {
    var wrote = false;
    while (_queue.isNotEmpty && _bytesWritten < _maxFileBytes) {
      _writeLines(_queue.removeAt(0));
      wrote = true;
    }
    if (_bytesWritten >= _maxFileBytes) {
      _startRotate();
      return;
    }
    if (wrote) _scheduleFlush();
  }

  void _writeLines(OutputEvent event) {
    final sink = _sink;
    if (sink == null) return;
    for (final line in event.lines) {
      sink.writeln(line);
      _bytesWritten += line.length + 1;
    }
  }

  void _startRotate() {
    if (_rotating) return;
    _rotating = true;
    _rotationFuture = _rotate().whenComplete(_drainQueue);
  }

  /// Close the current file and shift generations so the oldest is deleted,
  /// keeping at most [_maxGenerations] × [_maxFileBytes] bytes on disk.
  Future<void> _rotate() async {
    try {
      final dir = _file!.parent;
      try {
        await _pendingFlush;
        await _sink?.flush();
        await _sink?.close();
      } catch (_) {}
      _sink = null;
      _pendingFlush = Future<void>.value();

      try {
        // _maxGenerations counts the current file: log + .1..(n-1). The
        // oldest generation (n-1) is deleted, the rest shift up by one.
        final oldestIndex = _maxGenerations - 1;
        final oldest = File('${dir.path}/$_fileName.$oldestIndex');
        if (await oldest.exists()) await oldest.delete();
        for (var i = oldestIndex - 1; i >= 1; i--) {
          final src = File('${dir.path}/$_fileName.$i');
          if (await src.exists()) {
            await src.rename('${dir.path}/$_fileName.${i + 1}');
          }
        }
        await _file!.rename('${dir.path}/$_fileName.1');
      } catch (_) {
        // Rotation is best-effort; reopening below still lets logging continue.
      }

      _file = File('${dir.path}/$_fileName');
      _bytesWritten = 0;
      _sink = _file!.openWrite(mode: FileMode.append);
    } catch (_) {
      _ready = false;
    } finally {
      _rotating = false;
    }
  }

  /// Pre-10MB scheme kept a single `.old` file; remove it if present.
  void _removeLegacyOldFile(Directory dir) {
    final legacy = File('${dir.path}/$_fileName.old');
    if (legacy.existsSync()) {
      try {
        legacy.deleteSync();
      } catch (_) {}
    }
  }

  Future<Directory> _logDir() async {
    String base;
    final override = baseDirOverride;
    if (override != null) {
      // Test hook redirects only the base directory; the logs/ subdir below
      // is shared with the platform logic.
      base = (await override()).path;
    } else if (Platform.isAndroid) {
      // App-private external storage: the only Android location a user can
      // reach without root (internal app_flutter/ is hidden behind Android/data).
      final ext = await getExternalStorageDirectory();
      base = ext?.path ?? (await getApplicationDocumentsDirectory()).path;
    } else {
      // Windows/Linux/macOS: the user's Documents folder, directly visible.
      // macOS is sandboxed, so this resolves to the app container's Documents.
      base = (await getApplicationDocumentsDirectory()).path;
    }
    // App-named subdir keeps the Documents folder tidy; on Android the base
    // is already app-scoped, the subdir just keeps parity across platforms.
    final logDir = Directory('$base/KeeStone/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  /// Initializes the log file. Must be called once before any log output.
  @override
  Future<void> init() async {
    try {
      final dir = await _logDir();
      _file = File('${dir.path}/$_fileName');
      _bytesWritten = await _file!.exists() ? await _file!.length() : 0;
      _removeLegacyOldFile(dir);
      _sink = _file!.openWrite(mode: FileMode.append);
      _ready = true;
      // Replay events queued before init, then write a startup marker so we
      // know the log is working.
      _drainQueue();
      _sink?.writeln(
        '${DateTime.now()} [INFO] FileLogOutput initialized, path=${_file?.path}',
      );
      // flush() (not _sink.flush()): _drainQueue may have scheduled a flush.
      await flush();
    } catch (_) {
      // If file init fails, stop buffering to avoid unbounded memory growth.
      _initFailed = true;
      _queue.clear();
    }
  }

  @override
  Future<void> destroy() async {
    try {
      await flush();
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // Already closing/closed (e.g. mid-rotation); nothing to recover.
    }
    _sink = null;
  }
}
