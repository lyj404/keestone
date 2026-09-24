import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Conditional import keeps the win32 helper out of pure-web builds. On other
// `dart:io` targets the helper is linked but no-ops unless Platform.isWindows
// (see notification_service_windows.dart).
import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_windows.dart'
    as windows;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _windowsHelper = windows.WindowsNotificationHelper();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isLinux) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
      );
    } else if (Platform.isAndroid) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isMacOS) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    } else if (Platform.isIOS) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    }

    _initialized = true;
  }

  Future<void> showExpiryNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    if (Platform.isWindows) {
      _windowsHelper.showBalloon(title, body);
      return;
    }

    if (Platform.isLinux) {
      await _showLinuxNotification(title, body);
      return;
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _plugin.show(
        id: 0,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: Platform.isAndroid
              ? const AndroidNotificationDetails(
                  'expiry_reminder',
                  'Password Expiry Reminders',
                  channelDescription:
                      'Notifications for passwords that are about to expire',
                  importance: Importance.high,
                  priority: Priority.high,
                )
              : null,
          iOS: Platform.isIOS
              ? const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: false,
                  presentSound: false,
                )
              : null,
          macOS: Platform.isMacOS
              ? const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: false,
                  presentSound: false,
                )
              : null,
        ),
      );
      return;
    }
  }

  /// Linux: use flutter_local_notifications plugin instead of spawning a process.
  Future<void> _showLinuxNotification(String title, String body) async {
    try {
      await _plugin.show(
        id: 0,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (_) {
      // Fallback to notify-send if plugin fails
      try {
        await Process.run('notify-send', [
          '--app-name=KeeStone',
          '--urgency=normal',
          title,
          body,
        ]);
      } catch (_) {}
    }
  }

  void dispose() {
    _windowsHelper.dispose();
  }
}
