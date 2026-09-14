import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/crypto/crypto_service.dart';
import 'atomic_file_store.dart';
import '../../../core/utils/logger.dart';
import '../../backup/data/backup_service.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../sync/data/sync_service.dart';
import '../../totp/data/totp_service.dart';

/// Thrown when a KDBX file cannot be parsed due to corruption or bad format.
class DatabaseCorruptedException implements Exception {
  final Object original;
  DatabaseCorruptedException(this.original);

  @override
  String toString() => 'DatabaseCorruptedException: $original';
}

/// Returns true if the exception indicates a corrupt/invalid KDBX file.
bool isCorruptionError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('corrupt') ||
      msg.contains('bad version') ||
      msg.contains('invalid header') ||
      msg.contains('dataerror') ||
      msg.contains('format') && msg.contains('invalid') ||
      (e is InvalidCredentialsError == false &&
          msg.contains('invalid') &&
          msg.contains('key'));
}

/// Pre-computed lowercase text for an entry, used for fast search.

/// A search result with relevance score and match positions for highlighting.
class SearchResult {
  final KdbxEntry entry;
  final double score;
  final List<int> matchPositions;
  const SearchResult(this.entry, this.score, this.matchPositions);
}

class SyncAuditChange {
  final String type;
  final String title;
  final String? groupPath;
  final String? modifiedAt;
  final List<String> details;
  final Map<String, String> localValues;
  final Map<String, String> remoteValues;

  const SyncAuditChange({
    required this.type,
    required this.title,
    this.groupPath,
    this.modifiedAt,
    this.details = const [],
    this.localValues = const {},
    this.remoteValues = const {},
  });
}

class SyncAuditReport {
  final List<SyncAuditChange> localOnly;
  final List<SyncAuditChange> remoteOnly;
  final List<SyncAuditChange> modifiedBoth;

  const SyncAuditReport({
    required this.localOnly,
    required this.remoteOnly,
    required this.modifiedBoth,
  });

  bool get hasChanges =>
      localOnly.isNotEmpty || remoteOnly.isNotEmpty || modifiedBoth.isNotEmpty;
}

class _SearchRecord {
  final KdbxEntry entry;
  final String title;
  final String username;
  final String url;
  final String notes;
  final List<String> customFields;
  final List<String> tags;

  _SearchRecord(this.entry)
    : title = (entry.fields['Title']?.text ?? '').toLowerCase(),
      username = (entry.fields['UserName']?.text ?? '').toLowerCase(),
      url = (entry.fields['URL']?.text ?? '').toLowerCase(),
      notes = (entry.fields['Notes']?.text ?? '').toLowerCase(),
      customFields = entry.fields.entries
          .where(
            (e) => ![
              'Title',
              'UserName',
              'Password',
              'URL',
              'Notes',
            ].contains(e.key),
          )
          .map((e) => e.value.text.toLowerCase())
          .toList(),
      tags = (entry.tags ?? []).map((t) => t.toLowerCase()).toList();

  /// Returns the best fuzzy match score across all fields, or null if no match.
  FuzzyMatchResult? matchScore(String query) {
    final lowerQuery = query.toLowerCase();
    FuzzyMatchResult? best;

    void consider(String text) {
      final r = fuzzyMatch(text, lowerQuery);
      if (r != null && r.isMatch) {
        if (best == null || r.score > best!.score) best = r;
      }
    }

    // Primary fields
    consider(title);
    consider(username);
    consider(url);
    consider(notes);
    // Custom fields & tags
    for (final f in customFields) {
      consider(f);
    }
    for (final t in tags) {
      consider(t);
    }

    return best;
  }
}

