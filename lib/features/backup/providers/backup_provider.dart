import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers/database_provider.dart';
import '../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final backupListProvider = FutureProvider<List<BackupInfo>>((ref) async {
  final filePath = ref.read(databaseServiceProvider).filePath;
  if (filePath == null) return [];
  return ref.read(backupServiceProvider).listBackupsFor(filePath);
});

final backupRetentionProvider = FutureProvider<int>((ref) async {
  return ref.read(backupServiceProvider).getRetentionCount();
});

final autoBackupEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(backupServiceProvider).isAutoBackupEnabled();
});
