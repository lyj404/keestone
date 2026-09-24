import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../data/password_audit_service.dart';

class PasswordAuditScreen extends ConsumerStatefulWidget {
  const PasswordAuditScreen({super.key});

  @override
  ConsumerState<PasswordAuditScreen> createState() =>
      _PasswordAuditScreenState();
}

class _PasswordAuditScreenState extends ConsumerState<PasswordAuditScreen> {
  static const _service = PasswordAuditService();
  PasswordIssueKind? _filter;
  PasswordAuditReport? _report;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rescan());
  }

  void _rescan() {
    final db = ref.read(databaseProvider).value;
    final service = ref.read(databaseServiceProvider);
    if (db == null || !service.isOpen) {
      setState(() => _report = null);
      return;
    }
    final entries = service.allEntries
        .where((e) => !service.isInRecycleBin(e))
        .toList();
    final report = _service.analyze(
      entries,
      groupPathOf: (e) {
        final parent = e.parent;
        return parent == null ? '' : service.getGroupPath(parent);
      },
    );
    setState(() => _report = report);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordHealth),
        actions: [
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _SummaryCard(report: report, l10n: l10n),
                    const SizedBox(height: 8),
                    _FilterBar(
                      report: report,
                      selected: _filter,
                      l10n: l10n,
                      onSelected: (k) => setState(() => _filter = k),
                    ),
                    const SizedBox(height: 8),
                    if (report.findings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: EmptyState(
                          icon: Icons.verified_rounded,
                          message: l10n.auditNoIssues,
                        ),
                      )
                    else ...[
                      for (final finding in _visibleFindings(report))
                        _FindingCard(
                          finding: finding,
                          l10n: l10n,
                          colorScheme: colorScheme,
                          onTap: () => _openEntry(finding),
                        ),
                    ],
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                    count: report.countOf(PasswordIssueKind.weak) +
                        report.countOf(PasswordIssueKind.fair),
                  ),
                  _StatChip(
                    label: l10n.auditIssueReused,
                    count: report.countOf(PasswordIssueKind.reused),
                  ),
                  _StatChip(
                    label: l10n.auditIssueExpired,
                    count: report.countOf(PasswordIssueKind.expired) +
                        report.countOf(PasswordIssueKind.expiringSoon),
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
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(l10n.auditAll),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final kind in labels.keys)
            if (report.countOf(kind) > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${labels[kind]} · ${report.countOf(kind)}'),
                  selected: selected == kind,
                  selectedColor: colorScheme.primaryContainer,
                  onSelected: (_) => onSelected(kind),
                ),
              ),
        ],
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
    }
  }

  Color get _kindColor {
    switch (finding.kind) {
      case PasswordIssueKind.empty:
      case PasswordIssueKind.expired:
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
      if (finding.strength != null)
        '${l10n.auditStrength}: ${finding.strength!.getLabel(l10n)}',
      if (finding.expiry != null) l10n.auditExpiresOn(_fmtDate(finding.expiry!)),
    ];

    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kindColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(finding.kind),
              color: _kindColor,
              size: 20,
            ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
    }
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
