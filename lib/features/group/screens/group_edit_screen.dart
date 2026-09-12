import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class GroupEditScreen extends ConsumerStatefulWidget {
  final String groupPath;
  const GroupEditScreen({super.key, required this.groupPath});

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newGroup),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clay icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.15),
                          colorScheme.tertiary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.create_new_folder_rounded, size: 34, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.groupName,
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final service = ref.read(databaseServiceProvider);
    final parent = service.findGroupByPath(widget.groupPath);
    if (parent == null) return;

    service.createGroup(parent, _nameCtrl.text);
    refreshExplorerLists(ref);
    if (mounted) context.pop();
  }
}
