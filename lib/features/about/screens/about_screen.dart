import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../core/services/external_url_service.dart';
import '../../../core/widgets/button_label.dart';
import '../../../l10n/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _appName = 'KeeStone';
  static const String _githubUrl = 'https://github.com/lyj404/keestone';
  static const String _issuesUrl = 'https://github.com/lyj404/keestone/issues';
  static const String _licenseUrl =
      'https://github.com/lyj404/keestone/blob/main/LICENSE';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/lyj404/keestone/releases/latest';

  String _version = '';
  String _buildNumber = '';
  String? _latestVersion;
  bool _isChecking = false;
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkForUpdates();
  }

  Future<void> _loadVersion() async {
    final yaml = await rootBundle.loadString('pubspec.yaml');
    final match = RegExp(r'version:\s*(\d+\.\d+\.\d+)\+(\d+)').firstMatch(yaml);
    if (match != null && mounted) {
      setState(() {
        _version = match.group(1)!;
        _buildNumber = match.group(2)!;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
    });

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(_releasesApiUrl));
      final response = await request.close();

      if (response.statusCode == 200) {
        final json = await response.transform(utf8.decoder).join();
        final data = Map<String, dynamic>.from(
          (jsonDecode(json) as Map<String, dynamic>),
        );
        final tagName = data['tag_name'] as String?;
        if (tagName != null && mounted) {
          final version = tagName.startsWith('v')
              ? tagName.substring(1)
              : tagName;
          setState(() {
            _latestVersion = version;
            _hasChecked = true;
          });
        }
      }
    } catch (e) {
      // 忽略网络错误
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  bool _isNewVersionAvailable() {
    if (_latestVersion == null) return false;
    return _compareVersions(_latestVersion!, _version) > 0;
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final parts2 = v2.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context)!;
    final opened = await ExternalUrlService.openUrl(Uri.tryParse(url) ?? Uri());
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.linkCopied}: $url'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasUpdate = _isNewVersionAvailable();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  _appName,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Version
                Text(
                  '${l10n.version}: $_version',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                // Build Number
                Text(
                  '${l10n.build}: $_buildNumber',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                // Update Status
                if (_isChecking)
                  const CircularProgressIndicator()
                else if (hasUpdate) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${l10n.newVersionAvailable}: $_latestVersion',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        _openUrl(context, '$_githubUrl/releases/latest'),
                    icon: const Icon(Icons.system_update_rounded, size: 18),
                    label: ButtonLabel(l10n.update),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ] else if (_hasChecked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.alreadyLatest,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                // Description
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          l10n.appSubtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.aboutDescription,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Links
                _InfoTile(
                  icon: Icons.code_rounded,
                  title: l10n.sourceCode,
                  subtitle: 'GitHub',
                  onTap: () => _openUrl(context, _githubUrl),
                ),
                _InfoTile(
                  icon: Icons.bug_report_rounded,
                  title: l10n.reportIssue,
                  subtitle: l10n.reportIssueDescription,
                  onTap: () => _openUrl(context, _issuesUrl),
                ),
                _InfoTile(
                  icon: Icons.favorite_rounded,
                  title: l10n.licenses,
                  subtitle: 'Apache License 2.0',
                  onTap: () => _openUrl(context, _licenseUrl),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
