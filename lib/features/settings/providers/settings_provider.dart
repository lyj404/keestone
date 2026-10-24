import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/webdav_config.dart';
import '../data/webdav_service.dart';

final webDavSettingsServiceProvider = Provider<WebDavSettingsService>((ref) {
  return WebDavSettingsService();
});

final webDavConfigProvider = FutureProvider<WebDavConfig?>((ref) async {
  return ref.read(webDavSettingsServiceProvider).getConfig();
});

final webDavProfilesStateProvider = FutureProvider<WebDavProfilesState>((
  ref,
) async {
  return ref.read(webDavSettingsServiceProvider).getProfilesState();
});