class DatabaseService {
  final _backupService = BackupService();
  final _atomicFileStore = const AtomicFileStore();
  Future<void> _saveQueue = Future<void>.value();
  KdbxDatabase? _db;
  String? _filePath;
  String? _password;
  Uint8List? _keyData;
  bool _dirty = false;
  // Incremented on every markDirty so save() can detect mutations that
  // happened while serialization was running in the background isolate.
  int _mutationCount = 0;
  Uint8List? _preloadedBytes;
  String? _preloadedFilePath;
  DateTime? _preloadedModified;
  int? _preloadedSize;
  List<KdbxEntry>? _allEntriesCache;
  Map<String, KdbxEntry>? _entryByUuid;
  List<_SearchRecord>? _searchIndex;

  /// Last known remote file metadata, used for conflict detection.
  RemoteFileInfo? _lastSyncedRemoteInfo;
  RemoteFileInfo? get lastSyncedRemoteInfo => _lastSyncedRemoteInfo;
  void setLastSyncedRemoteInfo(RemoteFileInfo? info) =>
      _lastSyncedRemoteInfo = info;

  KdbxDatabase? get db => _db;
  String? get filePath => _filePath;
  bool get isOpen => _db != null;
  bool get isDirty => _dirty;
  bool get hasKeyFile => _keyData != null;

  /// Callback invoked when dirty state changes.
  void Function(bool isDirty)? onDirtyChanged;

  void markDirty() {
    _dirty = true;
    _mutationCount++;
    onDirtyChanged?.call(true);
  }

  void _ensureCacheFresh() {
    if (_allEntriesCache == null && _db != null) {
      _rebuildEntryCache();
    }
  }

  void markClean() {
    _dirty = false;
    onDirtyChanged?.call(false);
  }

  /// All entries in a flat cached list. Rebuilt on open/create/mutation.
  List<KdbxEntry> get allEntries {
    _ensureCacheFresh();
    return _allEntriesCache ?? [];
  }

  /// All unique tags across the entire database, sorted alphabetically.
  /// Computed from the cached [allEntries] list on every call so in-place tag
  /// mutations (e.g. batch tag, entry edit) are always reflected without a
  /// separate invalidation step.
  Set<String> get allTags {
    final tags = <String>{};
    for (final entry in allEntries) {
      final entryTags = entry.tags;
      if (entryTags != null) tags.addAll(entryTags);
    }
    return tags;
  }

  void _rebuildEntryCache() {
    _allEntriesCache = _db?.root.allEntries.toList();
    _entryByUuid = _allEntriesCache == null
        ? null
        : {for (final e in _allEntriesCache!) e.uuid.string: e};
    log.d(
      '[DatabaseService] _rebuildEntryCache count=${_allEntriesCache?.length}',
    );
    _searchIndex = null;
  }

  /// Upgrades TOTP secrets that only exist in this app's legacy customData
  /// keys into KeePass standard entry fields. Marks dirty so the next save
  /// persists the migration.
  void _migrateLegacyTotpFields() {
    final service = TotpService();
    var migrated = 0;
    for (final entry in allEntries) {
      if (service.migrateLegacyTotp(entry)) migrated++;
    }
    if (migrated > 0) {
      markDirty();
      log.i('Migrated $migrated legacy TOTP customData entries to fields');
    }
  }

  void _rebuildSearchIndex() {
    final entries = _allEntriesCache;
    if (entries == null) {
      _searchIndex = null;
      return;
    }
    _searchIndex = entries.map((e) => _SearchRecord(e)).toList();
  }

  void rebuildEntryCache() => _rebuildEntryCache();

  /// Drops the lowercase search index. It duplicates the text of every entry,
  /// so it is only worth keeping while a search session is actually active;
  /// the next search rebuilds it on demand.
  void clearSearchIndex() => _searchIndex = null;

  /// Returns true if the given group is the recycle bin group.
  bool isRecycleBinGroup(KdbxGroup group) {
    final recycleBinUuid = _db?.meta.recycleBinUuid;
    return recycleBinUuid != null && group.uuid == recycleBinUuid;
  }

