import 'package:csv/csv.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../totp/data/totp_service.dart';

/// A parsed entry from CSV, ready to be imported into KDBX.
class CsvEntry {
  String title;
  String username;
  String password;
  String url;
  String notes;
  String? group;
  Map<String, String> customFields;

  CsvEntry({
    this.title = '',
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.group,
    Map<String, String>? customFields,
  }) : customFields = customFields ?? {};
}

/// Column mapping for a recognized CSV format.
class _ColumnMapping {
  int title = -1;
  int username = -1;
  int password = -1;
  int url = -1;
  int notes = -1;
  int group = -1;
  int totp = -1;
  List<int> customIndices = [];
  List<String> customHeaders = [];
}

class CsvService {
  /// Import entries from a CSV file content.
  /// Returns a list of [CsvEntry] objects.
  List<CsvEntry> importFromCsv(String csvContent) {
    // Strip UTF-8 BOM if present
    if (csvContent.startsWith('﻿')) {
      csvContent = csvContent.substring(1);
    }

    // Normalize line endings
    csvContent = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Detect delimiter
    final delimiter = _detectDelimiter(csvContent);
    log.i(
      'CSV import: detected delimiter: ${delimiter == '\t'
          ? 'TAB'
          : delimiter == '  '
          ? 'SPACES'
          : delimiter}',
    );

    final rows = _parseCsvLines(csvContent, delimiter);

    log.i('CSV import: ${rows.length} rows parsed (including header)');
    if (rows.length < 2) return [];

    final headers = rows.first.map((h) => h.trim()).toList();
    log.i('CSV import: headers = $headers');
    final mapping = _mapColumns(headers);
    final entries = <CsvEntry>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      String cell(int idx) =>
          idx >= 0 && idx < row.length ? row[idx].trim() : '';

      final entry = CsvEntry(
        title: cell(mapping.title),
        username: cell(mapping.username),
        password: cell(mapping.password),
        url: cell(mapping.url),
        notes: cell(mapping.notes),
        group: mapping.group >= 0 ? cell(mapping.group) : null,
      );

      // TOTP -> custom field
      final totp = cell(mapping.totp);
      if (totp.isNotEmpty) {
        entry.customFields['TOTP'] = totp;
      }

      // Other custom fields
      for (int j = 0; j < mapping.customIndices.length; j++) {
        final value = cell(mapping.customIndices[j]);
        if (value.isNotEmpty && j < mapping.customHeaders.length) {
          entry.customFields[mapping.customHeaders[j]] = value;
        }
      }

