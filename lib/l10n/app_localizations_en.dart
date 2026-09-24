// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KeeStone';

  @override
  String get appSubtitle => 'KeePass-compatible password manager';

  @override
  String get openLocalDatabase => 'Open Local Database';

  @override
  String get createNewDatabase => 'Create New Database';

  @override
  String get openCloudDatabase => 'Open Cloud Database';

  @override
  String get recentOpened => 'Recent';

  @override
  String get cloudPrefix => 'Cloud';

  @override
  String get syncingCloudDatabase => 'Syncing cloud database...';

  @override
  String get downloadingFromCloud => 'Downloading from cloud...';

  @override
  String get uploadingToCloud => 'Uploading to cloud...';

  @override
  String get downloadingFromCloudShort => 'Downloading from cloud...';

  @override
  String get pleaseConfigureWebDAV =>
      'Please configure WebDAV in settings first';

  @override
  String get cloudSyncDisabled =>
      'WebDAV is configured but sync is disabled. Please enable cloud sync in settings.';

  @override
  String get webdavSaveFailedStorage =>
      'Save failed — system keyring (GNOME Keyring / KWallet) may be locked or unavailable';

  @override
  String get cloudNoDatabaseCreateFirst =>
      'No cloud database found. Please create and save a local database first, then sync.';

  @override
  String get cloudNoDatabaseSaveFirst =>
      'No cloud database found. Please save a local database first, then sync.';

  @override
  String downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String syncFailedWithError(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'OK';

  @override
  String get move => 'Move';

  @override
  String get close => 'Close';

  @override
  String get unlockDatabase => 'Unlock Database';

  @override
  String get cloudDatabase => 'Cloud Database';

  @override
  String get masterPassword => 'Master Password';

  @override
  String get pleaseEnterPassword => 'Please enter password';

  @override
  String get decryptingFirstTimeSlow => 'Decrypting, first open may be slow...';

  @override
  String get unlock => 'Unlock';

  @override
  String get passwordError => 'Incorrect password';

  @override
  String get fileFormatIncorrect => 'File format is incorrect or corrupted';

  @override
  String openFailed(Object msg) {
    return 'Open failed: $msg';
  }

  @override
  String get createDatabase => 'Create Database';

  @override
  String get databaseName => 'Database Name';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get passwordsNotMatch => 'Passwords do not match';

  @override
  String get selectSaveLocation => 'Select Save Location';

  @override
  String get create => 'Create';

  @override
  String get saveDatabase => 'Save Database';

  @override
  String get myDatabase => 'My Database';

  @override
  String error(Object e) {
    return 'Error: $e';
  }

  @override
  String get cloudNewVersion => 'New version on cloud';

  @override
  String get cloudModifiedSyncLatest =>
      'Cloud database has been modified by another device. Sync the latest version?';

  @override
  String get ignore => 'Ignore';

  @override
  String get sync => 'Sync';

  @override
  String get deleteEntry => 'Delete Entry';

  @override
  String get moveToRecycleBin => 'Move this entry to the recycle bin?';

  @override
  String get permanentDelete => 'Permanent Delete';

  @override
  String get permanentDeleteConfirm =>
      'This action cannot be undone. Confirm delete?';

  @override
  String get movedToRecycleBin => 'Moved to recycle bin';

  @override
  String get permanentlyDeleted => 'Permanently deleted';

  @override
  String get restored => 'Restored';

  @override
  String get restoreFailed => 'Restore failed: original group not found';

  @override
  String get moved => 'Moved';

  @override
  String get cannotDeleteNonEmptyGroup => 'Cannot delete a non-empty group';

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String deleteGroupConfirm(Object name) {
    return 'Delete group \'$name\'?';
  }

  @override
  String get renameGroup => 'Rename Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get syncConflict => 'Sync Conflict';

  @override
  String get syncConflictMessage =>
      'Cloud database has been modified by another device. You can overwrite the cloud version (use local), or download the cloud version first.';

  @override
  String get syncAuditLocalOnly => 'Local Only';

  @override
  String get syncAuditCloudOnly => 'Cloud Only';

  @override
  String get syncAuditModifiedBoth => 'Modified Both';

  @override
  String get syncAuditLocalValue => 'Local';

  @override
  String get syncAuditCloudValue => 'Cloud';

  @override
  String get syncAuditModifiedTime => 'Modified Time';

  @override
  String get syncAuditNoDiffDetails => 'No detailed differences available';

  @override
  String get syncAuditAddedOnlyLocal => 'Only in local';

  @override
  String get syncAuditAddedOnlyCloud => 'Only in cloud';

  @override
  String get downloadCloudVersion => 'Download Cloud Version';

  @override
  String get overwriteCloud => 'Overwrite Cloud';

  @override
  String get overwrittenToCloud => 'Overwritten to cloud';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get search => 'Search';

  @override
  String get back => 'Back';

  @override
  String get addEntry => 'Add Entry';

  @override
  String get addGroup => 'Add Group';

  @override
  String get syncFromCloud => 'Sync from Cloud';

  @override
  String get more => 'More';

  @override
  String get syncToCloud => 'Sync to Cloud';

  @override
  String get downloadFromCloud => 'Download from Cloud';

  @override
  String get settings => 'Settings';

  @override
  String get settingsCategoryGeneral => 'General';

  @override
  String get settingsCategoryAppearance => 'Appearance';

  @override
  String get settingsCategorySecurity => 'Security';

  @override
  String get settingsCategorySync => 'Sync';

  @override
  String get settingsCategoryDatabase => 'Database';

  @override
  String get closeDatabase => 'Close Database';

  @override
  String get rootDirectory => 'Root';

  @override
  String get thisGroupIsEmpty => 'This group is empty';

  @override
  String get newEntry => 'New Entry';

  @override
  String get title => 'Title';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get url => 'URL';

  @override
  String get notes => 'Notes';

  @override
  String get generatePassword => 'Generate Password';

  @override
  String get newGroup => 'New Group';

  @override
  String get rename => 'Rename';

  @override
  String get syncedToCloud => 'Synced to cloud';

  @override
  String get syncedFromCloud => 'Synced from cloud';

  @override
  String get copyUsername => 'Copy Username';

  @override
  String get copyPassword => 'Copy Password';

  @override
  String get entry => 'Entry';

  @override
  String get entryNotFound => 'Entry not found';

  @override
  String get entryDetail => 'Entry Details';

  @override
  String get edit => 'Edit';

  @override
  String get restore => 'Restore';

  @override
  String get permanentDeleteTooltip => 'Permanent Delete';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get editEntry => 'Edit Entry';

  @override
  String get untitled => '(Untitled)';

  @override
  String get copy => 'Copy';

  @override
  String copiedField(Object label) {
    return 'Copied $label';
  }

  @override
  String get copiedPassword => 'Copied password';

  @override
  String get copiedUsername => 'Copied username';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get searchEntries => 'Search entries...';

  @override
  String get enterKeywords => 'Enter keywords to search';

  @override
  String get noResults => 'No matching results';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get webdavProfiles => 'WebDAV Profiles';

  @override
  String get webdavProfile => 'WebDAV Profile';

  @override
  String get profileName => 'Profile Name';

  @override
  String get newProfile => 'New Profile';

  @override
  String get selectWebDavProfile => 'Select WebDAV Profile';

  @override
  String deleteProfileConfirm(Object name) {
    return 'Delete profile \'$name\'?';
  }

  @override
  String get cannotDeleteLastProfile =>
      'At least one WebDAV profile must remain';

  @override
  String get autoSyncOnSave => 'Auto-sync to cloud on save';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get serverAddressHint => 'https://example.com/dav/';

  @override
  String get serverAddressHelper => 'WebDAV server URL, without filename';

  @override
  String get pleaseEnterServerAddress => 'Please enter server address';

  @override
  String get pleaseEnterUsername => 'Please enter username';

  @override
  String get appPasswordHelper =>
      'Some services (e.g. Jianguoyun) require an app-specific password instead of your account password';

  @override
  String get remotePathOptional => 'Remote Path (optional)';

  @override
  String get remotePathHint => 'e.g. /keepass, leave empty for root directory';

  @override
  String get filename => 'Filename';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get testing => 'Testing...';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get defaultProfileName => 'Default';

  @override
  String get profile => 'Profile';

  @override
  String get pleaseCreateWebDavProfile =>
      'Please create a WebDAV profile first';

  @override
  String get profileRequired => 'Please select a WebDAV profile';

  @override
  String get moveToGroup => 'Move to Group';

  @override
  String get generatePasswordTitle => 'Generate Password';

  @override
  String get copied => 'Copy';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get passwordLength => 'Password Length';

  @override
  String get characterTypes => 'Character Types';

  @override
  String get uppercaseAZ => 'Uppercase A-Z';

  @override
  String get lowercaseaz => 'Lowercase a-z';

  @override
  String get digits09 => 'Digits 0-9';

  @override
  String get symbols => 'Symbols !@#\$%^&*';

  @override
  String get hyphen => 'Hyphen -';

  @override
  String get underscore => 'Underscore _';

  @override
  String get parentheses => 'Parentheses ()';

  @override
  String get space => 'Space';

  @override
  String get customSymbols => 'Custom Symbols';

  @override
  String get customSymbolsHint => 'Enter additional symbols to include';

  @override
  String get useThisPassword => 'Use This Password';

  @override
  String get excludeAmbiguous => 'Exclude ambiguous (0 O 1 l I |)';

  @override
  String get characterMode => 'Characters';

  @override
  String get passphraseMode => 'Passphrase';

  @override
  String get wordCount => 'Word Count';

  @override
  String get separatorLabel => 'Separator';

  @override
  String get appendDigit => 'Append digit';

  @override
  String get recycleBin => 'Recycle Bin';

  @override
  String get noPasswordCannotReload => 'No password available, cannot reload';

  @override
  String get authFailedCheckCredentials =>
      'Authentication failed, please check username and password';

  @override
  String serverConnectedPathNotAccessible(Object path) {
    return 'Server connected, but path \'$path\' is not accessible';
  }

  @override
  String get pathNotExistTitle => 'Path Not Found';

  @override
  String pathNotExistMessage(Object path) {
    return 'Path \'$path\' does not exist. The database file will be created on first sync.';
  }

  @override
  String get reenterPath => 'Re-enter';

  @override
  String get createPath => 'Create';

  @override
  String get creatingPath => 'Creating...';

  @override
  String get pathCreated => 'Directory created';

  @override
  String pathCreateFailed(Object msg) {
    return 'Create failed: $msg';
  }

  @override
  String connectionFailedMsg(Object msg) {
    return 'Connection failed: $msg';
  }

  @override
  String get networkFailedCheckServer =>
      'Network connection failed, please check server address';

  @override
  String get remoteDatabaseNotExist => 'Remote database does not exist';

  @override
  String get pleaseConfigureWebDAVFirst => 'Please configure WebDAV first';

  @override
  String get cloudDatabaseNotExist => 'Cloud database does not exist';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get theme => 'Theme';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get colorScheme => 'Color Scheme';

  @override
  String get themeSeedIndigo => 'Indigo';

  @override
  String get themeSeedEmerald => 'Emerald';

  @override
  String get themeSeedSky => 'Sky';

  @override
  String get themeSeedAmber => 'Amber';

  @override
  String get themeSeedSlate => 'Slate';

  @override
  String get themeSeedRose => 'Rose';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get groups => 'groups';

  @override
  String get entries => 'entries';

  @override
  String get closeBehavior => 'On Window Close';

  @override
  String get askEveryTime => 'Ask Every Time';

  @override
  String get minimizeToTray => 'Minimize to System Tray';

  @override
  String get minimize => 'Minimize';

  @override
  String get exitApp => 'Exit App';

  @override
  String get closeWindowMessage => 'What would you like to do?';

  @override
  String get rememberChoice => 'Remember my choice';

  @override
  String get showMainWindow => 'Show Main Window';

  @override
  String get exit => 'Exit';

  @override
  String get autoLock => 'Auto Lock';

  @override
  String get autoLockDescription => 'Lock database after inactivity';

  @override
  String get autoSave => 'Auto Save';

  @override
  String get autoSaveDescription => 'Save database after inactivity';

  @override
  String get seconds => 'sec';

  @override
  String get disabled => 'Disabled';

  @override
  String get minute => 'min';

  @override
  String get minutes => 'min';

  @override
  String get databaseBackup => 'Database Backup';

  @override
  String get autoBackup => 'Auto Backup';

  @override
  String get autoBackupDescription => 'Backup before every save and cloud sync';

  @override
  String get createBackupNow => 'Create Backup Now';

  @override
  String get noBackups => 'No backups yet';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get restoreBackupConfirm =>
      'Restore this backup? Current database will be backed up before restoring.';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupRestoreFailed => 'Restore failed';

  @override
  String get backupNotFound => 'Backup file not found';

  @override
  String get deleteBackup => 'Delete Backup';

  @override
  String get deleteBackupConfirm =>
      'Delete this backup? This cannot be undone.';

  @override
  String get backupDeleted => 'Backup deleted';

  @override
  String get backupRetention => 'Backup Retention';

  @override
  String backupRetentionInfo(Object count) {
    return 'Keeping latest $count backups';
  }

  @override
  String backupRetentionCount(Object count) {
    return 'Keep $count backups';
  }

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get build => 'Build';

  @override
  String get aboutDescription =>
      'A secure, open-source password manager compatible with KeePass format.';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get reportIssue => 'Report Issue';

  @override
  String get reportIssueDescription => 'Report bugs or suggestions';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String get update => 'Update';

  @override
  String get alreadyLatest => 'Already latest version';

  @override
  String get licenses => 'Licenses';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get changeMasterPassword => 'Change Master Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get pleaseEnterCurrentPassword => 'Please enter current password';

  @override
  String get newPassword => 'New Password';

  @override
  String get pleaseEnterNewPassword => 'Please enter new password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get passwordChanged => 'Master password changed';

  @override
  String get history => 'History';

  @override
  String get noHistory => 'No history yet';

  @override
  String get restoreVersion => 'Restore this version';

  @override
  String get restoreVersionConfirm =>
      'Restore entry to this version? The current state will be saved to history first.';

  @override
  String get versionRestored => 'Restored to historical version';

  @override
  String get currentVersion => 'Current version';

  @override
  String get attachments => 'Attachments';

  @override
  String get addAttachment => 'Add Attachment';

  @override
  String get deleteAttachment => 'Delete Attachment';

  @override
  String get deleteAttachmentConfirm => 'Delete this attachment?';

  @override
  String get attachmentDeleted => 'Attachment deleted';

  @override
  String get attachmentAdded => 'Attachment added';

  @override
  String get attachmentSaved => 'Attachment saved';

  @override
  String get saveAttachment => 'Save Attachment';

  @override
  String get noAttachments => 'No attachments';

  @override
  String get customFields => 'Custom Fields';

  @override
  String get addCustomField => 'Add Field';

  @override
  String get fieldName => 'Field Name';

  @override
  String get fieldValue => 'Field Value';

  @override
  String get protectField => 'Protect Field';

  @override
  String get unprotectField => 'Unprotect Field';

  @override
  String get fieldNameEmpty => 'Field name cannot be empty';

  @override
  String fieldNameDuplicate(Object name) {
    return 'Duplicate field name: $name';
  }

  @override
  String fieldNameReserved(Object name) {
    return 'Field name \"$name\" is reserved';
  }

  @override
  String deleteCustomFieldConfirm(Object name) {
    return 'Delete field \"$name\"?';
  }

  @override
  String get backupPasswordDifferent =>
      'Backup uses a different password (master password may have been changed). Please enter the backup password.';

  @override
  String get backupPasswordHint =>
      'Enter the master password from when the backup was created';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get exportKdbx => 'Export KDBX';

  @override
  String get importCsvTitle => 'Import CSV File';

  @override
  String importSuccess(Object count) {
    return 'Successfully imported $count entries';
  }

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get noEntriesToExport => 'No entries to export';

  @override
  String get noEntriesInCsv => 'No valid entries found in CSV file';

  @override
  String get expiration => 'Expiration';

  @override
  String get noExpiration => 'No Expiration';

  @override
  String get expired => 'Expired';

  @override
  String expiresOn(Object date) {
    return 'Expires on $date';
  }

  @override
  String get keyFile => 'Key File';

  @override
  String get selectKeyFile => 'Select Key File (optional)';

  @override
  String get keyFileSelected => 'Key file selected';

  @override
  String get changeKeyFile => 'Change';

  @override
  String get removeKeyFile => 'Remove Key File';

  @override
  String get setupTotp => 'Setup TOTP';

  @override
  String get totpUriLabel => 'Paste otpauth:// URI';

  @override
  String get totpParseUri => 'Parse URI';

  @override
  String get totpManualConfig => 'Configure manually';

  @override
  String get totpPasteUri => 'Paste URI instead';

  @override
  String get totpSecretLabel => 'Secret Key (Base32)';

  @override
  String get totpPeriodLabel => 'Period (seconds)';

  @override
  String get totpDigitsLabel => 'Digits';

  @override
  String get totpAlgorithmLabel => 'Algorithm';

  @override
  String get totpAlgoSha1 => 'SHA-1';

  @override
  String get totpAlgoSha256 => 'SHA-256';

  @override
  String get totpAlgoSha512 => 'SHA-512';

  @override
  String get totpInvalidUri => 'Invalid otpauth:// URI or Base32 secret';

  @override
  String get copiedUrl => 'Copied URL';

  @override
  String get copiedTotp => 'Copied TOTP';

  @override
  String get copyUrl => 'Copy URL';

  @override
  String get copyTotp => 'Copy TOTP';

  @override
  String get deleteTotp => 'Delete TOTP';

  @override
  String get deleteTotpConfirm => 'Remove TOTP configuration from this entry?';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get scanQrHint => 'Point camera at a TOTP QR code';

  @override
  String get toggleFlashlight => 'Toggle Flashlight';

  @override
  String get switchCamera => 'Switch Camera';

  @override
  String get expirationReminder => 'Expiration Reminder';

  @override
  String get expirationReminderDescription =>
      'Notify when passwords are about to expire';

  @override
  String get daysBeforeExpiry => 'days before expiry';

  @override
  String get tags => 'Tags';

  @override
  String get addTag => 'Add Tag';

  @override
  String get filterByTag => 'Filter by Tag';

  @override
  String get allTags => 'All Tags';

  @override
  String get noTags => 'No Tags';

  @override
  String get shortcutSearch => 'Search';

  @override
  String get shortcutSave => 'Save';

  @override
  String get biometricUnlock => 'Biometric Unlock';

  @override
  String get biometricUnlockDescription =>
      'Unlock with fingerprint or face recognition';

  @override
  String get authenticateToEnableBiometric =>
      'Authenticate to enable biometric unlock';

  @override
  String get biometricEnabled => 'Biometric unlock enabled';

  @override
  String get biometricAuthFailed => 'Biometric authentication failed';

  @override
  String get biometricDisabled => 'Biometric unlock disabled';

  @override
  String get unlockMethod => 'Unlock Method';

  @override
  String get unlockByPassword => 'Password';

  @override
  String get unlockByBiometric => 'Biometric';

  @override
  String get unlockWithBiometric => 'Unlock with Biometric';

  @override
  String get authenticateToUnlock => 'Authenticate to unlock database';

  @override
  String get noStoredPassword =>
      'No stored password. Please unlock with password first.';

  @override
  String get syncRetry => 'Retry';

  @override
  String syncRetrying(Object attempt, Object maxAttempts) {
    return 'Retrying... ($attempt/$maxAttempts)';
  }

  @override
  String get syncErrorNetwork =>
      'Network connection failed. Please check your internet and server settings.';

  @override
  String get syncErrorAuth =>
      'Authentication failed. Please check your username and password in settings.';

  @override
  String get syncErrorNotFound =>
      'Remote database not found. Please check the remote path in settings.';

  @override
  String get syncErrorTimeout =>
      'Connection timed out. The server may be temporarily unavailable.';

  @override
  String get syncErrorServer => 'Server error. Please try again later.';

  @override
  String get databaseCorrupted => 'Database file is corrupted or damaged.';

  @override
  String get restoreFromBackup => 'Restore from Backup';

  @override
  String get restoreFromBackupDescription =>
      'A backup was found. Would you like to restore from the most recent backup?';

  @override
  String get noBackupAvailable =>
      'No backup available for recovery. Please restore from an external backup.';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortTitleAsc => 'Title A→Z';

  @override
  String get sortTitleDesc => 'Title Z→A';

  @override
  String get sortCreatedNewest => 'Newest created';

  @override
  String get sortCreatedOldest => 'Oldest created';

  @override
  String get sortModifiedNewest => 'Recently modified';

  @override
  String get sortModifiedOldest => 'Least recently modified';

  @override
  String get sortExpiredFirst => 'Expired first';

  @override
  String get batchSelect => 'Select';

  @override
  String get batchDelete => 'Delete selected';

  @override
  String get batchMove => 'Move selected';

  @override
  String get batchTag => 'Edit tags';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get cancelSelection => 'Cancel';

  @override
  String get selectAll => 'Select all';

  @override
  String batchDeleteConfirm(Object count) {
    return 'Delete $count selected entries?';
  }

  @override
  String get batchTagTitle => 'Edit tags';

  @override
  String get batchTagHint => 'Enter tag name';

  @override
  String get groupsTab => 'Groups';

  @override
  String get entriesTab => 'Entries';

  @override
  String get totpTab => 'TOTP';

  @override
  String get searchTab => 'Search';

  @override
  String get toolsTab => 'Tools';

  @override
  String get noTotpEntries => 'No entries with TOTP configured';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get allSaved => 'All changes saved';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String get strengthStrong => 'Strong';

  @override
  String get csvPlaintextWarningTitle => 'Export plaintext passwords';

  @override
  String get csvPlaintextWarningBody =>
      'CSV files are not encrypted and contain every password in plaintext. Anyone with access to the file can read them. Prefer exporting KDBX. Continue anyway?';

  @override
  String get webDavInvalidUrl =>
      'The server address must be a valid HTTP or HTTPS URL';

  @override
  String get webDavInsecureHttpTitle => 'Insecure WebDAV connection';

  @override
  String get webDavInsecureHttpBody =>
      'This server uses unencrypted HTTP. Your credentials and database may be intercepted by others on the network. HTTPS is recommended. Continue anyway?';

  @override
  String get privacyProtection => 'Privacy protection';

  @override
  String get blockScreenshots => 'Block screenshots';

  @override
  String get blockScreenshotsDescription =>
      'Prevent screenshots and recent-app previews on Android.';

  @override
  String get hideInBackground => 'Hide content in background';

  @override
  String get hideInBackgroundDescription =>
      'Cover the vault while the app is inactive or in the background.';

  @override
  String get backupIntegrityFailed => 'Backup integrity verification failed';

  @override
  String get pendingUploadFailed =>
      'Pending cloud changes could not be uploaded. The local encrypted copy was kept.';

  @override
  String get pendingUploadConflict =>
      'Cloud data changed before pending local changes could be uploaded. The remote file was not overwritten.';

  @override
  String get discardChangesTitle => 'Unsaved changes';

  @override
  String get discardChangesBody =>
      'This entry has unsaved changes. Discard them and leave?';

  @override
  String get discardAndLeave => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get entryNoLongerExists =>
      'This entry no longer exists in the open database. Your changes were not saved.';

  @override
  String get closeUnsavedTitle => 'Unsaved database changes';

  @override
  String get closeUnsavedBody =>
      'Some changes could not be written to disk. Discard them and close anyway?';

  @override
  String get discardAndClose => 'Discard and close';
}
