import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/logger.dart';
import '../../database/data/database_service.dart';
import '../data/autofill_credential_snapshot.dart';
import '../data/autofill_matcher.dart';

const _appGroupId = 'group.com.keestone.keestone';
const _channel = MethodChannel('com.keestone.keestone/app_group');
const _snapshotFileName = 'keestone_autofill_snapshot.bin';
const _keyStorageKey = 'autofill_snapshot_key';
const _keyStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    groupId: _appGroupId,
    accessibility: KeychainAccessibility.first_unlock,
  ),
);

/// Builds the iOS autofill credential snapshot from the open vault, encrypts it
/// with AES-GCM, and writes it to the shared App Group container; the native
/// Credential Provider Extension reads + decrypts it (CryptoKit) to fill.
///
/// The snapshot is the *only* credential material that leaves the main app's
/// memory: it contains just the fields autofill needs, and is deleted on lock.
class AutofillSnapshotService {
  /// Writes a fresh snapshot for the currently open [service].
  ///
  /// iOS: App Group container (read by the Credential Provider Extension).
  /// Android: app files directory — the prewarmed autofill Flutter engine
  /// runs in the same process and reads it from Dart directly, so no native
  /// plumbing is needed.
  Future<void> writeFor(DatabaseService service) async {
    if (!service.isOpen) return;
    String? filePath;
    if (Platform.isIOS) {
      String? containerPath;
      try {
        containerPath = await _channel.invokeMethod<String>('getContainerPath');
      } catch (e) {
        log.w('app_group.getContainerPath failed (iOS App Group not configured?)', error: e);
        return;
      }
      if (containerPath == null) return;
      filePath = _joinPath(containerPath, _snapshotFileName);
    } else if (Platform.isAndroid) {
      try {
        final dir = await getApplicationSupportDirectory();
        filePath = _joinPath(dir.path, _snapshotFileName);
      } catch (e) {
        log.w('getApplicationSupportDirectory failed', error: e);
        return;
      }
    } else {
      return;
    }

    final snapshot = _buildSnapshot(service);
    if (snapshot.entries.isEmpty) return;

    try {
      final clearText = Uint8List.fromList(utf8.encode(snapshot.toUtf8JsonString()));
      final key = await _getOrCreateKey();
      final cipher = AesGcm.with256bits();
      final secretKey = SecretKey(key);
      final box = await cipher.encrypt(clearText, secretKey: secretKey);
      final combined = box.concatenation();
      final wrapped = AutofillSnapshotFile.wrap(Uint8List.fromList(combined));
      if (Platform.isIOS) {
        await _channel.invokeMethod('writeFile', {
          'path': filePath,
          'bytes': wrapped,
        });
      } else {
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(wrapped, flush: true);
      }
    } catch (e, st) {
      log.e('Autofill snapshot write failed', error: e, stackTrace: st);
    }
  }

  /// Loads and decrypts the snapshot for the prewarmed autofill engine on
  /// Android (same process, same files dir). Returns null when missing,
  /// unreadable or malformed — the caller falls back to "locked".
  Future<AutofillSnapshot?> readForMatching() async {
    if (!Platform.isAndroid) return null;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(_joinPath(dir.path, _snapshotFileName));
      if (!await file.exists()) return null;
      final wrapped = await file.readAsBytes();
      final combined = AutofillSnapshotFile.unwrap(wrapped);
      if (combined == null) return null;
      final key = await _getOrCreateKey();
      final cipher = AesGcm.with256bits();
      final secretBox = SecretBox.fromConcatenation(
        combined,
        nonceLength: cipher.nonceLength,
        macLength: cipher.macAlgorithm.macLength,
      );
      final clearText = await cipher.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );
      final json = jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
      return AutofillSnapshot.fromJson(json);
    } catch (e) {
      log.w('Autofill snapshot read failed', error: e);
      return null;
    }
  }

  /// Deletes the snapshot (called on lock/close so no credentials linger).
  Future<void> delete() async {
    try {
      if (Platform.isIOS) {
        final containerPath = await _channel.invokeMethod<String>('getContainerPath');
        if (containerPath == null) return;
        await _channel.invokeMethod('deleteFile', {
          'path': _joinPath(containerPath, _snapshotFileName),
        });
      } else if (Platform.isAndroid) {
        final dir = await getApplicationSupportDirectory();
        final file = File(_joinPath(dir.path, _snapshotFileName));
        if (await file.exists()) await file.delete();
      }
    } catch (_) {
      // Storage unavailable — nothing to delete.
    }
  }

  // ── Pure helpers ───────────────────────────────────────────────────────────

  AutofillSnapshot _buildSnapshot(DatabaseService service) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <AutofillSnapshotEntry>[];
    for (final entry in service.allEntries) {
      if (service.isInRecycleBin(entry)) continue;
      final title = entry.fields['Title']?.text ?? '';
      final username = entry.fields['UserName']?.text ?? '';
      final password = entry.fields['Password']?.text ?? '';
      final urlRaw = entry.fields['URL']?.text ?? '';
      if (password.isEmpty && username.isEmpty && title.isEmpty) continue;
      final tokens = AutofillMatcher.parseUrlField(urlRaw);
      final domains = <String>[];
      final packageIds = <String>[];
      for (final t in tokens) {
        if (t.isPackage) {
          packageIds.add(t.value);
        } else {
          domains.add(t.value);
        }
      }
      entries.add(AutofillSnapshotEntry(
        uuid: entry.uuid.string,
        title: title,
        username: username,
        password: password,
        domains: domains,
        packageIds: packageIds,
      ));
    }
    return AutofillSnapshot(version: AutofillSnapshot.currentVersion, createdAt: now, entries: entries);
  }

  Future<Uint8List> _getOrCreateKey() async {
    final existing = await _keyStorage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      if (bytes.length == 32) return Uint8List.fromList(bytes);
    }
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    await _keyStorage.write(key: _keyStorageKey, value: base64Encode(key));
    return key;
  }

  static String _joinPath(String dir, String name) {
    if (dir.endsWith('/')) return '$dir$name';
    return '$dir/$name';
  }

  static final _random = Random.secure();
}
