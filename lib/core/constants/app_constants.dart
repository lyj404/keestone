class AppConstants {
  static const clipboardClearTimeout = Duration(seconds: 30);
  static const searchDebounceDelay = Duration(milliseconds: 300);
  static const maxRecentFiles = 10;
  static const appName = 'KeeStone';
  static const kdbxExtension = '.kdbx';

  /// Standard KDBX field keys.
  static const standardKeys = {'Title', 'UserName', 'Password', 'URL', 'Notes'};

  /// KeePass / KeeStone TOTP bookkeeping fields. Managed by TotpService and
  /// shown in the TOTP UI — never as user-defined custom fields.
  static const totpFieldKeys = {
    'TimeOtp-Secret',
    'TimeOtp-Secret-Base32',
    'TimeOtp-Secret-Hex',
    'TimeOtp-Secret-Base64',
    'TimeOtp-Period',
    'TimeOtp-Length',
    'TimeOtp-Size',
    'TimeOtp-Algorithm',
    'TOTP',
  };

  /// True for fields the app manages itself (identity + TOTP internals).
  /// These must not appear in custom-field editors, search, or CSV extras.
  static bool isInternalField(String key) =>
      standardKeys.contains(key) ||
      totpFieldKeys.contains(key) ||
      key.startsWith('TimeOtp-');
}
