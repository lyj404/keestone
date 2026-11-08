import 'dart:convert';
import 'dart:typed_data';

/// One credential record inside the iOS autofill snapshot.
///
/// `domains` and `packageIds` are pre-parsed from the entry's URL field so the
/// Swift Credential Provider Extension can match by `serviceIdentifier` without
/// embedding a URL parser. Only the minimum fields needed for autofill are
/// included — no TOTP, attachments, or custom protected fields.
class AutofillSnapshotEntry {
  final String uuid;
  final String title;
  final String username;
  final String password;
  final List<String> domains;
  final List<String> packageIds;

  const AutofillSnapshotEntry({
    required this.uuid,
    required this.title,
    required this.username,
    required this.password,
    required this.domains,
    required this.packageIds,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'title': title,
    'username': username,
    'password': password,
    'domains': domains,
    'packageIds': packageIds,
  };

  factory AutofillSnapshotEntry.fromJson(Map<String, dynamic> json) =>
      AutofillSnapshotEntry(
        uuid: json['uuid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        domains: (json['domains'] as List?)?.cast<String>() ?? const [],
        packageIds:
            (json['packageIds'] as List?)?.cast<String>() ?? const [],
      );
}

/// Versioned, JSON-serializable snapshot consumed by the iOS extension.
class AutofillSnapshot {
  static const int currentVersion = 1;

  final int version;
  final int createdAt; // epoch milliseconds
  final List<AutofillSnapshotEntry> entries;

  const AutofillSnapshot({
    this.version = currentVersion,
    required this.createdAt,
    required this.entries,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory AutofillSnapshot.fromJson(Map<String, dynamic> json) =>
      AutofillSnapshot(
        version: json['version'] as int? ?? currentVersion,
        createdAt: json['createdAt'] as int? ?? 0,
        entries: (json['entries'] as List?)
                ?.map(
                  (e) => AutofillSnapshotEntry.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );

  String toUtf8JsonString() => jsonEncode(toJson());
}

/// On-wire layout of an encrypted snapshot file:
///   bytes 0..3   : magic  "KVAF"
///   byte  4      : format version (1)
///   bytes 5..    : AES-GCM combined = nonce(12) || ciphertext || tag(16)
class AutofillSnapshotFile {
  static const _magic = [0x4B, 0x56, 0x41, 0x46]; // "KVAF"
  static const _formatVersion = 1;

  /// Wraps the AES-GCM combined ciphertext ([nonce||cipherText||mac]) with the
  /// file header. Returns the bytes to write to the App Group container.
  static Uint8List wrap(Uint8List combined) {
    final out = Uint8List(5 + combined.length);
    out[0] = _magic[0];
    out[1] = _magic[1];
    out[2] = _magic[2];
    out[3] = _magic[3];
    out[4] = _formatVersion;
    out.setRange(5, out.length, combined);
    return out;
  }

  /// Splits a wrapped file back into the AES-GCM combined bytes, or null if the
  /// header is not a recognized KeeStone snapshot.
  static Uint8List? unwrap(Uint8List bytes) {
    if (bytes.length < 5 + 12 + 16) return null;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _magic[i]) return null;
    }
    if (bytes[4] != _formatVersion) return null;
    return Uint8List.sublistView(bytes, 5);
  }
}
