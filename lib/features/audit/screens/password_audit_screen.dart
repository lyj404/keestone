import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/logger.dart';
import '../../../core/widgets/button_label.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../data/hibp_service.dart';
import '../data/password_audit_service.dart';

class PasswordAuditScreen extends ConsumerStatefulWidget {
  const PasswordAuditScreen({super.key});

  @override
  ConsumerState<PasswordAuditScreen> createState() =>
      _PasswordAuditScreenState();
}

class _PasswordAuditScreenState extends ConsumerState<PasswordAuditScreen> {
  PasswordIssueKind? _filter;
  PasswordAuditReport? _report;
  bool _scanning = false;
  bool _checkingBreaches = false;
  Map<String, int>? _pwnedCounts;
  bool _breachCheckFailed = false;
  int _breachProgress = 0;
  int _breachTotal = 0;

  final _hibpService = HibpService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescan());
  }

  Future<void> _rescan() async {
    if (_scanning) return;
    final db = ref.read(databaseProvider).value;
    final service = ref.read(databaseServiceProvider);
    if (db == null || !service.isOpen) {
      setState(() => _report = null);
      return;
    }
    setState(() => _scanning = true);
    try {
      final data = [
        for (final e in service.allEntries)
          if (!service.isInRecycleBin(e))
            PasswordAuditEntryData(
              uuid: e.uuid.string,
              title: e.fields['Title']?.text ?? '',
              groupPath: e.parent == null
                  ? ''
                  : service.getGroupPath(e.parent!),
              password: e.fields['Password']?.text ?? '',
              expires: e.times.expires,
              expiry: e.times.expiry.time,
            ),
      ];
      final report = await analyzePasswordAuditSnapshots(data);
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _report = report;
        _pwnedCounts = null;
        _breachCheckFailed = false;
      });
    } catch (e, st) {
      log.e('Password audit scan failed', error: e, stackTrace: st);
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Explicit, networked breach check (HIBP, k-anonymity). Prompts before
  /// any traffic leaves the device, then checks every non-bin entry with a
  /// password and caches pwned counts for [_reportWithBreaches] to merge.
  Future<void> _checkBreaches() async {
    if (_checkingBreaches || _scanning) return;
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider).value;
    final service = ref.read(databaseServiceProvider);
    if (db == null || !service.isOpen) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.hibpConfirmTitle),
        content: Text(l10n.hibpConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: ButtonLabel(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: ButtonLabel(l10n.hibpConfirmRun),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final candidates = <(String, String)>[];
    for (final e in service.allEntries) {
      if (service.isInRecycleBin(e)) continue;
      final password = e.fields['Password']?.text ?? '';
      if (password.isEmpty) continue;
      candidates.add((e.uuid.string, password));
    }

    setState(() {
      _checkingBreaches = true;
      _breachProgress = 0;
      _breachTotal = candidates.length;
    });
    try {

      // Bounded concurrency: 6 parallel requests keeps well under the HIBP
      // rate limit (~30 req/s) while turning a multi-minute sequential scan
      // into ~30s for a few hundred entries. Individual failures are
      // tolerated and counted; only a complete failure marks the run failed.
      const concurrency = 6;
      final counts = <String, int>{};
      var checked = 0;
      var failedCount = 0;
      var cursor = 0;
      Future<void> worker() async {
        while (cursor < candidates.length) {
          if (!mounted) return;
          final index = cursor++;
          final (uuid, password) = candidates[index];
          final result = await _hibpService.checkPassword(password);
          if (result.errored) {
            failedCount++;
          } else if (result.pwned) {
            counts[uuid] = result.occurrenceCount;
          }
          checked++;
          if (mounted) setState(() => _breachProgress = checked);
        }
      }

      await Future.wait([
        for (var i = 0; i < concurrency; i++) worker(),
      ]);

      // Give up only when nothing at all could be checked (e.g. offline).
      final failed = checked == 0 && failedCount > 0;
      final partial = failedCount > 0;

      if (!mounted) return;
      setState(() {
        _checkingBreaches = false;
        _breachCheckFailed = failed;
        _pwnedCounts = counts.isEmpty ? null : counts;
      });

      // Completion feedback: summary toast, or an error hint on failure.
      final pwnedCount = counts.length;
      if (failed) {
        showToast(context, l10n.hibpCheckFailed, isError: true);
      } else if (pwnedCount > 0) {
        showToast(
          context,
          l10n.hibpDoneWithHits(pwnedCount),
          isError: true,
        );
      } else if (partial) {
        showToast(context, l10n.hibpDonePartial(failedCount), isError: true);
      } else {
        showToast(context, l10n.hibpDoneAllSafe(candidates.length));
      }
    } catch (e, st) {
      log.e('HIBP breach check failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _checkingBreaches = false;
          _breachCheckFailed = true;
        });
      }
    }
  }

  /// Merges cached breach-check results into the current report as
  /// [PasswordIssueKind.pwned] findings.
  PasswordAuditReport _reportWithBreaches(PasswordAuditReport report) {
    final counts = _pwnedCounts;
    if (counts == null || counts.isEmpty) return report;
    final entries = {for (final f in report.findings) f.entryUuid: f};
    final pwnedFindings = <PasswordAuditFinding>[];
    for (final entry in counts.entries) {
      final known = entries[entry.key];
      pwnedFindings.add(
        PasswordAuditFinding(
          entryUuid: entry.key,
          title: known?.title ?? '',
          groupPath: known?.groupPath ?? '',
          kind: PasswordIssueKind.pwned,
          pwnedCount: entry.value,
        ),
      );
    }
    final existing = report.findings
        .where((f) => f.kind != PasswordIssueKind.pwned)
        .toList();
    final findings = [...pwnedFindings, ...existing]
      ..sort((a, b) {
        final byKind = a.kind.severityRank.compareTo(b.kind.severityRank);
        if (byKind != 0) return byKind;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    final healthyExtra = report.totalEntries - counts.length;
    return PasswordAuditReport(
      totalEntries: report.totalEntries,
      healthyEntries: healthyExtra < 0 ? 0 : healthyExtra,
      findings: findings,
      scannedAt: report.scannedAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final rawReport = _report;
    final report = rawReport == null ? null : _reportWithBreaches(rawReport);
    final findings = report == null
        ? const <PasswordAuditFinding>[]
        : _visibleFindings(report).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordHealth),
        actions: [
          if (_checkingBreaches)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _BreachProgressIndicator(
                  progress: _breachProgress,
                  total: _breachTotal,
                ),
              ),
            )
          else
            IconButton(
              tooltip: l10n.hibpCheckAction,
              onPressed: _report == null ? null : _checkBreaches,
              icon: const Icon(Icons.travel_explore_rounded, size: 20),
            ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: l10n.auditRescan,
              onPressed: _rescan,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
        ],
      ),
      body: report == null
          ? EmptyState(
              icon: Icons.health_and_safety_outlined,
              message: l10n.auditOpenDatabaseFirst,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: _SummaryCard(report: report, l10n: l10n),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8),
                      sliver: SliverToBoxAdapter(
                        child: _FilterBar(
                          report: report,
                          selected: _filter,
                          l10n: l10n,
                          onSelected: (k) => setState(() => _filter = k),
                        ),
                      ),
                    ),
                    if (_breachCheckFailed)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _BreachErrorBanner(l10n: l10n),
                        ),
                      ),
                    if (report.findings.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyState(
                            icon: Icons.verified_rounded,
                            message: l10n.auditNoIssues,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList.builder(
                          itemCount: findings.length,
                          itemBuilder: (context, index) {
                            final finding = findings[index];
                            return _FindingCard(
                              finding: finding,
                              l10n: l10n,
                              colorScheme: colorScheme,
                              onTap: () => _openEntry(finding),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Iterable<PasswordAuditFinding> _visibleFindings(PasswordAuditReport report) {
    final filter = _filter;
    if (filter == null) return report.findings;
    return report.findings.where((f) => f.kind == filter);
  }

  void _openEntry(PasswordAuditFinding finding) {
    context.push(
      '/entry/detail?uuid=${Uri.encodeComponent(finding.entryUuid)}'
      '&groupPath=${Uri.encodeComponent(finding.groupPath)}',
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PasswordAuditReport report;
  final AppLocalizations l10n;

  const _SummaryCard({required this.report, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = report.healthScore;
    final scoreColor = score >= 80
        ? const Color(0xFF16A34A)
        : score >= 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFFDC2626);

    return SectionCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.auditHealthScore,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 40,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      '/100',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.auditEntryCounts(
                      report.healthyEntries,
                      report.totalEntries,
                    ),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: report.totalEntries == 0 ? 1 : score / 100,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: l10n.auditIssueEmpty,
                    count: report.countOf(PasswordIssueKind.empty),
                  ),
                  _StatChip(
                    label: l10n.auditIssueWeak,
                    count:
                        report.countOf(PasswordIssueKind.weak) +
                        report.countOf(PasswordIssueKind.fair),
                  ),
                  _StatChip(
                    label: l10n.auditIssueReused,
                    count: report.countOf(PasswordIssueKind.reused),
                  ),
                  _StatChip(
                    label: l10n.auditIssueExpired,
                    count:
                        report.countOf(PasswordIssueKind.expired) +
                        report.countOf(PasswordIssueKind.expiringSoon),
                  ),
                  _StatChip(
                    label: l10n.auditIssuePwned,
                    count: report.countOf(PasswordIssueKind.pwned),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  const _StatChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alert = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: alert
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: alert
              ? colorScheme.onErrorContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final PasswordAuditReport report;
  final PasswordIssueKind? selected;
  final AppLocalizations l10n;
  final ValueChanged<PasswordIssueKind?> onSelected;

  const _FilterBar({
    required this.report,
    required this.selected,
    required this.l10n,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labels = <PasswordIssueKind, String>{
      PasswordIssueKind.empty: l10n.auditIssueEmpty,
      PasswordIssueKind.weak: l10n.auditIssueWeak,
      PasswordIssueKind.reused: l10n.auditIssueReused,
      PasswordIssueKind.expired: l10n.auditIssueExpired,
      PasswordIssueKind.expiringSoon: l10n.auditIssueExpiringSoon,
      PasswordIssueKind.fair: l10n.auditIssueFair,
      if (report.countOf(PasswordIssueKind.pwned) > 0)
        PasswordIssueKind.pwned: l10n.auditIssuePwned,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: ButtonLabel(l10n.auditAll),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final kind in labels.keys)
              if (report.countOf(kind) > 0)
                ChoiceChip(
                  label: ButtonLabel(
                    '${labels[kind]} · ${report.countOf(kind)}',
                  ),
                  selected: selected == kind,
                  selectedColor: colorScheme.primaryContainer,
                  onSelected: (_) => onSelected(kind),
                ),
          ],
        ),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final PasswordAuditFinding finding;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _FindingCard({
    required this.finding,
    required this.l10n,
    required this.colorScheme,
    required this.onTap,
  });

  String get _kindLabel {
    switch (finding.kind) {
      case PasswordIssueKind.empty:
        return l10n.auditIssueEmpty;
      case PasswordIssueKind.weak:
        return l10n.auditIssueWeak;
      case PasswordIssueKind.fair:
        return l10n.auditIssueFair;
      case PasswordIssueKind.reused:
        return l10n.auditIssueReused;
      case PasswordIssueKind.expired:
        return l10n.auditIssueExpired;
      case PasswordIssueKind.expiringSoon:
        return l10n.auditIssueExpiringSoon;
      case PasswordIssueKind.pwned:
        return l10n.auditIssuePwned;
    }
  }

  Color get _kindColor {
    switch (finding.kind) {
      case PasswordIssueKind.empty:
      case PasswordIssueKind.expired:
        return const Color(0xFFDC2626);
      case PasswordIssueKind.pwned:
        // Breached passwords outrank every other warning.
        return const Color(0xFFDC2626);
      case PasswordIssueKind.weak:
      case PasswordIssueKind.reused:
        return const Color(0xFFF59E0B);
      case PasswordIssueKind.fair:
      case PasswordIssueKind.expiringSoon:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = finding.title.isEmpty ? l10n.entry : finding.title;
    final details = <String>[
      if (finding.kind == PasswordIssueKind.reused)
        l10n.auditSharedCount(finding.sharedCount),
      if (finding.kind == PasswordIssueKind.pwned &&
          finding.pwnedCount != null)
        l10n.hibpSeenCount(finding.pwnedCount!),
      if (finding.strength != null)
        '${l10n.auditStrength}: ${finding.strength!.getLabel(l10n)}',
      if (finding.expiry != null)
        l10n.auditExpiresOn(_fmtDate(finding.expiry!)),
    ];

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kindColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(finding.kind), color: _kindColor, size: 20),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (finding.groupPath.isNotEmpty)
                Text(
                  finding.groupPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _kindColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _kindLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kindColor,
                      ),
                    ),
                  ),
                  for (final d in details)
                    Text(
                      d,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: onTap,
        ),
      ],
    );
  }

  IconData _iconFor(PasswordIssueKind kind) {
    switch (kind) {
      case PasswordIssueKind.empty:
        return Icons.password_outlined;
      case PasswordIssueKind.weak:
      case PasswordIssueKind.fair:
        return Icons.trending_down_rounded;
      case PasswordIssueKind.reused:
        return Icons.copy_all_outlined;
      case PasswordIssueKind.expired:
      case PasswordIssueKind.expiringSoon:
        return Icons.event_busy_rounded;
      case PasswordIssueKind.pwned:
        return Icons.gpp_bad_rounded;
    }
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

class _BreachErrorBanner extends StatelessWidget {
  final AppLocalizations l10n;

  const _BreachErrorBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.hibpCheckFailed,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact linear progress shown in the app bar while the HIBP check runs,
/// with an x/y counter so the user can see it is actually moving.
class _BreachProgressIndicator extends StatelessWidget {
  final int progress;
  final int total;

  const _BreachProgressIndicator({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.hibpProgress(progress, total),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? null : progress / total,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
