import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../features/database/data/database_service.dart';
import 'toast.dart';

/// Displays entry attachments with optional add/delete/download actions.
class AttachmentsSection extends StatelessWidget {
  final KdbxEntry entry;
  final DatabaseService service;
  final bool readOnly;
  final VoidCallback? onChanged;

  const AttachmentsSection({
    super.key,
    required this.entry,
    required this.service,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final binaries = service.db?.binaries;
    final attachments = entry.binaries.entries.toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: ClayDecoration.card(brightness: brightness, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.attachments,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (attachments.isNotEmpty)
            for (int i = 0; i < attachments.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                ),
              _AttachmentTile(
                name: attachments[i].key,
                binaryRef: attachments[i].value,
                binaries: binaries,
                readOnly: readOnly,
                onDownload: () => _downloadAttachment(context, attachments[i].key, attachments[i].value),
                onDelete: readOnly ? null : () => _deleteAttachment(context, attachments[i].key),
              ),
            ],
          if (!readOnly) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addAttachment(context),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(l10n.addAttachment),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          if (attachments.isEmpty && readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.noAttachments,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addAttachment(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;

      final db = service.db;
      if (db == null) return;

      final binary = PlainBinary(data: bytes, compressed: true);
      final ref = db.binaries.add(binary);
      entry.binaries[file.name] = ref;
      service.markDirty();
      if (context.mounted) showToast(context, l10n.attachmentAdded);
      onChanged?.call();
    } catch (e) {
      log.e('Add attachment failed', error: e);
    }
  }

  Future<void> _downloadAttachment(BuildContext context, String name, BinaryReference ref) async {
    final l10n = AppLocalizations.of(context)!;
    final binaries = service.db?.binaries;
    if (binaries == null) return;
    final data = binaries.getByRef(ref);
    if (data == null) return;

    try {
      // Android/iOS saveFile requires the payload up front.
      final savePath = await FilePicker.platform.saveFile(
        fileName: name,
        bytes: (Platform.isAndroid || Platform.isIOS)
            ? Uint8List.fromList(data.data)
            : null,
      );
      if (savePath == null) return;
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savePath).writeAsBytes(data.data);
      }
      if (context.mounted) showToast(context, l10n.attachmentSaved);
    } catch (e) {
      log.e('Save attachment failed', error: e);
    }
  }

  void _deleteAttachment(BuildContext context, String name) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAttachment),
        content: Text(l10n.deleteAttachmentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              entry.binaries.remove(name);
              service.markDirty();
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, l10n.attachmentDeleted);
              onChanged?.call();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final String name;
  final BinaryReference binaryRef;
  final KdbxBinaries? binaries;
  final bool readOnly;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const _AttachmentTile({
    required this.name,
    required this.binaryRef,
    required this.binaries,
    required this.readOnly,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = binaries?.getByRef(binaryRef);
    final size = data?.data.length ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.attach_file_rounded, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                ),
                Text(
                  _formatSize(size),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onDownload != null)
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                icon: Icon(Icons.download_rounded, size: 15, color: colorScheme.primary),
                padding: EdgeInsets.zero,
                onPressed: onDownload,
              ),
            ),
          if (onDelete != null)
            SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                icon: Icon(Icons.close_rounded, size: 15, color: colorScheme.error),
                padding: EdgeInsets.zero,
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) => FormatUtils.formatSize(bytes);
}
