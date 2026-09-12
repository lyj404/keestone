import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';

/// A reusable key file picker widget.
class KeyFilePicker extends StatelessWidget {
  final Uint8List? keyData;
  final String? keyFileName;
  final ValueChanged<Uint8List?> onKeyDataChanged;
  final ValueChanged<String?> onKeyNameChanged;

  const KeyFilePicker({
    super.key,
    this.keyData,
    this.keyFileName,
    required this.onKeyDataChanged,
    required this.onKeyNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return keyData != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    keyFileName ?? l10n.keyFileSelected,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    onKeyDataChanged(null);
                    onKeyNameChanged(null);
                  },
                  tooltip: l10n.removeKeyFile,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          )
        : OutlinedButton.icon(
            onPressed: _pickKeyFile,
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: Text(l10n.selectKeyFile),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
  }

  Future<void> _pickKeyFile() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file != null) {
      final bytes = await file.readAsBytes();
      onKeyDataChanged(bytes);
      onKeyNameChanged(file.name);
    }
  }
}
