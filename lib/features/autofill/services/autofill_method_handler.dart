import 'package:flutter/services.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../core/providers/global_container.dart';
import '../../../core/utils/logger.dart';
import '../../database/providers/database_provider.dart';
import '../data/autofill_matcher.dart';
import 'autofill_snapshot_service.dart';

/// The platform channel that the Android autofill service uses to ask the
/// running Flutter engine (same process as `KeeVaultApplication`) for
/// matching vault entries.
///
/// All methods are best-effort and never throw across the channel: on any
/// error they return a "locked"/empty result so the native side can fall back
/// to launching the app. Credentials themselves are returned only on demand
/// (`getEntryCredentials`) and are not cached here.
class AutofillMethodHandler {
  static const _channel = MethodChannel('com.keestone.keestone/autofill');

  static AutofillMethodHandler? _instance;

  AutofillMethodHandler._();

  /// Registers the handler. Safe to call once at app startup.
  static void register() {
    _instance ??= AutofillMethodHandler._()._doRegister();
  }

  AutofillMethodHandler _doRegister() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'getCredentials':
            return await _handleGetCredentials(call.arguments);
          case 'getEntryCredentials':
            return await _handleGetEntryCredentials(call.arguments);
          default:
            return {'status': 'error', 'message': 'unknown_method'};
        }
      } catch (e, st) {
        log.e('AutofillMethodHandler error: ${call.method}', error: e, stackTrace: st);
        return {'status': 'error', 'message': e.toString()};
      }
    });
    return this;
  }

  Future<Map<String, dynamic>> _handleGetCredentials(dynamic arguments) async {
    final args = (arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final packageId = args['packageId'] as String?;
    final domain = args['domain'] as String?;
    final service = globalContainer.read(databaseServiceProvider);

    if (!service.isOpen) {
      // The prewarmed engine (Android autofill) is a separate Dart isolate
      // that never opens the database itself. Fall back to the encrypted
      // snapshot written by the main engine on unlock — this is what makes
      // filling work without showing "Unlock KeeStone" every time.
      final snapshot = await AutofillSnapshotService().readForMatching();
      if (snapshot != null) {
        final snapshotCandidates = AutofillMatcher.matchSnapshot(
          snapshot,
          query: AutofillQuery(packageId: packageId, domain: domain),
        );
        return AutofillMatchResult.unlocked(snapshotCandidates).toJson();
      }
      return AutofillMatchResult.locked(filePath: service.filePath).toJson();
    }

    final candidates = AutofillMatcher.match(
      service.allEntries,
      isInRecycleBin: service.isInRecycleBin,
      query: AutofillQuery(packageId: packageId, domain: domain),
    );
    return AutofillMatchResult.unlocked(candidates).toJson();
  }

  Future<Map<String, dynamic>> _handleGetEntryCredentials(
    dynamic arguments,
  ) async {
    final args = (arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final uuidStr = args['uuid'] as String?;
    if (uuidStr == null || uuidStr.isEmpty) {
      return {'status': 'error', 'message': 'missing_uuid'};
    }
    final service = globalContainer.read(databaseServiceProvider);
    if (!service.isOpen) {
      return AutofillMatchResult.locked(filePath: service.filePath).toJson();
    }
    final uuid = KdbxUuid.fromString(uuidStr);
    final entry = service.findEntryByUuid(uuid);
    if (entry == null) {
      return {'status': 'error', 'message': 'entry_not_found'};
    }
    final username = entry.fields['UserName']?.text ?? '';
    final password = entry.fields['Password']?.text ?? '';
    return {
      'status': 'unlocked',
      'username': username,
      'password': password,
    };
  }
}
