import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  /// Writes a fresh snapshot for the currently open [service]. No-op if the
  /// database is closed or the App Group container is unavailable.
  Future<void> writeFor(DatabaseService service) async {
    if (!service.isOpen) return;
    String? containerPath;
    try {
      containerPath = await _channel.invokeMethod<String>('getContainerPath');
    } catch (e) {
      log.w('app_group.getContainerPath failed (iOS App Group not configured?)', error: e);
      return;
    }
    if (containerPath == null) return;

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
      final file = _joinPath(containerPath, _snapshotFileName);
      await _channel.invokeMethod('writeFile', {
        'path': file,
        'bytes': wrapped,
      });
    } catch (e, st) {
      log.e('Autofill snapshot write failed', error: e, stackTrace: st);
    }
  }

  /// Deletes the snapshot (called on lock/close so no credentials linger).
  Future<void> delete() async {
    try {
      final containerPath = await _channel.invokeMethod<String>('getContainerPath');
      if (containerPath == null) return;
      await _channel.invokeMethod('deleteFile', {
        'path': _joinPath(containerPath, _snapshotFileName),
      });
    } catch (_) {
      // Container/keychain unavailable — nothing to delete.
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
