import 'package:material_ui/material_ui.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../core/widgets/button_label.dart';
import '../../../l10n/app_localizations.dart';

/// Shows a compact entry picker for AutoType. Designed to be shown without
/// stealing focus from the target window so the typed sequence lands where
/// the user was working. Return the chosen entry, or null to cancel.
Future<KdbxEntry?> showAutoTypeEntryPicker(
  BuildContext context,
  List<KdbxEntry> candidates,
) {
  return showDialog<KdbxEntry>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _AutoTypeEntryPicker(candidates: candidates),
  );
}

class _AutoTypeEntryPicker extends StatefulWidget {
  final List<KdbxEntry> candidates;

  const _AutoTypeEntryPicker({required this.candidates});

  @override
  State<_AutoTypeEntryPicker> createState() => _AutoTypeEntryPickerState();
}

class _AutoTypeEntryPickerState extends State<_AutoTypeEntryPicker> {
  final _filterCtrl = TextEditingController();
  late List<KdbxEntry> _filtered;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filtered = widget.candidates;
    _filterCtrl.addListener(_applyFilter);
  }

  void _applyFilter() {
    final query = _filterCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.candidates
          : widget.candidates.where((entry) {
              final title = entry.fields['Title']?.text.toLowerCase() ?? '';
              final username =
                  entry.fields['UserName']?.text.toLowerCase() ?? '';
              return title.contains(query) || username.contains(query);
            }).toList();
    });
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.autotypePickTitle)),
          Text(
            'Ctrl+Alt+A',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _filterCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchEntries,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResults,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final entry = _filtered[index];
                        final title = entry.fields['Title']?.text ?? '';
                        final username =
                            entry.fields['UserName']?.text ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.key_rounded, size: 20),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: username.isEmpty
                              ? null
                              : Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.of(context).pop(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: ButtonLabel(l10n.cancel),
        ),
      ],
    );
  }
}
