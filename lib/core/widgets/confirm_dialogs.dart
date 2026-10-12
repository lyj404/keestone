import 'package:material_ui/material_ui.dart';
import '../../l10n/app_localizations.dart';
import 'button_label.dart';

/// Shows a confirmation dialog for delete operations.
/// Returns true if confirmed, false if cancelled.
Future<bool> showConfirmDeleteDialog({
  required BuildContext context,
  required String title,
  required String message,
  bool isPermanent = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;

  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: ButtonLabel(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: ButtonLabel(isPermanent ? l10n.permanentDelete : l10n.delete),
        ),
      ],
    ),
  ) ?? false;
}

/// Shows a confirmation dialog for moving items to recycle bin.
Future<bool> showMoveToRecycleBinDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return showConfirmDeleteDialog(
    context: context,
    title: title,
    message: message,
    isPermanent: false,
  );
}

/// Shows a confirmation dialog for permanent deletion.
Future<bool> showPermanentDeleteDialog({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return showConfirmDeleteDialog(
    context: context,
    title: title,
    message: message,
    isPermanent: true,
  );
}
