import 'package:material_ui/material_ui.dart';
import 'package:kpasslib/kpasslib.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_utils.dart';
import '../../features/totp/data/totp_service.dart';
import '../../l10n/app_localizations.dart';
import 'toast.dart';
import '../utils/fuzzy_match.dart';

class EntryListTile extends StatefulWidget {
  final KdbxEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onMove;
  final String? query;
  final bool showCheckbox;
  final bool isChecked;
  final bool draggable;

  static final _totpService = TotpService();

  const EntryListTile({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.onTap,
    this.onOpen,
    this.onDelete,
    this.onRestore,
    this.onMove,
    this.query,
    this.showCheckbox = false,
    this.isChecked = false,
    this.draggable = false,
  });

  @override
  State<EntryListTile> createState() => _EntryListTileState();
}

class _EntryListTileState extends State<EntryListTile> {
  bool _hovered = false;

  String get _title => widget.entry.fields['Title']?.text ?? '';
  String get _username => widget.entry.fields['UserName']?.text ?? '';
  String get _password => widget.entry.fields['Password']?.text ?? '';
  bool get _isExpired =>
      widget.entry.times.expires &&
      widget.entry.times.expiry.time != null &&
      widget.entry.times.expiry.time!.isBefore(DateTime.now());

  String? _getTotpCode() {
    final config = EntryListTile._totpService.loadFromEntry(widget.entry);
    if (config == null) return null;
    return EntryListTile._totpService.generateCode(config);
  }

