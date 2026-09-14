import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../data/totp_service.dart';
import '../data/totp_ticker.dart';

class TotpDisplayWidget extends ConsumerStatefulWidget {
  final KdbxEntry entry;
  const TotpDisplayWidget({super.key, required this.entry});

  @override
  ConsumerState<TotpDisplayWidget> createState() => _TotpDisplayWidgetState();
}

class _TotpDisplayWidgetState extends ConsumerState<TotpDisplayWidget> {
  final _totpService = TotpService();
  TotpConfig? _config;
  String _code = '';
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant TotpDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when the underlying entry instance changes (e.g. after cloud
    // sync replaces the whole database) or when a different entry is passed.
    if (!identical(widget.entry, oldWidget.entry)) {
      TotpTicker.instance.removeListener(_onTick);
      _config = null;
      _code = '';
      _remaining = 0;
      _loadConfig();
    }
  }

  @override
  void dispose() {
    TotpTicker.instance.removeListener(_onTick);
    super.dispose();
  }

  void _loadConfig() {
    try {
      _config = _totpService.loadFromEntry(widget.entry);
    } catch (_) {
      _config = null;
    }
    if (_config != null) {
      _updateCode(force: true);
      TotpTicker.instance.addListener(_onTick);
    }
  }

  /// Called once per second by the shared ticker. The code only changes when
  /// the period wraps (remaining jumps back up), so the HMAC is recomputed
  /// once per period instead of on every tick.
  void _onTick() {
    _updateCode();
  }

  void _updateCode({bool force = false}) {
    final config = _config;
    if (config == null) return;
    final newRemaining = _totpService.remainingSeconds(config);
    String newCode;
    try {
      newCode = force || newRemaining > _remaining
          ? _totpService.generateCode(config)
          : _code;
    } catch (_) {
      newCode = '';
    }
    if (mounted && (newCode != _code || newRemaining != _remaining)) {
      setState(() {
        _code = newCode;
        _remaining = newRemaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final brightness = Theme.of(context).brightness;
    final isLow = _remaining <= 5;
    final progress = _remaining / _config!.period;

    final codeDisplay = _code.length == 6
        ? '${_code.substring(0, 3)} ${_code.substring(3)}'
        : _code;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: ClayDecoration.card(brightness: brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'TOTP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  tooltip: l10n.copy,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    copyToClipboardWithAutoClear(_code);
                    showToast(context, l10n.copiedField('TOTP'));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  codeDisplay,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isLow ? colorScheme.error : colorScheme.onSurface,
                    letterSpacing: 4,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLow ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$_remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isLow ? colorScheme.error : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