      entries.add(entry);
    }

    log.i('CSV import: ${entries.length} entries parsed');
    return entries;
  }

  /// Parse CSV content into rows, handling quoted fields with embedded delimiters.
  static List<List<String>> _parseCsvLines(String content, String delimiter) {
    if (delimiter == '  ') {
      return _parseSpaceDelimitedLines(content);
    }

    final lines = content.split('\n');
    final rows = <List<String>>[];
    List<String>? currentRow;
    String? pendingField;
    bool inQuote = false;

    for (final line in lines) {
      if (line.trim().isEmpty && !inQuote) continue;

      if (!inQuote) {
        currentRow = [];
        pendingField = '';
      }

      final sb = StringBuffer();
      // Join continuation lines with '\n' even when the quoted content so far
      // is empty (a quote opened at the very end of the previous line);
      // otherwise the first line break of a multi-line field is lost.
      if (inQuote && pendingField != null) {
        sb.write(pendingField);
        sb.write('\n');
      }

      int i = 0;
      while (i < line.length) {
        final ch = line[i];
        if (inQuote) {
          if (ch == '"') {
            if (i + 1 < line.length && line[i + 1] == '"') {
              sb.write('"');
              i += 2;
            } else {
              inQuote = false;
              i++;
            }
          } else {
            sb.write(ch);
            i++;
          }
        } else {
          if (ch == '"') {
            inQuote = true;
            i++;
          } else if (ch == delimiter) {
            currentRow!.add(sb.toString());
            sb.clear();
            i++;
          } else {
            sb.write(ch);
            i++;
          }
        }
      }

      if (inQuote) {
        pendingField = sb.toString();
      } else {
        final row = currentRow!;
        row.add(sb.toString());
        rows.add(row);
        pendingField = null;
      }
    }

    // The file ended inside a quoted field: flush what was accumulated so the
    // final row is not silently dropped.
    if (inQuote && currentRow != null) {
      currentRow.add(pendingField ?? '');
      rows.add(currentRow);
    }

    log.i('CSV import: manual parser returned ${rows.length} rows');
    if (rows.isNotEmpty) {
      log.i(
        'CSV import: first row has ${rows.first.length} columns: ${rows.first}',
      );
    }
    return rows;
  }

  static List<List<String>> _parseSpaceDelimitedLines(String content) {
    final pattern = RegExp(r' {2,}');
    final rows = <List<String>>[];
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      rows.add(line.split(pattern).map((cell) => cell.trim()).toList());
    }
    log.i('CSV import: space-delimited parser returned ${rows.length} rows');
    if (rows.isNotEmpty) {
      log.i(
        'CSV import: first row has ${rows.first.length} columns: ${rows.first}',
      );
    }
    return rows;
  }

  /// Create KDBX entries from parsed CSV entries.
  /// Returns the number of entries created.
  int createEntries(
    List<CsvEntry> csvEntries,
    KdbxDatabase db,
    KdbxGroup targetGroup,
  ) {
    int count = 0;
    for (final csv in csvEntries) {
      // Resolve target group
      KdbxGroup group = targetGroup;
      if (csv.group != null && csv.group!.isNotEmpty) {
        group = _findOrCreateGroup(db, targetGroup, csv.group!);
      }

      final entry = db.createEntry(parent: group);
      entry.times = KdbxTimes.fromTime();
      entry.fields['Title'] = KdbxTextField.fromText(text: csv.title);
      entry.fields['UserName'] = KdbxTextField.fromText(text: csv.username);
      entry.fields['Password'] = KdbxTextField.fromText(
        text: csv.password,
        protected: true,
      );
      entry.fields['URL'] = KdbxTextField.fromText(text: csv.url);
      entry.fields['Notes'] = KdbxTextField.fromText(text: csv.notes);

      // Custom fields
      final totpService = TotpService();
      for (final e in csv.customFields.entries) {
        if (!AppConstants.isInternalField(e.key) && e.value.isNotEmpty) {
          if (e.key == 'TOTP') {
            final config = totpService.parseUri(e.value);
            if (config != null) {
              totpService.saveToEntry(entry, config);
            } else {
              entry.fields[e.key] = KdbxTextField.fromText(text: e.value);
            }
          } else {
            entry.fields[e.key] = KdbxTextField.fromText(text: e.value);
          }
        }
      }

      count++;
    }
    log.i('CSV import: $count entries created');
    return count;
  }

  /// Export all entries to CSV string (KeePass-compatible format).
  String exportToCsv(List<KdbxEntry> entries) {
    final totpService = TotpService();
    final customHeaders = <String>{};

    for (final entry in entries) {
      for (final key in entry.fields.keys) {
        if (!AppConstants.isInternalField(key)) {
          customHeaders.add(key);
        }
      }
    }

    final sortedCustomHeaders = customHeaders.toList()..sort();
    final rows = <List<String>>[
      [
        'Group',
        'Title',
        'Username',
        'Password',
        'URL',
        'Notes',
        'TOTP',
        'Tags',
        'Attachments',
        'AttachmentCount',
        'HasHistory',
        'HistoryCount',
        'Expires',
        'ExpiryTime',
        'Created',
        'Modified',
        'LastAccessed',
        ...sortedCustomHeaders,
      ],
    ];

    for (final entry in entries) {
      final title = entry.fields['Title']?.text ?? '';
      final username = entry.fields['UserName']?.text ?? '';
      final password = entry.fields['Password']?.text ?? '';
      final url = entry.fields['URL']?.text ?? '';
      final notes = entry.fields['Notes']?.text ?? '';

      // Get group path
      String groupPath = '';
      KdbxGroup? current = entry.parent;
      final pathParts = <String>[];
      while (current != null && current.parent != null) {
        pathParts.add(current.name);
        current = current.parent;
      }
      if (pathParts.isNotEmpty) {
        groupPath = pathParts.reversed.join('/');
      }

      final tags = (entry.tags ?? []).join('|');
      final attachments = entry.binaries.keys.join('|');
      final attachmentCount = entry.binaries.length.toString();
      final historyCount = entry.history.length;
      final hasHistory = historyCount > 0 ? 'true' : 'false';
      final expires = entry.times.expires ? 'true' : 'false';
      final expiryTime = entry.times.expiry.time?.toIso8601String() ?? '';
      final created = entry.times.creation.time?.toIso8601String() ?? '';
      final modified = entry.times.modification.time?.toIso8601String() ?? '';
      final lastAccessed = entry.times.access.time?.toIso8601String() ?? '';

      // TOTP
      String totp = '';
      final totpConfig = totpService.loadFromEntry(entry);
      if (totpConfig != null) {
        final algo = TotpService.toOtpAuthAlgorithm(totpConfig.algorithm);
        totp =
            'otpauth://totp/${Uri.encodeComponent(title)}'
            '?secret=${totpConfig.secret}'
            '&digits=${totpConfig.digits}'
            '&period=${totpConfig.period}'
            '&algorithm=$algo';
      } else {
        totp = entry.fields['TOTP']?.text ?? '';
      }

      rows.add([
        groupPath,
        title,
        username,
        password,
        url,
        notes,
        totp,
        tags,
        attachments,
        attachmentCount,
        hasHistory,
        '$historyCount',
        expires,
        expiryTime,
        created,
        modified,
        lastAccessed,
        ...sortedCustomHeaders.map(
          (header) => entry.fields[header]?.text ?? '',
        ),
      ]);
    }

    return Csv().encode(rows);
  }

  /// Detect CSV delimiter by sampling the first few lines.
  String _detectDelimiter(String content) {
    final lines = content.split('\n').take(5).toList();
    int commas = 0;
    int semicolons = 0;
    int tabs = 0;
    for (final line in lines) {
      // Skip quoted sections for accurate counting
      bool inQuote = false;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == '"') {
          inQuote = !inQuote;
        } else if (!inQuote) {
          if (line[i] == ',') commas++;
          if (line[i] == ';') semicolons++;
          if (line[i] == '\t') tabs++;
        }
      }
    }
    if (tabs > commas && tabs > semicolons) return '\t';
    if (semicolons > commas) return ';';
    if (commas > 0) return ',';
    // Fallback: check if multiple spaces work as delimiter
    if (_couldBeSpaceDelimited(lines)) return '  ';
    return ',';
  }

  /// Heuristic: if splitting on 2+ spaces yields consistent column counts
  /// across the first few lines, treat as space-delimited.
  bool _couldBeSpaceDelimited(List<String> lines) {
    if (lines.length < 2) return false;
    final pattern = RegExp(r' {2,}');
    final counts = <int>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(pattern).where((p) => p.isNotEmpty).toList();
      counts.add(parts.length);
    }
    if (counts.isEmpty) return false;
    final first = counts.first;
    return first >= 2 && counts.every((c) => c == first);
  }

  /// Map CSV headers to column indices.
  _ColumnMapping _mapColumns(List<String> headers) {
    final m = _ColumnMapping();
    final lowerHeaders = headers.map((h) => h.toLowerCase().trim()).toList();

    for (int i = 0; i < lowerHeaders.length; i++) {
      final h = lowerHeaders[i];
      // Title/Name
      if (h == 'name' || h == 'title' || h == 'entry name') {
        m.title = i;
      }
      // Username
      else if (h == 'username' ||
          h == 'login_username' ||
          h == 'user' ||
          h == 'login') {
        m.username = i;
      }
      // Password
      else if (h == 'password' ||
          h == 'login_password' ||
          h == 'pass' ||
          h == 'passwd') {
        m.password = i;
      }
      // URL
      else if (h == 'url' ||
          h == 'login_uri' ||
          h == 'website' ||
          h == 'web site' ||
          h == 'uri') {
        m.url = i;
      }
      // Notes
      else if (h == 'notes' ||
          h == 'extra' ||
          h == 'note' ||
          h == 'comments' ||
          h == 'comment') {
        m.notes = i;
      }
      // Group/Folder
      else if (h == 'group' ||
          h == 'grouping' ||
          h == 'folder' ||
          h == 'folders' ||
          h == 'path') {
        m.group = i;
      }
      // TOTP
      else if (h == 'totp' ||
          h == 'otpauth' ||
          h == 'login_totp' ||
          h == 'otp') {
        m.totp = i;
      }
      // Unknown -> custom field
      else {
        m.customIndices.add(i);
        m.customHeaders.add(headers[i]);
      }
    }

    // If title not found, try first column
    if (m.title < 0 && headers.isNotEmpty) {
      m.title = 0;
    }

    return m;
  }

  /// Find or create a group by path (e.g., "Email/Work").
  KdbxGroup _findOrCreateGroup(KdbxDatabase db, KdbxGroup root, String path) {
    // Normalize separators
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((s) => s.isNotEmpty).toList();

    KdbxGroup current = root;
    for (final segment in segments) {
      final existing = current.groups
          .where((g) => g.name == segment)
          .firstOrNull;
      if (existing != null) {
        current = existing;
      } else {
        current = db.createGroup(parent: current, name: segment);
      }
    }
    return current;
  }
}
