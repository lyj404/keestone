import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kpasslib/kpasslib.dart';
import '../utils/secure_storage_helper.dart';
import '../services/notification_service.dart';

const reminderThresholdOptions = [0, 1, 3, 7, 14, 30]; // days, 0 = disabled

class ExpirationReminderNotifier extends StateNotifier<int> {
  static const _storage = SecureStorageHelper();
  static const _key = 'expiration_reminder_days';

  ExpirationReminderNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) {
      state = int.tryParse(value) ?? 0;
    }
  }

  Future<void> setDays(int days) async {
    state = days;
    await _storage.write(key: _key, value: days.toString());
  }

  Future<void> checkExpiringEntries(KdbxDatabase db) async {
    if (state <= 0) return;

    // Throttle: only check once per day
    final lastCheckKey = _lastCheckKeyFor(db);
    final lastCheck = await _storage.read(key: lastCheckKey);
    final now = DateTime.now();
    if (lastCheck != null) {
      final lastDate = DateTime.tryParse(lastCheck);
      if (lastDate != null && now.difference(lastDate).inHours < 24) return;
    }

    final threshold = now.add(Duration(days: state));
    final expiring = <KdbxEntry>[];
    final expired = <KdbxEntry>[];

    for (final entry in db.root.allEntries) {
      if (!entry.times.expires) continue;
      final expiry = entry.times.expiry.time;
      if (expiry == null) continue;

      if (expiry.isBefore(now)) {
        expired.add(entry);
      } else if (expiry.isBefore(threshold)) {
        expiring.add(entry);
      }
    }

    await _storage.write(key: lastCheckKey, value: now.toIso8601String());

    if (expiring.isEmpty && expired.isEmpty) return;

    final title = _buildTitle(expiring.length, expired.length);
    final body = _buildBody(expiring, expired);

    await NotificationService().showExpiryNotification(
      title: title,
      body: body,
    );
  }

  String _buildTitle(int expiringCount, int expiredCount) {
    final parts = <String>[];
    if (expiredCount > 0) {
      parts.add('$expiredCount password(s) expired');
    }
    if (expiringCount > 0) {
      parts.add('$expiringCount password(s) expiring soon');
    }
    return parts.join(', ');
  }

  String _buildBody(List<KdbxEntry> expiring, List<KdbxEntry> expired) {
    final names = <String>[];
    for (final e in expired.take(3)) {
      names.add(e.fields['Title']?.text ?? '(Untitled)');
    }
    for (final e in expiring.take(3)) {
      names.add(e.fields['Title']?.text ?? '(Untitled)');
    }
    var result = names.join(', ');
    final total = expiring.length + expired.length;
    if (total > 6) result += ' and ${total - 6} more';
    return result;
  }

  String _lastCheckKeyFor(KdbxDatabase db) {
    final rootUuid = db.root.uuid.string;
    return 'expiration_reminder_last_check_$rootUuid';
  }
}

final expirationReminderProvider =
    StateNotifierProvider<ExpirationReminderNotifier, int>((ref) {
      return ExpirationReminderNotifier();
    });

final reminderThresholdOptionsProvider = Provider<List<int>>((ref) {
  return reminderThresholdOptions;
});
