part of 'explorer_screen.dart';

class _TagFilterBar extends ConsumerWidget {
  const _TagFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTags = ref.watch(allTagsProvider);
    if (allTags.isEmpty) return const SizedBox.shrink();

    final selectedTag = ref.watch(selectedTagProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allTags.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Icon(
                Icons.label_outline_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            );
          }
          if (index == 1) {
            return Row(
              children: [
                const SizedBox(width: 4),
                _TagChip(
                  label: l10n.allTags,
                  selected: selectedTag == null,
                  onTap: () =>
                      ref.read(selectedTagProvider.notifier).state = null,
                ),
              ],
            );
          }
          final tag = allTags[index - 2];
          return _TagChip(
            label: tag,
            selected: selectedTag == tag,
            onTap: () => ref.read(selectedTagProvider.notifier).state =
                selectedTag == tag ? null : tag,
          );
        },
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shortcut hint bar ─────────────────────────────────────────────────

class _ShortcutHintBar extends StatelessWidget {
  final KdbxEntry entry;
  const _ShortcutHintBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final username = entry.fields['UserName']?.text ?? '';
    final password = entry.fields['Password']?.text ?? '';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.keyboard_rounded,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) ...[
            const _KeyChip(label: 'Ctrl+F'),
            const SizedBox(width: 4),
            Text(
              l10n.shortcutSearch,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            const _KeyChip(label: 'Ctrl+S'),
            const SizedBox(width: 4),
            Text(
              l10n.shortcutSave,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (username.isNotEmpty) ...[
            const _KeyChip(label: 'Ctrl+B'),
            const SizedBox(width: 4),
            Text(
              l10n.copyUsername,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (password.isNotEmpty) ...[
            const _KeyChip(label: 'Ctrl+C'),
            const SizedBox(width: 4),
            Text(
              l10n.copyPassword,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
          ],
          const _KeyChip(label: 'Ctrl+U'),
          const SizedBox(width: 4),
          Text(
            l10n.copyUrl,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          const _KeyChip(label: 'Ctrl+T'),
          const SizedBox(width: 4),
          Text(
            l10n.copyTotp,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String label;
  const _KeyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─── Sync helpers ───────────────────────────────────────────────────────

Future<void> _syncToCloud(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;
  final notifier = container.read(databaseProvider.notifier);
  final isCloud = container.read(openedFromCloudProvider);

  // A local database must first be linked to the active WebDAV profile.
  // getConfigById(null) resolves the active profile when no profile is bound
  // yet, so this also validates that cloud sync is actually configured.
  final config = isCloud
      ? await container
            .read(webDavSettingsServiceProvider)
            .getConfigById(
              (await container.read(recentFilesServiceProvider).getLastOpenedFile())
                  ?.webDavProfileId,
            )
      : await container.read(webDavSettingsServiceProvider).getConfig();
  if (config == null || !config.enabled) {
    if (context.mounted) {
      showToast(context, l10n.pleaseConfigureWebDAV, isError: true);
      unawaited(context.push('/settings'));
    }
    return;
  }
  if (!context.mounted) return;
  unawaited(
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.uploadingToCloud,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ),
    ),
  );
  try {
    if (isCloud) {
      await notifier.forceUpload();
    } else {
      // Links the open local database to the cloud and uploads it, reporting
      // a conflict if the remote path already holds a database.
      await notifier.syncLocalToCloud();
    }
    if (context.mounted) {
      Navigator.of(context).pop();
      final syncState = container.read(syncStateProvider);
      if (syncState == SyncState.success) {
        showToast(context, l10n.syncedToCloud);
      } else if (syncState == SyncState.conflict) {
        _showSyncToCloudConflictDialog(context);
      } else {
        final error = container.read(databaseProvider.notifier).lastSyncError;
        if (context.mounted) {
          _showSyncErrorDialog(
            context,
            _translateSyncError(error ?? Exception('unknown'), l10n),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSyncErrorDialog(context, _translateSyncError(e, l10n));
    }
  }
}

/// Shown when linking a local database to the cloud finds an existing remote
/// database. The user chooses to pull the cloud version down (discarding local
/// changes) or to overwrite the cloud copy with the local one.
void _showSyncToCloudConflictDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final container = ProviderScope.containerOf(context);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.syncConflict),
      content: Text(l10n.syncConflictMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: ButtonLabel(l10n.cancel),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _syncFromCloud(context);
          },
          child: ButtonLabel(l10n.downloadCloudVersion),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await container.read(databaseProvider.notifier).forceUpload();
            if (context.mounted) {
              final syncState = container.read(syncStateProvider);
              if (syncState == SyncState.success) {
                showToast(context, l10n.overwrittenToCloud);
              } else {
                showToast(context, l10n.syncFailed, isError: true);
              }
            }
          },
          child: ButtonLabel(l10n.overwriteCloud),
        ),
      ],
    ),
  );
}

Future<void> _syncFromCloud(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;
  final recent = await container
      .read(recentFilesServiceProvider)
      .getLastOpenedFile();
  final config = await container
      .read(webDavSettingsServiceProvider)
      .getConfigById(recent?.webDavProfileId);
  if (config == null || !config.enabled) {
    if (context.mounted) {
      _showSyncErrorDialog(context, l10n.pleaseConfigureWebDAV);
    }
    return;
  }
  if (!context.mounted) return;
  final syncService = container.read(syncServiceProvider);
  final bool exists;
  try {
    exists = await syncService.remoteFileExists(config);
  } catch (e) {
    // Auth/network failure must not be presented as "cloud has no database"
    // — that would guide the user into creating/overwriting a real one.
    log.e('Remote file probe failed before sync', error: e);
    if (context.mounted) {
      _showSyncErrorDialog(context, l10n.syncFailed);
    }
    return;
  }
  if (!exists) {
    if (context.mounted) {
      _showSyncErrorDialog(context, l10n.cloudNoDatabaseSaveFirst);
    }
    return;
  }
  if (!context.mounted) return;
  unawaited(
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.downloadingFromCloudShort,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final container = ProviderScope.containerOf(context);
    await container.read(databaseProvider.notifier).reloadFromCloud();
    container.invalidate(entriesProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
      showToast(context, l10n.syncedFromCloud);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSyncErrorDialog(context, _translateSyncError(e, l10n));
    }
  }
}

String _translateSyncError(Object e, AppLocalizations l10n) {
  if (e is SyncException) {
    switch (e.type) {
      case SyncErrorType.network:
        return l10n.syncErrorNetwork;
      case SyncErrorType.auth:
        return l10n.syncErrorAuth;
      case SyncErrorType.notFound:
        return l10n.syncErrorNotFound;
      case SyncErrorType.timeout:
        return l10n.syncErrorTimeout;
      case SyncErrorType.conflict:
        return l10n.syncConflict;
      case SyncErrorType.serverError:
        return l10n.syncErrorServer;
      case SyncErrorType.unknown:
        break;
    }
  }
  final msg = e.toString().replaceFirst('Exception: ', '');
  if (msg == 'please_configure_webdav') return l10n.pleaseConfigureWebDAVFirst;
  if (msg == 'cloud_database_not_exist') return l10n.cloudDatabaseNotExist;
  if (msg == 'remote_database_not_exist') return l10n.remoteDatabaseNotExist;
  return l10n.syncFailedWithError(msg);
}

void _showSyncErrorDialog(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(l10n.cancel),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/settings');
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(l10n.goToSettings),
        ),
      ],
    ),
  );
}