  /// Returns true if an item is inside the recycle bin or one of its groups.
  bool isInRecycleBin(KdbxItem item) {
    final recycleBinUuid = _db?.meta.recycleBinUuid;
    if (recycleBinUuid == null) return false;

    var group = item is KdbxGroup ? item : item.parent;
    while (group != null) {
      if (group.uuid == recycleBinUuid) return true;
      group = group.parent;
    }
    return false;
  }

  /// Returns the name of the recycle bin group, or null if no recycle bin exists.
  String? get recycleBinName {
    final recycleBinUuid = _db?.meta.recycleBinUuid;
    if (recycleBinUuid == null) return null;
    final root = _db?.root;
    if (root == null) return null;
    for (final group in root.groups) {
      if (group.uuid == recycleBinUuid) return group.name;
    }
    return null;
  }

  /// Preloads file bytes into memory so openFile doesn't block on I/O.
  /// Runs in a background isolate to avoid blocking the UI.
  Future<void> preloadFile(String filePath) async {
    // Skip if already preloaded the same file
    if (_preloadedBytes != null && _preloadedFilePath == filePath) {
      log.i('File already preloaded: $filePath');
      return;
    }
    log.i('Preloading file: $filePath');
    final loaded = await Isolate.run(() async {
      final file = File(filePath);
      final stat = await file.stat();
      return (bytes: await file.readAsBytes(), stat: stat);
    });
    _preloadedBytes = loaded.bytes;
    _preloadedFilePath = filePath;
    _preloadedModified = loaded.stat.modified;
    _preloadedSize = loaded.stat.size;
  }

  /// The preloaded bytes can go stale while the unlock screen is open (e.g.
  /// a "download latest" flow rewrites the same cache path). Verify size and
  /// mtime before trusting them: opening a stale preload and saving it would
  /// overwrite the newer file while matching its remote revision.
  Future<bool> _isPreloadFresh(String filePath) async {
    if (_preloadedModified == null || _preloadedSize == null) return false;
    try {
      final stat = await File(filePath).stat();
      return stat.size == _preloadedSize &&
          stat.modified == _preloadedModified;
    } catch (_) {
      return false;
    }
  }

