import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../database/data/database_service.dart';
import '../../database/providers/database_provider.dart';
import '../data/autotype_sequence.dart';
import '../services/autotype_native.dart';

/// AutoType runtime state surfaced to settings and dialogs.
class AutoTypeStatus {
  final bool enabled;
  final bool hotkeyRegistered;

  const AutoTypeStatus({
    required this.enabled,
    required this.hotkeyRegistered,
  });

  AutoTypeStatus copyWith({bool? enabled, bool? hotkeyRegistered}) =>
      AutoTypeStatus(
        enabled: enabled ?? this.enabled,
        hotkeyRegistered: hotkeyRegistered ?? this.hotkeyRegistered,
      );
}

/// Coordinates the AutoType feature: hotkey listening, entry picking and
/// sequence execution. Native typing is only supported on Windows.
class AutoTypeService {
  final Ref ref;
  StreamSubscription<void>? _hotkeySub;
  bool _enabled = false;
  bool _hotkeyRegistered = false;

  /// When set by the host app, invoked instead of the built-in dialog so the
  /// UI layer controls how entries are presented.
  Future<KdbxEntry?> Function(List<KdbxEntry> candidates)? pickEntry;

  AutoTypeService(this.ref);

  AutoTypeStatus get status =>
      AutoTypeStatus(enabled: _enabled, hotkeyRegistered: _hotkeyRegistered);

  DatabaseService? get _database {
    try {
      return ref.read(databaseServiceProvider);
    } catch (_) {
      return null;
    }
  }

  /// Enables or disables hotkey listening.
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled && autotypePlatformSupported) {
      await _start();
    } else {
      await _stop();
    }
  }

  Future<void> _start() async {
    _hotkeyRegistered = await AutoTypeNative.isHotkeyRegistered();
    await _hotkeySub?.cancel();
    _hotkeySub = AutoTypeNative.hotkeyPressed.listen((_) => _onHotkey());
  }

  Future<void> _stop() async {
    await _hotkeySub?.cancel();
    _hotkeySub = null;
    _hotkeyRegistered = false;
  }

  /// Called when Ctrl+Alt+A is pressed anywhere in the OS. Shows the entry
  /// picker with all vault entries and types the chosen sequence.
  Future<void> _onHotkey() async {
    if (!_enabled) return;
    final database = _database;
    final picker = pickEntry;
    if (database == null || picker == null) return;
    if (database.db == null) return;

    final candidates = database.allEntries;
    if (candidates.isEmpty) return;

    final entry = await picker(candidates);
    if (entry == null) return;

    await typeEntry(entry);
  }

  /// Resolves the entry's sequence and types it into the previously focused
  /// window. The picker dialog must not steal focus for this to reach the
  /// right target.
  Future<void> typeEntry(KdbxEntry entry) async {
    if (!autotypePlatformSupported) return;
    final sequence = entry.autoType.defaultSequence?.isNotEmpty == true
        ? entry.autoType.defaultSequence!
        : defaultAutoTypeSequence;
    final tokens = parseAutoTypeSequence(sequence);
    final actions = buildAutoTypeActions(
      tokens: tokens,
      username: entry.fields['UserName']?.text,
      password: entry.fields['Password']?.text,
      title: entry.fields['Title']?.text,
      url: entry.fields['URL']?.text,
      notes: entry.fields['Notes']?.text,
      totp: null,
    );
    await AutoTypeNative.performActions(actions);
  }

  /// Persists a custom sequence on the entry using the standard KDBX
  /// AutoType structure (defaultSequence), or clears it when equal to the
  /// built-in default.
  void saveSequence(KdbxEntry entry, String sequence, DatabaseService db) {
    final trimmed = sequence.trim();
    if (trimmed.isEmpty || trimmed == defaultAutoTypeSequence) {
      entry.autoType.defaultSequence = null;
    } else {
      entry.autoType.enabled = true;
      entry.autoType.defaultSequence = trimmed;
    }
    db.markDirty();
  }

  /// Custom sequence for the entry, or null when using the default.
  String? loadSequence(KdbxEntry entry) {
    final seq = entry.autoType.defaultSequence;
    return seq == null || seq.isEmpty ? null : seq;
  }

  void dispose() {
    _hotkeySub?.cancel();
  }
}

final autoTypeServiceProvider = Provider<AutoTypeService>((ref) {
  final service = AutoTypeService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Reactive AutoType status for settings UI.
final autoTypeStatusProvider = StateProvider<AutoTypeStatus>(
  (ref) => const AutoTypeStatus(enabled: false, hotkeyRegistered: false),
);
