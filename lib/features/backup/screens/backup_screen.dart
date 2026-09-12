import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../data/backup_service.dart';
import '../providers/backup_provider.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final backupsAsync = ref.watch(backupListProvider);
    final autoBackupAsync = ref.watch(autoBackupEnabledProvider);
    final retentionAsync = ref.watch(backupRetentionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.databaseBackup)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Settings area
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    // Auto-backup toggle
                    Container(
                      decoration: ClayDecoration.card(
                        brightness: brightness,
                        radius: ClayLayout.radiusLg,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: ClayDecoration.iconContainer(
                              brightness: brightness,
                            ),
                            child: Icon(
                              Icons.sync_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.autoBackup,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  l10n.autoBackupDescription,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          autoBackupAsync.when(
                            data: (enabled) => Switch(
                              value: enabled,
                              onChanged: (v) async {
                                await ref
                                    .read(backupServiceProvider)
                                    .setAutoBackupEnabled(v);
                                ref.invalidate(autoBackupEnabledProvider);
                              },
                              activeThumbColor: colorScheme.primary,
                            ),
                            loading: () =>
                                const SizedBox(width: 48, height: 32),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Retention count
                    Container(
                      decoration: ClayDecoration.card(
                        brightness: brightness,
                        radius: ClayLayout.radiusLg,
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: ClayDecoration.iconContainer(
                              brightness: brightness,
                            ),
                            child: Icon(
                              Icons.inventory_2_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.backupRetention,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          retentionAsync.when(
                            data: (count) => DropdownButton<int>(
                              value: count,
                              focusColor: ClayDecoration.dropdownFocusColor,
                              underline: const SizedBox.shrink(),
                              items: [3, 5, 10, 20]
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text(l10n.backupRetentionCount(n)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                if (v != null) {
                                  await ref
                                      .read(backupServiceProvider)
                                      .setRetentionCount(v);
                                  ref.invalidate(backupRetentionProvider);
                                }
                              },
                            ),
                            loading: () =>
                                const SizedBox(width: 48, height: 32),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Manual backup button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: _createManualBackup,
                        icon: const Icon(Icons.backup_rounded, size: 20),
                        label: Text(l10n.createBackupNow),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Backup list
              Expanded(
                child: backupsAsync.when(
                  data: (backups) {
                    if (backups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noBackups,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      addAutomaticKeepAlives: false,
                      scrollCacheExtent: const ScrollCacheExtent.pixels(200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: backups.length,
                      itemBuilder: (ctx, i) {
                        final backup = backups[i];
                        return _BackupTile(
                          backup: backup,
                          brightness: brightness,
                          onRestore: () => _restoreBackup(backup.filename),
                          onDelete: () => _deleteBackup(backup.filename),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('${l10n.error}: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createManualBackup() async {
    final filePath = ref.read(databaseServiceProvider).filePath;
    if (filePath == null) return;
    final backup = await ref.read(backupServiceProvider).createBackup(filePath);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (backup != null) {
      showToast(context, l10n.backupCreated);
    } else {
      showToast(context, l10n.backupFailed);
    }
    ref.invalidate(backupListProvider);
  }

  Future<void> _restoreBackup(String filename) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreBackup),
        content: Text(l10n.restoreBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(databaseServiceProvider);
    final notifier = ref.read(databaseProvider.notifier);

    final verification = await ref
        .read(backupServiceProvider)
        .verifyAndReadBackup(filename);
    if (!mounted) return;
    if (!verification.canRestore || verification.bytes == null) {
      final message = switch (verification.status) {
        BackupIntegrityStatus.missing => l10n.backupNotFound,
        BackupIntegrityStatus.corrupted => l10n.backupIntegrityFailed,
        BackupIntegrityStatus.invalid => l10n.backupIntegrityFailed,
        _ => l10n.backupRestoreFailed,
      };
      showToast(context, message, isError: true);
      return;
    }
    final bytes = verification.bytes!;

    // Only create a safety backup after the selected backup passed integrity
    // validation, so corrupt input cannot trigger any restore side effects.
    if (service.filePath != null) {
      await ref.read(backupServiceProvider).createBackup(service.filePath!);
      if (!mounted) return;
    }
    try {
      final restored = await notifier.restoreBackupBytes(bytes);
      if (!mounted) return;
      showToast(
        context,
        restored ? l10n.backupRestored : l10n.syncFailed,
        isError: !restored,
      );
      ref.invalidate(backupListProvider);
      if (restored) {
        context.go('/explorer');
      }
    } on InvalidCredentialsError {
      // Backup was encrypted with a different password (likely changed after backup)
      if (!mounted) return;
      final backupPassword = await _askBackupPassword();
      if (backupPassword == null) return;
      try {
        final restored = await notifier.restoreBackupBytes(
          bytes,
          password: backupPassword,
        );
        if (!mounted) return;
        showToast(
          context,
          restored ? l10n.backupRestored : l10n.syncFailed,
          isError: !restored,
        );
        ref.invalidate(backupListProvider);
        if (restored) {
          context.go('/explorer');
        }
      } catch (e) {
        if (!mounted) return;
        showToast(context, l10n.backupRestoreFailed, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is KdbxError ? e.message : e.toString();
      showToast(context, '${l10n.backupRestoreFailed}: $msg', isError: true);
    }
  }

  Future<String?> _askBackupPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.masterPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backupPasswordDifferent,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.backupPasswordHint),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(String filename) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBackup),
        content: Text(l10n.deleteBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(backupServiceProvider).deleteBackup(filename);
    if (!mounted) return;
    showToast(context, l10n.backupDeleted);
    ref.invalidate(backupListProvider);
  }
}

class _BackupTile extends StatelessWidget {
  final BackupInfo backup;
  final Brightness brightness;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _BackupTile({
    required this.backup,
    required this.brightness,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizeStr = _formatSize(backup.sizeBytes);
    final timeStr = _formatTime(backup.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        decoration: ClayDecoration.card(brightness: brightness),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
            onTap: onRestore,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ClayDecoration.iconContainer(
                      brightness: brightness,
                      radius: 13,
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backup.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$timeStr · $sizeStr',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Restore button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onRestore,
                        child: Icon(
                          Icons.settings_backup_restore_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Delete button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onDelete,
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) => FormatUtils.formatSize(bytes);

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