  /// Loads a KDBX database in a background isolate to avoid blocking the UI.
  /// The isolate initializes its own crypto engine (FFI if available, pure Dart fallback).
  static Future<KdbxDatabase> _loadDatabase(
    Uint8List bytes,
    String password, {
    Uint8List? keyData,
  }) async {
    return await Isolate.run(() {
      CryptoService.initialize();
      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(password),
        keyData: keyData,
      );
      return KdbxDatabase.fromBytes(data: bytes, credentials: credentials);
    });
  }

  /// Validates serialized KDBX bytes without mutating the active service.
  static Future<void> validateBytes(
    Uint8List bytes,
    String password, {
    Uint8List? keyData,
  }) async {
    await _loadDatabase(bytes, password, keyData: keyData);
  }
  Future<KdbxDatabase> openFile(
    String filePath,
    String password, {
    Uint8List? keyData,
  }) async {
    log.i('Opening database: $filePath');
    // Recover any interrupted atomic write before reading the target path.
    final recovered = await _recoverInterruptedWrite(
      filePath,
      password,
      keyData: keyData,
    );
    // Preload is only safe when it matches this path, recovery did not
    // rewrite the file underneath, and the file has not been changed on disk
    // since the preload was taken.
    final canUsePreload =
        !recovered &&
        _preloadedBytes != null &&
        _preloadedFilePath == filePath &&
        await _isPreloadFresh(filePath);
    final bytes =
        canUsePreload ? _preloadedBytes! : await File(filePath).readAsBytes();
    _preloadedBytes = null;
    _preloadedFilePath = null;
    try {
      _db = await _loadDatabase(bytes, password, keyData: keyData);
    } catch (e) {
      if (isCorruptionError(e)) {
        log.e('Database file corrupted: $filePath', error: e);
        throw DatabaseCorruptedException(e);
      }
      rethrow;
    }
    _filePath = filePath;
    _password = password;
    _keyData = keyData;
    markClean();
    _localizeRecycleBin();
    _rebuildEntryCache();
    _migrateLegacyTotpFields();
    log.i('Database opened, entries: ${_allEntriesCache!.length}');
    return _db!;
  }

  /// Best-effort recovery for an interrupted [AtomicFileStore.commit].
  /// Returns true if the target file was replaced from a recovery candidate.
  Future<bool> _recoverInterruptedWrite(
    String filePath,
    String password, {
    Uint8List? keyData,
  }) async {
    final pending = await _atomicFileStore.readPending(filePath);
    if (pending == null) return false;

    log.w(
      'Interrupted write detected for $filePath (stage=${pending.stage}); '
      'attempting recovery',
    );

    final candidates = await _atomicFileStore.candidates(filePath);
    // Prefer target, then rollback (previous good), then temp (new write).
    AtomicRecoveryCandidate? pick(String path) =>
        candidates.where((c) => c.path == path).firstOrNull;
    final ordered = <AtomicRecoveryCandidate>[
      ?pick(pending.target),
      ?pick(pending.rollback),
      ?pick(pending.temp),
    ];

    for (final candidate in ordered) {
      try {
        final bytes = await File(candidate.path).readAsBytes();
        await validateBytes(bytes, password, keyData: keyData);
        var rewritten = false;
        if (candidate.path != filePath) {
          await File(candidate.path).copy(filePath);
          rewritten = true;
          log.i('Recovered database from ${candidate.path}');
        } else {
          log.i('Target file already valid after interrupted write');
        }
        await _atomicFileStore.discardPending(filePath);
        return rewritten;
      } catch (e) {
        log.w('Recovery candidate failed: ${candidate.path}', error: e);
      }
    }

    log.e(
      'Unable to recover a valid database from interrupted write artifacts '
      'for $filePath',
    );
    // Leave artifacts in place for manual recovery / backup restore.
    return false;
  }

  Future<KdbxDatabase> createDatabase(
    String name,
    String password,
    String filePath, {
    Uint8List? keyData,
  }) async {
    log.i('Creating database: $name -> $filePath');
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
      keyData: keyData,
    );
    _db = KdbxDatabase.create(credentials: credentials, name: name);
    _filePath = filePath;
    _password = password;
    _keyData = keyData;
    markDirty();
    _localizeRecycleBin();
    _rebuildEntryCache();
    await save();
    log.i('Database created successfully');
    return _db!;
  }

  Future<KdbxDatabase> reloadFromBytes(
    Uint8List bytes, {
    String? password,
  }) async {
    final pw = password ?? _password;
    if (pw == null) throw Exception('no_password_cannot_reload');
    _db = await _loadDatabase(bytes, pw, keyData: _keyData);
    _password = pw;
    // Keep the database dirty until the reloaded content is actually
    // persisted: if the following save() fails, close()/auto-save must still
    // see the pending change instead of silently dropping the restore.
    markDirty();
    _localizeRecycleBin();
    _rebuildEntryCache();
    _migrateLegacyTotpFields();
    return _db!;
  }

  void _localizeRecycleBin() {
    // Intentionally no-op: localizing the recycle bin name on every open
    // causes unnecessary dirty state and sync conflicts for bilingual users.
  }

  /// Saves the database to disk and returns the serialized bytes.
  /// Serialization runs on the calling isolate (see [_saveOnce]); concurrent
  /// saves are serialized via [_saveQueue].
  /// Returns the serialized bytes so callers can reuse them (e.g. for cloud upload).
  Future<Uint8List> save() {
    final completer = Completer<Uint8List>();
    _saveQueue = _saveQueue
        .then((_) => null, onError: (_) => null)
        .then((_) async {
      try {
        completer.complete(await _saveOnce());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Uint8List> _saveOnce() async {
    final db = _db;
    final path = _filePath;
    final password = _password;
    // A queued save can start after close() cleared the state. Fail loudly so
    // callers never mistake empty bytes for a successful save (an empty result
    // must never reach a cloud upload).
    if (db == null || path == null || password == null) {
      throw StateError('Cannot save: database is closed');
    }
    log.i('Saving database: $path');
    final mutationCountAtStart = _mutationCount;
    // Serialize on the main isolate. KdbxDatabase graphs (and any enclosing
    // service state captured by a closure) are not reliably sendable to a
    // background isolate; Isolate.run previously failed with:
    // "Illegal argument in isolate message: object is unsendable ... _Future".
    // KDF/crypto inside kpasslib is already async, so the UI can still yield.
    // kpasslib's save() already returns a freshly built Uint8List; copying it
    // again via Uint8List.fromList would double the whole database in memory.
    final saved = await db.save();
    final bytes = saved is Uint8List ? saved : Uint8List.fromList(saved);
    await validateBytes(bytes, password, keyData: _keyData);
    await _atomicFileStore.commit(
      path,
      bytes,
      backup: () async {
        if (await _backupService.isAutoBackupEnabled()) {
          final backup = await _backupService.createBackup(path);
          if (backup == null) {
            throw const FileSystemException('Unable to create database backup');
          }
        }
      },
    );
    if (_mutationCount == mutationCountAtStart) {
      markClean();
    } else {
      log.i('Database mutated during save, keeping dirty flag');
    }
    log.i('Database saved (${bytes.length} bytes)');
    return bytes;
  }

  /// Serializes the database to bytes without writing to disk.
  Future<Uint8List> saveToBytes() async {
    if (_db == null) return Uint8List(0);
    final saved = await _db!.save();
    return saved is Uint8List ? saved : Uint8List.fromList(saved);
  }

  Future<void> saveAs(String newPath) async {
    final previousPath = _filePath;
    _filePath = newPath;
    try {
      await save();
    } catch (_) {
      _filePath = previousPath;
      rethrow;
    }
  }

  KdbxGroup createGroup(KdbxGroup parent, String name) {
    final group = _db!.createGroup(parent: parent, name: name);
    markDirty();
    return group;
  }

  KdbxEntry createEntry(KdbxGroup parent) {
    final entry = _db!.createEntry(parent: parent);
    entry.times = KdbxTimes.fromTime();
    _allEntriesCache = null;
    markDirty();
    return entry;
  }

  void deleteItem(KdbxItem item) {
    _db!.remove(item);
    _allEntriesCache = null;
    markDirty();
  }

  /// Permanently discards an item (no recycle bin). Used when abandoning a
  /// never-saved draft entry so it does not pollute the recycle bin.
  void discardItem(KdbxItem item) {
    if (_db == null) return;
    _db!.move(item: item, target: null);
    _allEntriesCache = null;
  }

  /// Restores an item from the recycle bin to its previous parent group.
  /// Returns true if restored successfully, false if previous parent not found.
  bool restoreItem(KdbxItem item) {
    if (_db == null) return false;
    final prevUuid = item.previousParent;
    if (prevUuid == null) return false;
    final target = _db!.getGroup(uuid: prevUuid);
    if (target == null) return false;
    _db!.move(item: item, target: target);
    _allEntriesCache = null;
    markDirty();
    return true;
  }

  void moveItem(KdbxItem item, KdbxGroup target) {
    _db!.move(item: item, target: target);
    _allEntriesCache = null;
    markDirty();
  }

  KdbxEntry? findEntryByUuid(KdbxUuid uuid) {
    if (_db == null) return null;
    _ensureCacheFresh();
    final entry = _entryByUuid?[uuid.string];
    if (entry == null) {
      log.w(
        '[DatabaseService] findEntryByUuid MISS uuid=${uuid.string} cacheSize=${_allEntriesCache?.length}',
      );
    }
    return entry;
  }

  /// Searches all entries for [query], returning matches ranked by relevance.
  /// When [limit] is provided, at most [limit] top results are returned, which
  /// avoids sorting/allocating the full match set for very large databases.
  List<SearchResult> search(String query, {int? limit}) {
    if (_db == null || query.isEmpty) return [];
    // Ensure the entry cache is fresh before (re)building the search index.
    // Mutations null _allEntriesCache without touching _searchIndex, so an
    // explicit cache check here guarantees the index reflects current state.
    _ensureCacheFresh();
    if (_searchIndex == null) {
      log.d('[DatabaseService] building search index lazily');
      _rebuildSearchIndex();
    }
    final index = _searchIndex ?? const <_SearchRecord>[];
    final results = <SearchResult>[];
    for (final record in index) {
      final match = record.matchScore(query);
      if (match != null && match.isMatch) {
        results.add(SearchResult(record.entry, match.score, match.positions));
        if (limit != null && results.length >= limit) break;
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  KdbxGroup? findGroupByPath(String path) {
    if (_db == null || path.isEmpty) return _db?.root;
    final segments = path.split('/');
    KdbxGroup? current = _db!.root;
    for (final segment in segments) {
      if (segment.isEmpty) continue;
      current = current?.groups.where((g) => g.name == segment).firstOrNull;
      if (current == null) {
        log.w(
          '[DatabaseService] findGroupByPath MISS path="$path" failed at segment="$segment"',
        );
        return null;
      }
    }
    return current;
  }

  String getGroupPath(KdbxGroup group, {KdbxGroup? root}) {
    final parts = <String>[];
    final effectiveRoot = root ?? _db?.root;
    KdbxGroup? current = group;
    while (current != null && current != effectiveRoot) {
      parts.add(current.name);
      current = current.parent;
    }
    return parts.reversed.join('/');
  }

  SyncAuditReport buildSyncAuditReport(KdbxDatabase remoteDb) {
    final localMap = {for (final entry in allEntries) entry.uuid.string: entry};
    final remoteEntries = remoteDb.root.allEntries.toList();
    final remoteMap = {
      for (final entry in remoteEntries) entry.uuid.string: entry,
    };

    final localOnly = <SyncAuditChange>[];
    final remoteOnly = <SyncAuditChange>[];
    final modifiedBoth = <SyncAuditChange>[];

    for (final entry in allEntries) {
      final remoteEntry = remoteMap[entry.uuid.string];
      if (remoteEntry == null) {
        localOnly.add(_buildChange('local_only', entry, root: _db?.root));
        continue;
      }
      final diff = _entryDiffDetails(entry, remoteEntry);
      final details = diff.details;
      if (details.isNotEmpty) {
        modifiedBoth.add(
          _buildChange(
            'modified_both',
            entry,
            root: _db?.root,
            details: details,
            localValues: diff.localValues,
            remoteValues: diff.remoteValues,
          ),
        );
      }
    }

    for (final entry in remoteEntries) {
      if (!localMap.containsKey(entry.uuid.string)) {
        remoteOnly.add(_buildChange('remote_only', entry, root: remoteDb.root));
      }
    }

    return SyncAuditReport(
      localOnly: localOnly,
      remoteOnly: remoteOnly,
      modifiedBoth: modifiedBoth,
    );
  }

  Future<SyncAuditReport> buildSyncAuditReportFromBytes(
    Uint8List remoteBytes,
  ) async {
    if (_db == null || _password == null) {
      throw Exception('database_not_open');
    }
    final remoteDb = await _loadDatabase(
      remoteBytes,
      _password!,
      keyData: _keyData,
    );
    return buildSyncAuditReport(remoteDb);
  }

  SyncAuditChange _buildChange(
    String type,
    KdbxEntry entry, {
    KdbxGroup? root,
    List<String> details = const [],
    Map<String, String> localValues = const {},
    Map<String, String> remoteValues = const {},
  }) {
    final title = entry.fields['Title']?.text ?? '(Untitled)';
    final groupPath =
        entry.parent != null ? getGroupPath(entry.parent!, root: root) : '';
    final modifiedAt = entry.times.modification.time?.toIso8601String();
    return SyncAuditChange(
      type: type,
      title: title,
      groupPath: groupPath,
      modifiedAt: modifiedAt,
      details: details,
      localValues: localValues,
      remoteValues: remoteValues,
    );
  }

  ({
    List<String> details,
    Map<String, String> localValues,
    Map<String, String> remoteValues,
  })
  _entryDiffDetails(KdbxEntry local, KdbxEntry remote) {
    final details = <String>[];
    final localValues = <String, String>{};
    final remoteValues = <String, String>{};
    final keys = <String>{...local.fields.keys, ...remote.fields.keys}.toList()
      ..sort();
    for (final key in keys) {
      final localValue = local.fields[key]?.text ?? '';
      final remoteValue = remote.fields[key]?.text ?? '';
      if (localValue != remoteValue) {
        details.add('Field:$key');
        localValues[key] = localValue;
        remoteValues[key] = remoteValue;
      }
    }

    final localTags = (local.tags ?? []).toSet();
    final remoteTags = (remote.tags ?? []).toSet();
    if (localTags.length != remoteTags.length ||
        !localTags.containsAll(remoteTags)) {
      details.add('Tags');
      localValues['Tags'] = localTags.join(', ');
      remoteValues['Tags'] = remoteTags.join(', ');
    }

    final localAttachments = local.binaries.keys.toSet();
    final remoteAttachments = remote.binaries.keys.toSet();
    if (localAttachments.length != remoteAttachments.length ||
        !localAttachments.containsAll(remoteAttachments)) {
      details.add('Attachments');
      localValues['Attachments'] = localAttachments.join(', ');
      remoteValues['Attachments'] = remoteAttachments.join(', ');
    }

    if (local.history.length != remote.history.length) {
      details.add('History');
      localValues['History'] = '${local.history.length}';
      remoteValues['History'] = '${remote.history.length}';
    }

    final localModified = local.times.modification.time;
    final remoteModified = remote.times.modification.time;
    if (localModified != remoteModified) {
      details.add('ModifiedTime');
      localValues['ModifiedTime'] = localModified?.toIso8601String() ?? '';
      remoteValues['ModifiedTime'] = remoteModified?.toIso8601String() ?? '';
    }

    return (
      details: details,
      localValues: localValues,
      remoteValues: remoteValues,
    );
  }

  /// Changes the master password of the currently open database.
  /// Throws [InvalidCredentialsError] if [oldPassword] is incorrect.
  /// Does NOT save to disk — caller should invoke save() afterwards.
  /// If [updateKeyFile] is true, [newKeyData] will be used (null means remove key file).
  /// If [updateKeyFile] is false, the existing key file is preserved.
  void changePassword(
    String oldPassword,
    String newPassword, {
    bool updateKeyFile = false,
    Uint8List? newKeyData,
  }) {
    if (_db == null) throw Exception('database_not_open');
    if (_password != oldPassword) {
      throw const InvalidCredentialsError('invalid key');
    }
    final keyData = updateKeyFile ? newKeyData : _keyData;
    _db!.header.credentials = KdbxCredentials(
      password: ProtectedData.fromString(newPassword),
      keyData: keyData,
    );
    _password = newPassword;
    _keyData = keyData;
    markDirty();
    log.i('Master password changed');
  }

  void close() {
    log.i('Database closed: $_filePath');
    _db = null;
    _filePath = null;
    _password = null;
    _keyData = null;
    if (_dirty) markClean();
    _lastSyncedRemoteInfo = null;
    _preloadedBytes = null;
    _preloadedFilePath = null;
    _preloadedModified = null;
    _preloadedSize = null;
    _allEntriesCache = null;
    _entryByUuid = null;
    _searchIndex = null;
  }
}

