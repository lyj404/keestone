import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';

import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../settings/providers/username_suggest_provider.dart';

/// Usernames already present in the vault, deduplicated, sorted by
/// frequency then alphabetically. Excludes the entry currently being edited
/// (via [excludeEntry]) and recycle-bin entries.
List<String> collectVaultUsernames(WidgetRef ref, {KdbxEntry? excludeEntry}) {
  final service = ref.read(databaseServiceProvider);
  final counts = <String, int>{};
  for (final entry in service.allEntries) {
    if (identical(entry, excludeEntry)) continue;
    final username = entry.fields['UserName']?.text.trim() ?? '';
    if (username.isEmpty) continue;
    counts[username] = (counts[username] ?? 0) + 1;
  }
  final names = counts.keys.toList();
  names.sort((a, b) {
    final byCount = counts[b]!.compareTo(counts[a]!);
    if (byCount != 0) return byCount;
    return a.toLowerCase().compareTo(b.toLowerCase());
  });
  return names;
}

/// Username field with vault-backed autocompletion. Wraps a TextFormField;
/// when the suggest setting is enabled, typing shows matching usernames
/// from the current database for one-tap selection. Works on mobile
/// (touch) and desktop (keyboard arrows + enter).
class UsernameSuggestField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final KdbxEntry? excludeEntry;
  final InputDecoration? decoration;
  final bool enabled;
  final VoidCallback? onChanged;
  final FormFieldValidator<String>? validator;

  const UsernameSuggestField({
    super.key,
    required this.controller,
    required this.labelText,
    this.excludeEntry,
    this.decoration,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  ConsumerState<UsernameSuggestField> createState() =>
      _UsernameSuggestFieldState();
}

class _UsernameSuggestFieldState extends ConsumerState<UsernameSuggestField> {
  List<String> _allUsernames = const [];
  late final FocusNode _focusNode;
  bool _collected = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocus);
    widget.controller.addListener(_onChanged);
  }

  /// Collect the candidate pool when the field gains focus: cheap enough
  /// once per session, and guarantees suggestions exist from the very first
  /// keystroke.
  void _onFocus() {
    if (_focusNode.hasFocus && !_collected) {
      _collected = true;
      setState(() {
        _allUsernames =
            collectVaultUsernames(ref, excludeEntry: widget.excludeEntry);
      });
    }
  }

  void _onChanged() {
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestEnabled = ref.watch(usernameSuggestProvider);
    if (!suggestEnabled || !widget.enabled) {
      return TextFormField(
        controller: widget.controller,
        decoration: widget.decoration ??
            InputDecoration(
              labelText: widget.labelText,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
        enabled: widget.enabled,
        validator: widget.validator,
      );
    }

    final options = _allUsernames;

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return options.where((name) {
          final lower = name.toLowerCase();
          // Match by prefix or by containing the query (e.g. domain part).
          return lower.startsWith(query) || lower.contains(query);
        }).take(8);
      },
      displayStringForOption: (option) => option,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: widget.decoration ??
              InputDecoration(
                labelText: widget.labelText,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
          enabled: widget.enabled,
          validator: widget.validator,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline_rounded, size: 18),
                    title: Text(option, maxLines: 1),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Settings tile content: switch controlling [usernameSuggestProvider].
class UsernameSuggestToggle extends ConsumerWidget {
  const UsernameSuggestToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = ref.watch(usernameSuggestProvider);
    return SwitchListTile(
      title: Text(l10n.usernameSuggestTitle),
      subtitle: Text(l10n.usernameSuggestSubtitle),
      value: enabled,
      onChanged: (v) =>
          ref.read(usernameSuggestProvider.notifier).setEnabled(v),
    );
  }
}