  Widget _highlightedTitle(
    String text,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final titleStyle = textTheme.titleSmall;
    if (widget.query == null || widget.query!.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );
    }
    final match = fuzzyMatch(text, widget.query!);
    if (match == null || !match.isMatch) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );
    }
    final positions = match.positions.toSet();
    final normalStyle = titleStyle;
    final highlightStyle = titleStyle?.copyWith(
      color: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
    );
    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final isHighlight = positions.contains(i);
      int j = i + 1;
      while (j < text.length && positions.contains(j) == isHighlight) {
        j++;
      }
      spans.add(
        TextSpan(
          text: text.substring(i, j),
          style: isHighlight ? highlightStyle : normalStyle,
        ),
      );
      i = j;
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screenSize = overlay.size;
    final position = RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      screenSize.width - globalPos.dx,
      screenSize.height - globalPos.dy,
    );
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'copy_password',
        child: ListTile(
          leading: const Icon(Icons.copy_rounded),
          title: Text(l10n.copyPassword),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem(
        value: 'copy_username',
        child: ListTile(
          leading: const Icon(Icons.person_rounded),
          title: Text(l10n.copyUsername),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
    final url = widget.entry.fields['URL']?.text ?? '';
    if (url.isNotEmpty) {
      items.add(
        PopupMenuItem(
          value: 'copy_url',
          child: ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(l10n.copyUrl),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    final hasTotp = EntryListTile._totpService.hasTotp(widget.entry);
    if (hasTotp) {
      items.add(
        PopupMenuItem(
          value: 'copy_totp',
          child: ListTile(
            leading: const Icon(Icons.timer_rounded),
            title: Text(l10n.copyTotp),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    if (widget.onMove != null) {
      items.add(
        PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: const Icon(Icons.drive_file_move_rounded),
            title: Text(l10n.move),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    if (widget.onRestore != null) {
      items.add(
        PopupMenuItem(
          value: 'restore',
          child: ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: Text(l10n.restore),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    if (widget.onDelete != null) {
      items.add(
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(
              widget.onRestore != null ? l10n.permanentDelete : l10n.delete,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
    showMenu<String>(context: context, position: position, items: items).then((
      value,
    ) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'copy_password':
          copyToClipboardWithAutoClear(_password);
          showToast(context, l10n.copiedPassword);
        case 'copy_username':
          if (_username.isNotEmpty) {
            copyToClipboardWithAutoClear(_username);
            showToast(context, l10n.copiedUsername);
          }
        case 'copy_url':
          copyToClipboardWithAutoClear(widget.entry.fields['URL']?.text ?? '');
          showToast(context, l10n.copiedUrl);
        case 'copy_totp':
          final totpCode = _getTotpCode();
          if (totpCode != null) {
            copyToClipboardWithAutoClear(totpCode);
            showToast(context, l10n.copiedTotp);
          }
        case 'move':
          widget.onMove?.call();
        case 'restore':
          widget.onRestore?.call();
        case 'delete':
          widget.onDelete?.call();
      }
    });
  }

  Widget _actionButton({
    required ColorScheme colorScheme,
    required IconData icon,
    required double iconSize,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: ClayLayout.iconButton,
      height: ClayLayout.iconButton,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ClayLayout.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(ClayLayout.radiusSm),
          onTap: onTap,
          child: Icon(
            icon,
            size: iconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _title.isEmpty ? l10n.untitled : _title;
    final dense = ClayLayout.isDesktopPlatform(context);
    final radius = ClayLayout.radiusLg;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final tile = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? ClayLayout.space12 : ClayLayout.space12,
        vertical: dense ? 2 : 3,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: ClayDecoration.listShadow(brightness),
        ),
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : ClayLayout.motionFast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer
                : _hovered
                ? colorScheme.surfaceContainerLow
                : (brightness == Brightness.dark
                      ? ClayColors.surfaceCardDark
                      : ClayColors.surfaceCardLight),
            borderRadius: BorderRadius.circular(radius),
            border: widget.isSelected
                ? Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: brightness == Brightness.dark ? 0.55 : 0.35,
                    ),
                  )
                : Border.all(color: colorScheme.outline),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: widget.onTap,
              onHover: dense
                  ? (v) {
                      if (_hovered != v) setState(() => _hovered = v);
                    }
                  : null,
              onSecondaryTapUp: (details) =>
                  _showContextMenu(context, details.globalPosition),
              onLongPress: () {
                final box = context.findRenderObject() as RenderBox?;
                final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                final size = box?.size ?? Size.zero;
                _showContextMenu(
                  context,
                  Offset(pos.dx + size.width / 2, pos.dy + size.height / 2),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: dense ? 48 : ClayLayout.touchMin,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ClayLayout.space12,
                    vertical: dense ? ClayLayout.space8 : ClayLayout.space12,
                  ),
                  child: Row(
                    children: [
                      if (widget.showCheckbox) ...[
                        Checkbox(
                          value: widget.isChecked,
                          onChanged: widget.onTap != null
                              ? (_) => widget.onTap!()
                              : null,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: ClayLayout.space8),
                      ],
                      Container(
                        width: dense ? 36 : 40,
                        height: dense ? 36 : 40,
                        decoration: ClayDecoration.iconContainer(
                          brightness: brightness,
                          radius: 12,
                        ),
                        child: Icon(
                          _getIcon(widget.entry.icon),
                          size: dense ? 18 : 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: ClayLayout.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _highlightedTitle(
                              displayTitle,
                              colorScheme,
                              textTheme,
                            ),
                            if (_username.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ],
                            if (widget.entry.tags != null &&
                                widget.entry.tags!.isNotEmpty) ...[
                              const SizedBox(height: ClayLayout.space4),
                              Wrap(
                                spacing: ClayLayout.space4,
                                runSpacing: 2,
                                children: [
                                  for (final tag in widget.entry.tags!)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer
                                            .withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tag,
                                        style: textTheme.labelSmall?.copyWith(
                                          fontSize: 10,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isExpired) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                size: 12,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                l10n.expired,
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: ClayLayout.space8),
                      ],
                      if (_password.isNotEmpty)
                        _actionButton(
                          colorScheme: colorScheme,
                          icon: Icons.copy_rounded,
                          iconSize: 16,
                          onTap: () {
                            copyToClipboardWithAutoClear(_password);
                            showToast(context, l10n.copiedPassword);
                          },
                        ),
                      const SizedBox(width: ClayLayout.space8),
                      _actionButton(
                        colorScheme: colorScheme,
                        icon: Icons.chevron_right_rounded,
                        iconSize: 20,
                        onTap: widget.onOpen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.draggable) return tile;

    return LongPressDraggable<KdbxEntry>(
      data: widget.entry,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(widget.entry.icon),
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}

IconData _getIcon(KdbxIcon icon) {
  return switch (icon) {
    KdbxIcon.key => Icons.key_rounded,
    KdbxIcon.world => Icons.language_rounded,
    KdbxIcon.networkServer => Icons.dns_rounded,
    KdbxIcon.eMail ||
    KdbxIcon.eMailBox ||
    KdbxIcon.eMailSearch => Icons.email_rounded,
    KdbxIcon.userCommunication || KdbxIcon.identity => Icons.person_rounded,
    KdbxIcon.homebanking || KdbxIcon.money => Icons.account_balance_rounded,
    KdbxIcon.certificate => Icons.verified_rounded,
    KdbxIcon.terminalEncrypted || KdbxIcon.console => Icons.terminal_rounded,
    KdbxIcon.drive ||
    KdbxIcon.driveWindows ||
    KdbxIcon.disk => Icons.storage_rounded,
    KdbxIcon.clipboardReady => Icons.content_paste_rounded,
    KdbxIcon.note || KdbxIcon.notepad => Icons.note_rounded,
    KdbxIcon.settings || KdbxIcon.configuration => Icons.settings_rounded,
    KdbxIcon.star => Icons.star_rounded,
    KdbxIcon.tool => Icons.build_rounded,
    KdbxIcon.home => Icons.home_rounded,
    KdbxIcon.book => Icons.book_rounded,
    KdbxIcon.list => Icons.list_rounded,
    KdbxIcon.package => Icons.inventory_2_rounded,
    KdbxIcon.clock => Icons.access_time_rounded,
    KdbxIcon.trashBin => Icons.delete_rounded,
    _ => Icons.key_rounded,
  };
}
