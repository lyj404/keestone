// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'KeeStone';

  @override
  String get appSubtitle => 'KeePass 兼容的密码管理器';

  @override
  String get openLocalDatabase => '打开本地数据库';

  @override
  String get createNewDatabase => '创建新数据库';

  @override
  String get openCloudDatabase => '打开云端数据库';

  @override
  String get recentOpened => '最近打开';

  @override
  String get cloudPrefix => '云端';

  @override
  String get syncingCloudDatabase => '正在同步云端数据库...';

  @override
  String get downloadingFromCloud => '正在从云端下载...';

  @override
  String get uploadingToCloud => '正在同步到云端...';

  @override
  String get downloadingFromCloudShort => '正在从云端下载...';

  @override
  String get pleaseConfigureWebDAV => '请先在设置中配置 WebDAV';

  @override
  String get cloudSyncDisabled => 'WebDAV 已配置但未启用同步，请在设置中开启云端同步开关';

  @override
  String get webdavSaveFailedStorage =>
      '保存失败，可能是系统密钥环（GNOME Keyring / KWallet）未解锁或不可用';

  @override
  String get cloudNoDatabaseCreateFirst => '云端还没有数据库，请先在本地创建并保存后同步';

  @override
  String get cloudNoDatabaseSaveFirst => '云端还没有数据库，请先保存本地数据库后同步';

  @override
  String downloadFailed(Object error) {
    return '下载失败: $error';
  }

  @override
  String syncFailedWithError(Object error) {
    return '同步失败: $error';
  }

  @override
  String get cancel => '取消';

  @override
  String get goToSettings => '去设置';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确定';

  @override
  String get move => '移动';

  @override
  String get close => '关闭';

  @override
  String get unlockDatabase => '解锁数据库';

  @override
  String get cloudDatabase => '云端数据库';

  @override
  String get masterPassword => '主密码';

  @override
  String get pleaseEnterPassword => '请输入密码';

  @override
  String get decryptingFirstTimeSlow => '正在解密，首次打开可能较慢...';

  @override
  String get unlock => '解锁';

  @override
  String get passwordError => '密码错误';

  @override
  String get fileFormatIncorrect => '文件格式不正确或已损坏';

  @override
  String openFailed(Object msg) {
    return '打开失败: $msg';
  }

  @override
  String get createDatabase => '创建数据库';

  @override
  String get databaseName => '数据库名称';

  @override
  String get pleaseEnterName => '请输入名称';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordsNotMatch => '两次密码不一致';

  @override
  String get selectSaveLocation => '选择保存位置';

  @override
  String get create => '创建';

  @override
  String get saveDatabase => '保存数据库';

  @override
  String get myDatabase => '我的数据库';

  @override
  String error(Object e) {
    return '错误: $e';
  }

  @override
  String get cloudNewVersion => '云端有新版本';

  @override
  String get cloudModifiedSyncLatest => '检测到云端数据库已被其他设备修改，是否同步最新版本？';

  @override
  String get ignore => '忽略';

  @override
  String get sync => '同步';

  @override
  String get deleteEntry => '删除条目';

  @override
  String get moveToRecycleBin => '确定将此条目移至回收站？';

  @override
  String get permanentDelete => '永久删除';

  @override
  String get permanentDeleteConfirm => '此操作不可撤销，确定删除？';

  @override
  String get movedToRecycleBin => '已移至回收站';

  @override
  String get permanentlyDeleted => '已永久删除';

  @override
  String get restored => '已恢复';

  @override
  String get restoreFailed => '恢复失败：找不到原始分组';

  @override
  String get moved => '已移动';

  @override
  String get cannotDeleteNonEmptyGroup => '不能删除非空分组';

  @override
  String get deleteGroup => '删除分组';

  @override
  String deleteGroupConfirm(Object name) {
    return '确定删除分组「$name」？';
  }

  @override
  String get renameGroup => '重命名分组';

  @override
  String get groupName => '分组名称';

  @override
  String get saved => '已保存';

  @override
  String get saveFailed => '保存失败';

  @override
  String get syncConflict => '同步冲突';

  @override
  String get syncConflictMessage =>
      '云端数据库已被其他设备修改。你可以选择覆盖云端版本（以本地为准），或先下载云端版本再编辑。';

  @override
  String get syncAuditLocalOnly => '仅本地存在';

  @override
  String get syncAuditCloudOnly => '仅云端存在';

  @override
  String get syncAuditModifiedBoth => '双方都已修改';

  @override
  String get syncAuditLocalValue => '本地';

  @override
  String get syncAuditCloudValue => '云端';

  @override
  String get syncAuditModifiedTime => '修改时间';

  @override
  String get syncAuditNoDiffDetails => '没有更详细的差异信息';

  @override
  String get syncAuditAddedOnlyLocal => '仅在本地存在';

  @override
  String get syncAuditAddedOnlyCloud => '仅在云端存在';

  @override
  String get downloadCloudVersion => '下载云端版本';

  @override
  String get overwriteCloud => '覆盖云端';

  @override
  String get overwrittenToCloud => '已覆盖同步到云端';

  @override
  String get syncFailed => '同步失败';

  @override
  String get search => '搜索';

  @override
  String get back => '返回';

  @override
  String get addEntry => '添加条目';

  @override
  String get addGroup => '添加分组';

  @override
  String get syncFromCloud => '从云端同步';

  @override
  String get more => '更多';

  @override
  String get syncToCloud => '同步到云端';

  @override
  String get downloadFromCloud => '从云端下载';

  @override
  String get settings => '设置';

  @override
  String get settingsCategoryGeneral => '常规';

  @override
  String get settingsCategoryAppearance => '外观';

  @override
  String get settingsCategorySecurity => '安全';

  @override
  String get settingsCategorySync => '同步';

  @override
  String get settingsCategoryDatabase => '数据库';

  @override
  String get closeDatabase => '关闭数据库';

  @override
  String get rootDirectory => '根目录';

  @override
  String get thisGroupIsEmpty => '此分组为空';

  @override
  String get newEntry => '新建条目';

  @override
  String get title => '标题';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get url => '网址';

  @override
  String get notes => '备注';

  @override
  String get generatePassword => '生成密码';

  @override
  String get newGroup => '新建分组';

  @override
  String get rename => '重命名';

  @override
  String get syncedToCloud => '已同步到云端';

  @override
  String get syncedFromCloud => '已从云端同步';

  @override
  String get copyUsername => '复制用户名';

  @override
  String get copyPassword => '复制密码';

  @override
  String get entry => '条目';

  @override
  String get entryNotFound => '未找到该条目';

  @override
  String get entryDetail => '条目详情';

  @override
  String get edit => '编辑';

  @override
  String get restore => '恢复';

  @override
  String get permanentDeleteTooltip => '永久删除';

  @override
  String get deleteTooltip => '删除';

  @override
  String get editEntry => '编辑条目';

  @override
  String get untitled => '(未命名)';

  @override
  String get copy => '复制';

  @override
  String copiedField(Object label) {
    return '已复制$label';
  }

  @override
  String get copiedPassword => '已复制密码';

  @override
  String get copiedUsername => '已复制用户名';

  @override
  String get hide => '隐藏';

  @override
  String get show => '显示';

  @override
  String get searchEntries => '搜索条目...';

  @override
  String get enterKeywords => '输入关键词搜索';

  @override
  String get noResults => '未找到匹配结果';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get webdavProfiles => 'WebDAV 配置档案';

  @override
  String get webdavProfile => 'WebDAV 档案';

  @override
  String get profileName => '档案名称';

  @override
  String get newProfile => '新建档案';

  @override
  String get selectWebDavProfile => '选择 WebDAV 档案';

  @override
  String deleteProfileConfirm(Object name) {
    return '确定删除档案「$name」？';
  }

  @override
  String get cannotDeleteLastProfile => '至少保留一个 WebDAV 档案';

  @override
  String get autoSyncOnSave => '保存时自动同步到云端';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => 'https://example.com/dav/';

  @override
  String get serverAddressHelper => 'WebDAV 服务地址，不含文件名';

  @override
  String get pleaseEnterServerAddress => '请输入服务器地址';

  @override
  String get pleaseEnterUsername => '请输入用户名';

  @override
  String get appPasswordHelper => '部分服务（如坚果云）需要使用应用专用密码而非账号密码';

  @override
  String get remotePathOptional => '远程路径（可选）';

  @override
  String get remotePathHint => '例如 /keepass，留空则保存在根目录';

  @override
  String get filename => '文件名';

  @override
  String get testConnection => '测试连接';

  @override
  String get testing => '测试中...';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get defaultProfileName => '默认档案';

  @override
  String get profile => '档案';

  @override
  String get pleaseCreateWebDavProfile => '请先创建一个 WebDAV 档案';

  @override
  String get profileRequired => '请选择 WebDAV 档案';

  @override
  String get moveToGroup => '移动到分组';

  @override
  String get generatePasswordTitle => '生成密码';

  @override
  String get copied => '复制';

  @override
  String get regenerate => '重新生成';

  @override
  String get passwordLength => '密码长度';

  @override
  String get characterTypes => '字符类型';

  @override
  String get uppercaseAZ => '大写字母 A-Z';

  @override
  String get lowercaseaz => '小写字母 a-z';

  @override
  String get digits09 => '数字 0-9';

  @override
  String get symbols => '符号 !@#\$%^&*';

  @override
  String get hyphen => '减号 -';

  @override
  String get underscore => '下划线 _';

  @override
  String get parentheses => '括号 ()';

  @override
  String get space => '空格';

  @override
  String get customSymbols => '自定义符号';

  @override
  String get customSymbolsHint => '输入额外要包含的符号';

  @override
  String get useThisPassword => '使用此密码';

  @override
  String get excludeAmbiguous => '排除易混字符 (0 O 1 l I |)';

  @override
  String get characterMode => '字符';

  @override
  String get passphraseMode => '短语';

  @override
  String get wordCount => '单词数';

  @override
  String get separatorLabel => '分隔符';

  @override
  String get appendDigit => '追加数字';

  @override
  String get recycleBin => '回收站';

  @override
  String get noPasswordCannotReload => '无密码信息，无法重新加载';

  @override
  String get authFailedCheckCredentials => '认证失败，请检查用户名和密码';

  @override
  String serverConnectedPathNotAccessible(Object path) {
    return '服务器已连接，但路径「$path」不可访问';
  }

  @override
  String get pathNotExistTitle => '路径不存在';

  @override
  String pathNotExistMessage(Object path) {
    return '路径「$path」不存在。数据库文件将在首次同步时生成。';
  }

  @override
  String get reenterPath => '重新输入';

  @override
  String get createPath => '创建目录';

  @override
  String get creatingPath => '创建中...';

  @override
  String get pathCreated => '目录已创建';

  @override
  String pathCreateFailed(Object msg) {
    return '创建失败: $msg';
  }

  @override
  String connectionFailedMsg(Object msg) {
    return '连接失败: $msg';
  }

  @override
  String get networkFailedCheckServer => '网络连接失败，请检查服务器地址';

  @override
  String get remoteDatabaseNotExist => '远程数据库不存在';

  @override
  String get pleaseConfigureWebDAVFirst => '请先配置 WebDAV';

  @override
  String get cloudDatabaseNotExist => '云端数据库不存在';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get lightTheme => '浅色模式';

  @override
  String get darkTheme => '深色模式';

  @override
  String get colorScheme => '配色方案';

  @override
  String get themeSeedIndigo => '靛紫';

  @override
  String get themeSeedEmerald => '青绿';

  @override
  String get themeSeedSky => '天蓝';

  @override
  String get themeSeedAmber => '琥珀';

  @override
  String get themeSeedSlate => '石板灰';

  @override
  String get themeSeedRose => '品红';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get groups => '个分组';

  @override
  String get entries => '个条目';

  @override
  String get closeBehavior => '关闭窗口时';

  @override
  String get askEveryTime => '每次询问';

  @override
  String get minimizeToTray => '最小化到系统托盘';

  @override
  String get minimize => '最小化';

  @override
  String get exitApp => '直接退出';

  @override
  String get closeWindowMessage => '请选择关闭窗口的方式：';

  @override
  String get rememberChoice => '记住我的选择';

  @override
  String get showMainWindow => '显示主窗口';

  @override
  String get exit => '退出';

  @override
  String get autoLock => '自动锁定';

  @override
  String get autoLockDescription => '无操作后自动锁定数据库';

  @override
  String get autoSave => '自动保存';

  @override
  String get autoSaveDescription => '无操作后自动保存数据库';

  @override
  String get seconds => '秒';

  @override
  String get disabled => '关闭';

  @override
  String get minute => '分钟';

  @override
  String get minutes => '分钟';

  @override
  String get databaseBackup => '数据库备份';

  @override
  String get autoBackup => '自动备份';

  @override
  String get autoBackupDescription => '保存和同步前自动备份数据库';

  @override
  String get createBackupNow => '立即备份';

  @override
  String get noBackups => '暂无备份';

  @override
  String get backupCreated => '备份已创建';

  @override
  String get backupFailed => '备份失败';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restoreBackupConfirm => '确定恢复此备份？恢复前将自动备份当前数据库。';

  @override
  String get backupRestored => '备份已恢复';

  @override
  String get backupRestoreFailed => '恢复失败';

  @override
  String get backupNotFound => '备份文件不存在';

  @override
  String get deleteBackup => '删除备份';

  @override
  String get deleteBackupConfirm => '确定删除此备份？此操作不可撤销。';

  @override
  String get backupDeleted => '备份已删除';

  @override
  String get backupRetention => '备份数量';

  @override
  String backupRetentionInfo(Object count) {
    return '保留最近 $count 个备份';
  }

  @override
  String backupRetentionCount(Object count) {
    return '保留 $count 个备份';
  }

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get build => '构建';

  @override
  String get aboutDescription => '一个安全、开源的密码管理器，兼容 KeePass 格式。';

  @override
  String get sourceCode => '源代码';

  @override
  String get reportIssue => '报告问题';

  @override
  String get reportIssueDescription => '反馈 Bug 或建议';

  @override
  String get linkCopied => '链接已复制';

  @override
  String get newVersionAvailable => '有新版本可用';

  @override
  String get update => '去更新';

  @override
  String get alreadyLatest => '已是最新版本';

  @override
  String get licenses => '许可证';

  @override
  String get openSourceLicenses => '开源许可协议';

  @override
  String get changeMasterPassword => '修改主密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get pleaseEnterCurrentPassword => '请输入当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get pleaseEnterNewPassword => '请输入新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get passwordChanged => '主密码已修改';

  @override
  String get history => '历史记录';

  @override
  String get noHistory => '暂无历史记录';

  @override
  String get restoreVersion => '恢复此版本';

  @override
  String get restoreVersionConfirm => '确定将条目恢复到此版本？当前状态会先保存到历史记录。';

  @override
  String get versionRestored => '已恢复到历史版本';

  @override
  String get currentVersion => '当前版本';

  @override
  String get attachments => '附件';

  @override
  String get addAttachment => '添加附件';

  @override
  String get deleteAttachment => '删除附件';

  @override
  String get deleteAttachmentConfirm => '确定删除此附件？';

  @override
  String get attachmentDeleted => '附件已删除';

  @override
  String get attachmentAdded => '附件已添加';

  @override
  String get attachmentSaved => '附件已保存';

  @override
  String get saveAttachment => '保存附件';

  @override
  String get noAttachments => '暂无附件';

  @override
  String get customFields => '自定义字段';

  @override
  String get addCustomField => '添加字段';

  @override
  String get fieldName => '字段名称';

  @override
  String get fieldValue => '字段值';

  @override
  String get protectField => '保护字段';

  @override
  String get unprotectField => '取消保护';

  @override
  String get fieldNameEmpty => '字段名称不能为空';

  @override
  String fieldNameDuplicate(Object name) {
    return '字段名称重复: $name';
  }

  @override
  String fieldNameReserved(Object name) {
    return '字段名称 \"$name\" 是保留名称';
  }

  @override
  String deleteCustomFieldConfirm(Object name) {
    return '确定删除字段 \"$name\"？';
  }

  @override
  String get backupPasswordDifferent => '备份使用了不同的密码（可能修改过主密码），请输入备份时的密码';

  @override
  String get backupPasswordHint => '请输入备份时的主密码';

  @override
  String get importCsv => '导入 CSV';

  @override
  String get exportCsv => '导出 CSV';

  @override
  String get exportKdbx => '导出 KDBX';

  @override
  String get importCsvTitle => '导入 CSV 文件';

  @override
  String importSuccess(Object count) {
    return '成功导入 $count 个条目';
  }

  @override
  String importFailed(Object error) {
    return '导入失败: $error';
  }

  @override
  String get exportSuccess => '导出成功';

  @override
  String get exportFailed => '导出失败';

  @override
  String get noEntriesToExport => '没有可导出的条目';

  @override
  String get noEntriesInCsv => 'CSV 文件中未找到有效条目';

  @override
  String get expiration => '过期时间';

  @override
  String get noExpiration => '永不过期';

  @override
  String get expired => '已过期';

  @override
  String expiresOn(Object date) {
    return '过期于 $date';
  }

  @override
  String get keyFile => '密钥文件';

  @override
  String get selectKeyFile => '选择密钥文件（可选）';

  @override
  String get keyFileSelected => '已选择密钥文件';

  @override
  String get changeKeyFile => '更换';

  @override
  String get removeKeyFile => '移除密钥文件';

  @override
  String get setupTotp => '设置 TOTP';

  @override
  String get totpUriLabel => '粘贴 otpauth:// 链接';

  @override
  String get totpParseUri => '解析链接';

  @override
  String get totpManualConfig => '手动配置';

  @override
  String get totpPasteUri => '粘贴链接';

  @override
  String get totpSecretLabel => '密钥 (Base32)';

  @override
  String get totpPeriodLabel => '周期（秒）';

  @override
  String get totpDigitsLabel => '位数';

  @override
  String get totpAlgorithmLabel => '算法';

  @override
  String get totpAlgoSha1 => 'SHA-1';

  @override
  String get totpAlgoSha256 => 'SHA-256';

  @override
  String get totpAlgoSha512 => 'SHA-512';

  @override
  String get totpInvalidUri => '无效的 otpauth:// 链接或 Base32 密钥';

  @override
  String get copiedUrl => '已复制网址';

  @override
  String get copiedTotp => '已复制 TOTP';

  @override
  String get copyUrl => '复制网址';

  @override
  String get copyTotp => '复制 TOTP';

  @override
  String get deleteTotp => '删除 TOTP';

  @override
  String get deleteTotpConfirm => '确定移除此条目的 TOTP 配置？';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String get scanQrHint => '将摄像头对准 TOTP 二维码';

  @override
  String get toggleFlashlight => '切换闪光灯';

  @override
  String get switchCamera => '切换摄像头';

  @override
  String get expirationReminder => '过期提醒';

  @override
  String get expirationReminderDescription => '密码即将过期时通知提醒';

  @override
  String get daysBeforeExpiry => '天前提醒';

  @override
  String get tags => '标签';

  @override
  String get addTag => '添加标签';

  @override
  String get filterByTag => '按标签筛选';

  @override
  String get allTags => '全部标签';

  @override
  String get noTags => '无标签';

  @override
  String get shortcutSearch => '搜索';

  @override
  String get shortcutSave => '保存';

  @override
  String get biometricUnlock => '指纹解锁';

  @override
  String get biometricUnlockDescription => '使用指纹或面部识别解锁数据库';

  @override
  String get authenticateToEnableBiometric => '验证身份以启用指纹解锁';

  @override
  String get biometricEnabled => '指纹解锁已启用';

  @override
  String get biometricAuthFailed => '指纹验证失败';

  @override
  String get biometricDisabled => '指纹解锁已禁用';

  @override
  String get unlockMethod => '解锁方式';

  @override
  String get unlockByPassword => '密码认证';

  @override
  String get unlockByBiometric => '指纹认证';

  @override
  String get unlockWithBiometric => '使用指纹解锁';

  @override
  String get authenticateToUnlock => '验证身份以解锁数据库';

  @override
  String get noStoredPassword => '没有存储的密码，请先使用密码解锁';

  @override
  String get syncRetry => '重试';

  @override
  String syncRetrying(Object attempt, Object maxAttempts) {
    return '重试中... ($attempt/$maxAttempts)';
  }

  @override
  String get syncErrorNetwork => '网络连接失败，请检查网络和服务器设置。';

  @override
  String get syncErrorAuth => '认证失败，请在设置中检查用户名和密码。';

  @override
  String get syncErrorNotFound => '远程数据库不存在，请在设置中检查远程路径。';

  @override
  String get syncErrorTimeout => '连接超时，服务器可能暂时不可用。';

  @override
  String get syncErrorServer => '服务器错误，请稍后再试。';

  @override
  String get databaseCorrupted => '数据库文件已损坏或格式不正确。';

  @override
  String get restoreFromBackup => '从备份恢复';

  @override
  String get restoreFromBackupDescription => '找到可用的备份，是否从最新备份恢复？';

  @override
  String get noBackupAvailable => '没有可用的备份进行恢复，请从外部备份手动恢复。';

  @override
  String get sortBy => '排序方式';

  @override
  String get sortTitleAsc => '标题 A→Z';

  @override
  String get sortTitleDesc => '标题 Z→A';

  @override
  String get sortCreatedNewest => '最新创建';

  @override
  String get sortCreatedOldest => '最早创建';

  @override
  String get sortModifiedNewest => '最近修改';

  @override
  String get sortModifiedOldest => '最早修改';

  @override
  String get sortExpiredFirst => '过期优先';

  @override
  String get batchSelect => '批量选择';

  @override
  String get batchDelete => '批量删除';

  @override
  String get batchMove => '批量移动';

  @override
  String get batchTag => '批量标签';

  @override
  String selectedCount(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get cancelSelection => '取消选择';

  @override
  String get selectAll => '全选';

  @override
  String batchDeleteConfirm(Object count) {
    return '确定删除选中的 $count 个条目吗？';
  }

  @override
  String get batchTagTitle => '编辑标签';

  @override
  String get batchTagHint => '输入标签名称';

  @override
  String get groupsTab => '分组';

  @override
  String get entriesTab => '条目';

  @override
  String get totpTab => 'TOTP';

  @override
  String get searchTab => '搜索';

  @override
  String get toolsTab => '工具';

  @override
  String get noTotpEntries => '暂无配置 TOTP 的条目';

  @override
  String get unsavedChanges => '有未保存的更改';

  @override
  String get allSaved => '所有更改已保存';

  @override
  String get strengthWeak => '弱';

  @override
  String get strengthFair => '一般';

  @override
  String get strengthGood => '良好';

  @override
  String get strengthStrong => '强';

  @override
  String get csvPlaintextWarningTitle => '导出明文密码';

  @override
  String get csvPlaintextWarningBody =>
      'CSV 文件不会加密，并包含所有条目的明文密码。任何能访问该文件的人都可以读取这些密码。建议优先导出 KDBX。是否仍要继续？';

  @override
  String get webDavInvalidUrl => '服务器地址必须是有效的 HTTP 或 HTTPS URL';

  @override
  String get webDavInsecureHttpTitle => '不安全的 WebDAV 连接';

  @override
  String get webDavInsecureHttpBody =>
      '此服务器使用未加密的 HTTP，登录凭据和数据库可能被网络中的其他人截获。建议使用 HTTPS。是否仍要继续？';

  @override
  String get privacyProtection => '隐私保护';

  @override
  String get blockScreenshots => '禁止截屏';

  @override
  String get blockScreenshotsDescription => '在 Android 上阻止截屏和最近任务预览。';

  @override
  String get hideInBackground => '后台隐藏内容';

  @override
  String get hideInBackgroundDescription => '应用失去焦点或进入后台时遮挡密码库内容。';

  @override
  String get backupIntegrityFailed => '备份完整性校验失败';

  @override
  String get pendingUploadFailed => '待同步的云端更改上传失败，已保留本地加密副本。';

  @override
  String get pendingUploadConflict => '云端数据已发生变化，待同步的本地更改未覆盖远端。';

  @override
  String get discardChangesTitle => '有未保存的更改';

  @override
  String get discardChangesBody => '当前条目的修改尚未保存，确定放弃并离开吗？';

  @override
  String get discardAndLeave => '放弃';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get entryNoLongerExists => '该条目在当前打开的数据库中已不存在，修改未保存。';

  @override
  String get closeUnsavedTitle => '数据库有未保存更改';

  @override
  String get closeUnsavedBody => '部分更改未能写入磁盘。确定放弃这些更改并关闭吗？';

  @override
  String get discardAndClose => '放弃并关闭';
}
