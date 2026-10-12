import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/database/data/database_service.dart';
import 'package:keestone/features/database/providers/database_provider.dart';
import 'package:keestone/features/settings/data/webdav_config.dart';
import 'package:keestone/features/sync/data/sync_service.dart';
import 'package:keestone/features/sync/providers/sync_provider.dart';

/// A SyncService stand-in that records calls and returns scripted remote
/// state so linking a local database to the cloud can be exercised without a
/// live WebDAV server.
class _FakeSyncService extends SyncService {
  _FakeSyncService({this.remoteInfo});

  /// When non-null, the remote path is treated as already holding a database.
  RemoteFileInfo? remoteInfo;

  int ensureDirCalls = 0;
  int uploadCalls = 0;
  RemoteFileInfo? lastExpected;
  bool lastForce = false;

  @override
  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    ensureDirCalls++;
  }

  @override
  Future<RemoteFileInfo?> getRemoteFileInfo(WebDavConfig config) async {
    return remoteInfo;
  }

  @override
  Future<RemoteFileInfo> uploadDatabase(
    WebDavConfig config,
    Uint8List bytes, {
    RemoteFileInfo? expected,
    bool force = false,
  }) async {
    uploadCalls++;
    lastExpected = expected;
    lastForce = force;
    return const RemoteFileInfo(eTag: '"uploaded"');
  }

  @override
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(
    WebDavConfig config,
  ) async {
    // inspectCloudDiff() calls this on conflict; returning null keeps the
    // audit best-effort without needing a real remote database.
    return null;
  }

  @override
  void clearCache() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late String databasePath;

  Future<void> seedWebDavProfile({required bool enabled}) async {
    FlutterSecureStorage.setMockInitialValues({
      // Disable auto-backup so save() does not reach path_provider, which has
      // no implementation in a plain unit test.
      'backup_auto_enabled': 'false',
      'webdav_profiles': jsonEncode({
        'activeProfileId': 'p1',
        'profiles': [
          {
            'id': 'p1',
            'name': 'Home',
            'serverUrl': 'https://example.com/dav',
            'username': 'user',
            'password': 'secret',
            'remotePath': '/vaults',
            'remoteFilename': 'vault.kdbx',
            'enabled': enabled,
          },
        ],
      }),
    });
  }

  setUp(() async {
    // Keep auto-backup off for the seed save below too.
    FlutterSecureStorage.setMockInitialValues({'backup_auto_enabled': 'false'});
    directory = await Directory.systemTemp.createTemp('keestone_link_cloud_');
    databasePath = '${directory.path}${Platform.pathSeparator}vault.kdbx';
    // Create a real local database file to open.
    final seedService = DatabaseService();
    await seedService.createDatabase('Vault', 'test-password', databasePath);
    await seedService.save();
    seedService.close();
  });

  tearDown(() async {
    FlutterSecureStorage.setMockInitialValues({});
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  ProviderContainer makeContainer(_FakeSyncService fake) {
    return ProviderContainer(
      overrides: [
        syncServiceProvider.overrideWithValue(fake),
      ],
    );
  }

  test('empty remote: links local database and uploads conditionally',
      () async {
    await seedWebDavProfile(enabled: true);
    final fake = _FakeSyncService(remoteInfo: null);
    final container = makeContainer(fake);
    addTearDown(container.dispose);

    final notifier = container.read(databaseProvider.notifier);
    await notifier.openFile(databasePath, 'test-password', isCloud: false);
    expect(container.read(openedFromCloudProvider), isFalse);

    await notifier.syncLocalToCloud();

    expect(container.read(syncStateProvider), SyncState.success);
    expect(container.read(openedFromCloudProvider), isTrue);
    expect(fake.ensureDirCalls, 1);
    expect(fake.uploadCalls, 1);
    // A never-seen remote must use the conditional (If-None-Match) path.
    expect(fake.lastExpected, isNull);
    expect(fake.lastForce, isFalse);

    final recent = await container
        .read(recentFilesServiceProvider)
        .getLastOpenedFile();
    expect(recent?.isCloud, isTrue);
    expect(recent?.webDavProfileId, 'p1');
    expect(recent?.remotePath, '/vaults/vault.kdbx');
  });

  test('existing remote: reports a conflict and never overwrites', () async {
    await seedWebDavProfile(enabled: true);
    final fake = _FakeSyncService(
      remoteInfo: const RemoteFileInfo(eTag: '"remote"'),
    );
    final container = makeContainer(fake);
    addTearDown(container.dispose);

    final notifier = container.read(databaseProvider.notifier);
    await notifier.openFile(databasePath, 'test-password', isCloud: false);

    await notifier.syncLocalToCloud();

    expect(container.read(syncStateProvider), SyncState.conflict);
    // No upload happened — the existing remote database is preserved.
    expect(fake.uploadCalls, 0);
    // The database is now associated with the profile so the user can resolve
    // the conflict (download / overwrite).
    expect(container.read(openedFromCloudProvider), isTrue);
  });

  test('disabled WebDAV: throws and leaves the database local', () async {
    await seedWebDavProfile(enabled: false);
    final fake = _FakeSyncService();
    final container = makeContainer(fake);
    addTearDown(container.dispose);

    final notifier = container.read(databaseProvider.notifier);
    await notifier.openFile(databasePath, 'test-password', isCloud: false);

    await expectLater(notifier.syncLocalToCloud(), throwsA(isA<Exception>()));
    expect(container.read(openedFromCloudProvider), isFalse);
    expect(fake.uploadCalls, 0);
  });
}
