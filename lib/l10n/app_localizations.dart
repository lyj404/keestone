import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'KeeStone'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'KeePass 兼容的密码管理器'**
  String get appSubtitle;

  /// No description provided for @openLocalDatabase.
  ///
  /// In zh, this message translates to:
  /// **'打开本地数据库'**
  String get openLocalDatabase;

  /// No description provided for @createNewDatabase.
  ///
  /// In zh, this message translates to:
  /// **'创建新数据库'**
  String get createNewDatabase;

  /// No description provided for @openCloudDatabase.
  ///
  /// In zh, this message translates to:
  /// **'打开云端数据库'**
  String get openCloudDatabase;

  /// No description provided for @recentOpened.
  ///
  /// In zh, this message translates to:
  /// **'最近打开'**
  String get recentOpened;

  /// No description provided for @cloudPrefix.
  ///
  /// In zh, this message translates to:
  /// **'云端'**
  String get cloudPrefix;

  /// No description provided for @syncingCloudDatabase.
  ///
  /// In zh, this message translates to:
  /// **'正在同步云端数据库...'**
  String get syncingCloudDatabase;

  /// No description provided for @downloadingFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'正在从云端下载...'**
  String get downloadingFromCloud;

  /// No description provided for @uploadingToCloud.
  ///
  /// In zh, this message translates to:
  /// **'正在同步到云端...'**
  String get uploadingToCloud;

  /// No description provided for @downloadingFromCloudShort.
  ///
  /// In zh, this message translates to:
  /// **'正在从云端下载...'**
  String get downloadingFromCloudShort;

  /// No description provided for @pleaseConfigureWebDAV.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中配置 WebDAV'**
  String get pleaseConfigureWebDAV;

  /// No description provided for @cloudSyncDisabled.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 已配置但未启用同步，请在设置中开启云端同步开关'**
  String get cloudSyncDisabled;

  /// No description provided for @webdavSaveFailedStorage.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，可能是系统密钥环（GNOME Keyring / KWallet）未解锁或不可用'**
  String get webdavSaveFailedStorage;

  /// No description provided for @cloudNoDatabaseCreateFirst.
  ///
  /// In zh, this message translates to:
  /// **'云端还没有数据库，请先在本地创建并保存后同步'**
  String get cloudNoDatabaseCreateFirst;

  /// No description provided for @cloudNoDatabaseSaveFirst.
  ///
  /// In zh, this message translates to:
  /// **'云端还没有数据库，请先保存本地数据库后同步'**
  String get cloudNoDatabaseSaveFirst;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String downloadFailed(Object error);

  /// No description provided for @syncFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'同步失败: {error}'**
  String syncFailedWithError(Object error);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @goToSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get goToSettings;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @move.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get move;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @unlockDatabase.
  ///
  /// In zh, this message translates to:
  /// **'解锁数据库'**
  String get unlockDatabase;

  /// No description provided for @cloudDatabase.
  ///
  /// In zh, this message translates to:
  /// **'云端数据库'**
  String get cloudDatabase;

  /// No description provided for @masterPassword.
  ///
  /// In zh, this message translates to:
  /// **'主密码'**
  String get masterPassword;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get pleaseEnterPassword;

  /// No description provided for @decryptingFirstTimeSlow.
  ///
  /// In zh, this message translates to:
  /// **'正在解密，首次打开可能较慢...'**
  String get decryptingFirstTimeSlow;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @passwordError.
  ///
  /// In zh, this message translates to:
  /// **'密码错误'**
  String get passwordError;

  /// No description provided for @fileFormatIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'文件格式不正确或已损坏'**
  String get fileFormatIncorrect;

  /// No description provided for @openFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开失败: {msg}'**
  String openFailed(Object msg);

  /// No description provided for @createDatabase.
  ///
  /// In zh, this message translates to:
  /// **'创建数据库'**
  String get createDatabase;

  /// No description provided for @databaseName.
  ///
  /// In zh, this message translates to:
  /// **'数据库名称'**
  String get databaseName;

  /// No description provided for @pleaseEnterName.
  ///
  /// In zh, this message translates to:
  /// **'请输入名称'**
  String get pleaseEnterName;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次密码不一致'**
  String get passwordsNotMatch;

  /// No description provided for @selectSaveLocation.
  ///
  /// In zh, this message translates to:
  /// **'选择保存位置'**
  String get selectSaveLocation;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @saveDatabase.
  ///
  /// In zh, this message translates to:
  /// **'保存数据库'**
  String get saveDatabase;

  /// No description provided for @myDatabase.
  ///
  /// In zh, this message translates to:
  /// **'我的数据库'**
  String get myDatabase;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误: {e}'**
  String error(Object e);

  /// No description provided for @cloudNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'云端有新版本'**
  String get cloudNewVersion;

  /// No description provided for @cloudModifiedSyncLatest.
  ///
  /// In zh, this message translates to:
  /// **'检测到云端数据库已被其他设备修改，是否同步最新版本？'**
  String get cloudModifiedSyncLatest;

  /// No description provided for @ignore.
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get ignore;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @deleteEntry.
  ///
  /// In zh, this message translates to:
  /// **'删除条目'**
  String get deleteEntry;

  /// No description provided for @moveToRecycleBin.
  ///
  /// In zh, this message translates to:
  /// **'确定将此条目移至回收站？'**
  String get moveToRecycleBin;

  /// No description provided for @permanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get permanentDelete;

  /// No description provided for @permanentDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可撤销，确定删除？'**
  String get permanentDeleteConfirm;

  /// No description provided for @movedToRecycleBin.
  ///
  /// In zh, this message translates to:
  /// **'已移至回收站'**
  String get movedToRecycleBin;

  /// No description provided for @permanentlyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除'**
  String get permanentlyDeleted;

  /// No description provided for @restored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复'**
  String get restored;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：找不到原始分组'**
  String get restoreFailed;

  /// No description provided for @moved.
  ///
  /// In zh, this message translates to:
  /// **'已移动'**
  String get moved;

  /// No description provided for @cannotDeleteNonEmptyGroup.
  ///
  /// In zh, this message translates to:
  /// **'不能删除非空分组'**
  String get cannotDeleteNonEmptyGroup;

  /// No description provided for @deleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除分组'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除分组「{name}」？'**
  String deleteGroupConfirm(Object name);

  /// No description provided for @renameGroup.
  ///
  /// In zh, this message translates to:
  /// **'重命名分组'**
  String get renameGroup;

  /// No description provided for @groupName.
  ///
  /// In zh, this message translates to:
  /// **'分组名称'**
  String get groupName;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get saveFailed;

  /// No description provided for @syncConflict.
  ///
  /// In zh, this message translates to:
  /// **'同步冲突'**
  String get syncConflict;

  /// No description provided for @syncConflictMessage.
  ///
  /// In zh, this message translates to:
  /// **'云端数据库已被其他设备修改。你可以选择覆盖云端版本（以本地为准），或先下载云端版本再编辑。'**
  String get syncConflictMessage;

  /// No description provided for @syncAuditLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本地存在'**
  String get syncAuditLocalOnly;

  /// No description provided for @syncAuditCloudOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅云端存在'**
  String get syncAuditCloudOnly;

  /// No description provided for @syncAuditModifiedBoth.
  ///
  /// In zh, this message translates to:
  /// **'双方都已修改'**
  String get syncAuditModifiedBoth;

  /// No description provided for @syncAuditLocalValue.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get syncAuditLocalValue;

  /// No description provided for @syncAuditCloudValue.
  ///
  /// In zh, this message translates to:
  /// **'云端'**
  String get syncAuditCloudValue;

  /// No description provided for @syncAuditModifiedTime.
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get syncAuditModifiedTime;

  /// No description provided for @syncAuditNoDiffDetails.
  ///
  /// In zh, this message translates to:
  /// **'没有更详细的差异信息'**
  String get syncAuditNoDiffDetails;

  /// No description provided for @syncAuditAddedOnlyLocal.
  ///
  /// In zh, this message translates to:
  /// **'仅在本地存在'**
  String get syncAuditAddedOnlyLocal;

  /// No description provided for @syncAuditAddedOnlyCloud.
  ///
  /// In zh, this message translates to:
  /// **'仅在云端存在'**
  String get syncAuditAddedOnlyCloud;

  /// No description provided for @downloadCloudVersion.
  ///
  /// In zh, this message translates to:
  /// **'下载云端版本'**
  String get downloadCloudVersion;

  /// No description provided for @overwriteCloud.
  ///
  /// In zh, this message translates to:
  /// **'覆盖云端'**
  String get overwriteCloud;

  /// No description provided for @overwrittenToCloud.
  ///
  /// In zh, this message translates to:
  /// **'已覆盖同步到云端'**
  String get overwrittenToCloud;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @addEntry.
  ///
  /// In zh, this message translates to:
  /// **'添加条目'**
  String get addEntry;

  /// No description provided for @addGroup.
  ///
  /// In zh, this message translates to:
  /// **'添加分组'**
  String get addGroup;

  /// No description provided for @syncFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'从云端同步'**
  String get syncFromCloud;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @syncToCloud.
  ///
  /// In zh, this message translates to:
  /// **'同步到云端'**
  String get syncToCloud;

  /// No description provided for @downloadFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'从云端下载'**
  String get downloadFromCloud;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsCategoryGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get settingsCategoryGeneral;

  /// No description provided for @settingsCategoryAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsCategoryAppearance;

  /// No description provided for @settingsCategorySecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsCategorySecurity;

  /// No description provided for @settingsCategorySync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get settingsCategorySync;

  /// No description provided for @settingsCategoryDatabase.
  ///
  /// In zh, this message translates to:
  /// **'数据库'**
  String get settingsCategoryDatabase;

  /// No description provided for @closeDatabase.
  ///
  /// In zh, this message translates to:
  /// **'关闭数据库'**
  String get closeDatabase;

  /// No description provided for @rootDirectory.
  ///
  /// In zh, this message translates to:
  /// **'根目录'**
  String get rootDirectory;

  /// No description provided for @thisGroupIsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'此分组为空'**
  String get thisGroupIsEmpty;

  /// No description provided for @newEntry.
  ///
  /// In zh, this message translates to:
  /// **'新建条目'**
  String get newEntry;

  /// No description provided for @title.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get title;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @url.
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get url;

  /// No description provided for @notes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get notes;

  /// No description provided for @generatePassword.
  ///
  /// In zh, this message translates to:
  /// **'生成密码'**
  String get generatePassword;

  /// No description provided for @newGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建分组'**
  String get newGroup;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @syncedToCloud.
  ///
  /// In zh, this message translates to:
  /// **'已同步到云端'**
  String get syncedToCloud;

  /// No description provided for @syncedFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'已从云端同步'**
  String get syncedFromCloud;

  /// No description provided for @copyUsername.
  ///
  /// In zh, this message translates to:
  /// **'复制用户名'**
  String get copyUsername;

  /// No description provided for @copyPassword.
  ///
  /// In zh, this message translates to:
  /// **'复制密码'**
  String get copyPassword;

  /// No description provided for @entry.
  ///
  /// In zh, this message translates to:
  /// **'条目'**
  String get entry;

  /// No description provided for @entryNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到该条目'**
  String get entryNotFound;

  /// No description provided for @entryDetail.
  ///
  /// In zh, this message translates to:
  /// **'条目详情'**
  String get entryDetail;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @permanentDeleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get permanentDeleteTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteTooltip;

  /// No description provided for @editEntry.
  ///
  /// In zh, this message translates to:
  /// **'编辑条目'**
  String get editEntry;

  /// No description provided for @untitled.
  ///
  /// In zh, this message translates to:
  /// **'(未命名)'**
  String get untitled;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copiedField.
  ///
  /// In zh, this message translates to:
  /// **'已复制{label}'**
  String copiedField(Object label);

  /// No description provided for @copiedPassword.
  ///
  /// In zh, this message translates to:
  /// **'已复制密码'**
  String get copiedPassword;

  /// No description provided for @copiedUsername.
  ///
  /// In zh, this message translates to:
  /// **'已复制用户名'**
  String get copiedUsername;

  /// No description provided for @hide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get hide;

  /// No description provided for @show.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get show;

  /// No description provided for @searchEntries.
  ///
  /// In zh, this message translates to:
  /// **'搜索条目...'**
  String get searchEntries;

  /// No description provided for @enterKeywords.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索'**
  String get enterKeywords;

  /// No description provided for @noResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配结果'**
  String get noResults;

  /// No description provided for @webdavSync.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get webdavSync;

  /// No description provided for @webdavProfiles.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 配置档案'**
  String get webdavProfiles;

  /// No description provided for @webdavProfile.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 档案'**
  String get webdavProfile;

  /// No description provided for @profileName.
  ///
  /// In zh, this message translates to:
  /// **'档案名称'**
  String get profileName;

  /// No description provided for @newProfile.
  ///
  /// In zh, this message translates to:
  /// **'新建档案'**
  String get newProfile;

  /// No description provided for @selectWebDavProfile.
  ///
  /// In zh, this message translates to:
  /// **'选择 WebDAV 档案'**
  String get selectWebDavProfile;

  /// No description provided for @deleteProfileConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除档案「{name}」？'**
  String deleteProfileConfirm(Object name);

  /// No description provided for @cannotDeleteLastProfile.
  ///
  /// In zh, this message translates to:
  /// **'至少保留一个 WebDAV 档案'**
  String get cannotDeleteLastProfile;

  /// No description provided for @autoSyncOnSave.
  ///
  /// In zh, this message translates to:
  /// **'保存时自动同步到云端'**
  String get autoSyncOnSave;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/dav/'**
  String get serverAddressHint;

  /// No description provided for @serverAddressHelper.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 服务地址，不含文件名'**
  String get serverAddressHelper;

  /// No description provided for @pleaseEnterServerAddress.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get pleaseEnterServerAddress;

  /// No description provided for @pleaseEnterUsername.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get pleaseEnterUsername;

  /// No description provided for @appPasswordHelper.
  ///
  /// In zh, this message translates to:
  /// **'部分服务（如坚果云）需要使用应用专用密码而非账号密码'**
  String get appPasswordHelper;

  /// No description provided for @remotePathOptional.
  ///
  /// In zh, this message translates to:
  /// **'远程路径（可选）'**
  String get remotePathOptional;

  /// No description provided for @remotePathHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 /keepass，留空则保存在根目录'**
  String get remotePathHint;

  /// No description provided for @filename.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get filename;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get testing;

  /// No description provided for @connectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionFailed;

  /// No description provided for @defaultProfileName.
  ///
  /// In zh, this message translates to:
  /// **'默认档案'**
  String get defaultProfileName;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'档案'**
  String get profile;

  /// No description provided for @pleaseCreateWebDavProfile.
  ///
  /// In zh, this message translates to:
  /// **'请先创建一个 WebDAV 档案'**
  String get pleaseCreateWebDavProfile;

  /// No description provided for @profileRequired.
  ///
  /// In zh, this message translates to:
  /// **'请选择 WebDAV 档案'**
  String get profileRequired;

  /// No description provided for @moveToGroup.
  ///
  /// In zh, this message translates to:
  /// **'移动到分组'**
  String get moveToGroup;

  /// No description provided for @generatePasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成密码'**
  String get generatePasswordTitle;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copied;

  /// No description provided for @regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// No description provided for @passwordLength.
  ///
  /// In zh, this message translates to:
  /// **'密码长度'**
  String get passwordLength;

  /// No description provided for @characterTypes.
  ///
  /// In zh, this message translates to:
  /// **'字符类型'**
  String get characterTypes;

  /// No description provided for @uppercaseAZ.
  ///
  /// In zh, this message translates to:
  /// **'大写字母 A-Z'**
  String get uppercaseAZ;

  /// No description provided for @lowercaseaz.
  ///
  /// In zh, this message translates to:
  /// **'小写字母 a-z'**
  String get lowercaseaz;

  /// No description provided for @digits09.
  ///
  /// In zh, this message translates to:
  /// **'数字 0-9'**
  String get digits09;

  /// No description provided for @symbols.
  ///
  /// In zh, this message translates to:
  /// **'符号 !@#\$%^&*'**
  String get symbols;

  /// No description provided for @hyphen.
  ///
  /// In zh, this message translates to:
  /// **'减号 -'**
  String get hyphen;

  /// No description provided for @underscore.
  ///
  /// In zh, this message translates to:
  /// **'下划线 _'**
  String get underscore;

  /// No description provided for @parentheses.
  ///
  /// In zh, this message translates to:
  /// **'括号 ()'**
  String get parentheses;

  /// No description provided for @space.
  ///
  /// In zh, this message translates to:
  /// **'空格'**
  String get space;

  /// No description provided for @customSymbols.
  ///
  /// In zh, this message translates to:
  /// **'自定义符号'**
  String get customSymbols;

  /// No description provided for @customSymbolsHint.
  ///
  /// In zh, this message translates to:
  /// **'输入额外要包含的符号'**
  String get customSymbolsHint;

  /// No description provided for @useThisPassword.
  ///
  /// In zh, this message translates to:
  /// **'使用此密码'**
  String get useThisPassword;

  /// No description provided for @excludeAmbiguous.
  ///
  /// In zh, this message translates to:
  /// **'排除易混字符 (0 O 1 l I |)'**
  String get excludeAmbiguous;

  /// No description provided for @characterMode.
  ///
  /// In zh, this message translates to:
  /// **'字符'**
  String get characterMode;

  /// No description provided for @passphraseMode.
  ///
  /// In zh, this message translates to:
  /// **'短语'**
  String get passphraseMode;

  /// No description provided for @wordCount.
  ///
  /// In zh, this message translates to:
  /// **'单词数'**
  String get wordCount;

  /// No description provided for @separatorLabel.
  ///
  /// In zh, this message translates to:
  /// **'分隔符'**
  String get separatorLabel;

  /// No description provided for @appendDigit.
  ///
  /// In zh, this message translates to:
  /// **'追加数字'**
  String get appendDigit;

  /// No description provided for @recycleBin.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get recycleBin;

  /// No description provided for @noPasswordCannotReload.
  ///
  /// In zh, this message translates to:
  /// **'无密码信息，无法重新加载'**
  String get noPasswordCannotReload;

  /// No description provided for @authFailedCheckCredentials.
  ///
  /// In zh, this message translates to:
  /// **'认证失败，请检查用户名和密码'**
  String get authFailedCheckCredentials;

  /// No description provided for @serverConnectedPathNotAccessible.
  ///
  /// In zh, this message translates to:
  /// **'服务器已连接，但路径「{path}」不可访问'**
  String serverConnectedPathNotAccessible(Object path);

  /// No description provided for @pathNotExistTitle.
  ///
  /// In zh, this message translates to:
  /// **'路径不存在'**
  String get pathNotExistTitle;

  /// No description provided for @pathNotExistMessage.
  ///
  /// In zh, this message translates to:
  /// **'路径「{path}」不存在。数据库文件将在首次同步时生成。'**
  String pathNotExistMessage(Object path);

  /// No description provided for @reenterPath.
  ///
  /// In zh, this message translates to:
  /// **'重新输入'**
  String get reenterPath;

  /// No description provided for @createPath.
  ///
  /// In zh, this message translates to:
  /// **'创建目录'**
  String get createPath;

  /// No description provided for @creatingPath.
  ///
  /// In zh, this message translates to:
  /// **'创建中...'**
  String get creatingPath;

  /// No description provided for @pathCreated.
  ///
  /// In zh, this message translates to:
  /// **'目录已创建'**
  String get pathCreated;

  /// No description provided for @pathCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败: {msg}'**
  String pathCreateFailed(Object msg);

  /// No description provided for @connectionFailedMsg.
  ///
  /// In zh, this message translates to:
  /// **'连接失败: {msg}'**
  String connectionFailedMsg(Object msg);

  /// No description provided for @networkFailedCheckServer.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查服务器地址'**
  String get networkFailedCheckServer;

  /// No description provided for @remoteDatabaseNotExist.
  ///
  /// In zh, this message translates to:
  /// **'远程数据库不存在'**
  String get remoteDatabaseNotExist;

  /// No description provided for @pleaseConfigureWebDAVFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 WebDAV'**
  String get pleaseConfigureWebDAVFirst;

  /// No description provided for @cloudDatabaseNotExist.
  ///
  /// In zh, this message translates to:
  /// **'云端数据库不存在'**
  String get cloudDatabaseNotExist;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @lightTheme.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkTheme;

  /// No description provided for @colorScheme.
  ///
  /// In zh, this message translates to:
  /// **'配色方案'**
  String get colorScheme;

  /// No description provided for @themeSeedIndigo.
  ///
  /// In zh, this message translates to:
  /// **'靛紫'**
  String get themeSeedIndigo;

  /// No description provided for @themeSeedEmerald.
  ///
  /// In zh, this message translates to:
  /// **'青绿'**
  String get themeSeedEmerald;

  /// No description provided for @themeSeedSky.
  ///
  /// In zh, this message translates to:
  /// **'天蓝'**
  String get themeSeedSky;

  /// No description provided for @themeSeedAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀'**
  String get themeSeedAmber;

  /// No description provided for @themeSeedSlate.
  ///
  /// In zh, this message translates to:
  /// **'石板灰'**
  String get themeSeedSlate;

  /// No description provided for @themeSeedRose.
  ///
  /// In zh, this message translates to:
  /// **'品红'**
  String get themeSeedRose;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @groups.
  ///
  /// In zh, this message translates to:
  /// **'个分组'**
  String get groups;

  /// No description provided for @entries.
  ///
  /// In zh, this message translates to:
  /// **'个条目'**
  String get entries;

  /// No description provided for @closeBehavior.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口时'**
  String get closeBehavior;

  /// No description provided for @askEveryTime.
  ///
  /// In zh, this message translates to:
  /// **'每次询问'**
  String get askEveryTime;

  /// No description provided for @minimizeToTray.
  ///
  /// In zh, this message translates to:
  /// **'最小化到系统托盘'**
  String get minimizeToTray;

  /// No description provided for @minimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get minimize;

  /// No description provided for @exitApp.
  ///
  /// In zh, this message translates to:
  /// **'直接退出'**
  String get exitApp;

  /// No description provided for @closeWindowMessage.
  ///
  /// In zh, this message translates to:
  /// **'请选择关闭窗口的方式：'**
  String get closeWindowMessage;

  /// No description provided for @rememberChoice.
  ///
  /// In zh, this message translates to:
  /// **'记住我的选择'**
  String get rememberChoice;

  /// No description provided for @showMainWindow.
  ///
  /// In zh, this message translates to:
  /// **'显示主窗口'**
  String get showMainWindow;

  /// No description provided for @exit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// No description provided for @autoLock.
  ///
  /// In zh, this message translates to:
  /// **'自动锁定'**
  String get autoLock;

  /// No description provided for @autoLockDescription.
  ///
  /// In zh, this message translates to:
  /// **'无操作后自动锁定数据库'**
  String get autoLockDescription;

  /// No description provided for @autoSave.
  ///
  /// In zh, this message translates to:
  /// **'自动保存'**
  String get autoSave;

  /// No description provided for @autoSaveDescription.
  ///
  /// In zh, this message translates to:
  /// **'无操作后自动保存数据库'**
  String get autoSaveDescription;

  /// No description provided for @seconds.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get seconds;

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get disabled;

  /// No description provided for @minute.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minute;

  /// No description provided for @minutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutes;

  /// No description provided for @databaseBackup.
  ///
  /// In zh, this message translates to:
  /// **'数据库备份'**
  String get databaseBackup;

  /// No description provided for @autoBackup.
  ///
  /// In zh, this message translates to:
  /// **'自动备份'**
  String get autoBackup;

  /// No description provided for @autoBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'保存和同步前自动备份数据库'**
  String get autoBackupDescription;

  /// No description provided for @createBackupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get createBackupNow;

  /// No description provided for @noBackups.
  ///
  /// In zh, this message translates to:
  /// **'暂无备份'**
  String get noBackups;

  /// No description provided for @backupCreated.
  ///
  /// In zh, this message translates to:
  /// **'备份已创建'**
  String get backupCreated;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败'**
  String get backupFailed;

  /// No description provided for @restoreBackup.
  ///
  /// In zh, this message translates to:
  /// **'恢复备份'**
  String get restoreBackup;

  /// No description provided for @restoreBackupConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定恢复此备份？恢复前将自动备份当前数据库。'**
  String get restoreBackupConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In zh, this message translates to:
  /// **'备份已恢复'**
  String get backupRestored;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败'**
  String get backupRestoreFailed;

  /// No description provided for @backupNotFound.
  ///
  /// In zh, this message translates to:
  /// **'备份文件不存在'**
  String get backupNotFound;

  /// No description provided for @deleteBackup.
  ///
  /// In zh, this message translates to:
  /// **'删除备份'**
  String get deleteBackup;

  /// No description provided for @deleteBackupConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此备份？此操作不可撤销。'**
  String get deleteBackupConfirm;

  /// No description provided for @backupDeleted.
  ///
  /// In zh, this message translates to:
  /// **'备份已删除'**
  String get backupDeleted;

  /// No description provided for @backupRetention.
  ///
  /// In zh, this message translates to:
  /// **'备份数量'**
  String get backupRetention;

  /// No description provided for @backupRetentionInfo.
  ///
  /// In zh, this message translates to:
  /// **'保留最近 {count} 个备份'**
  String backupRetentionInfo(Object count);

  /// No description provided for @backupRetentionCount.
  ///
  /// In zh, this message translates to:
  /// **'保留 {count} 个备份'**
  String backupRetentionCount(Object count);

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @build.
  ///
  /// In zh, this message translates to:
  /// **'构建'**
  String get build;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'一个安全、开源的密码管理器，兼容 KeePass 格式。'**
  String get aboutDescription;

  /// No description provided for @sourceCode.
  ///
  /// In zh, this message translates to:
  /// **'源代码'**
  String get sourceCode;

  /// No description provided for @reportIssue.
  ///
  /// In zh, this message translates to:
  /// **'报告问题'**
  String get reportIssue;

  /// No description provided for @reportIssueDescription.
  ///
  /// In zh, this message translates to:
  /// **'反馈 Bug 或建议'**
  String get reportIssueDescription;

  /// No description provided for @linkCopied.
  ///
  /// In zh, this message translates to:
  /// **'链接已复制'**
  String get linkCopied;

  /// No description provided for @newVersionAvailable.
  ///
  /// In zh, this message translates to:
  /// **'有新版本可用'**
  String get newVersionAvailable;

  /// No description provided for @update.
  ///
  /// In zh, this message translates to:
  /// **'去更新'**
  String get update;

  /// No description provided for @alreadyLatest.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatest;

  /// No description provided for @licenses.
  ///
  /// In zh, this message translates to:
  /// **'许可证'**
  String get licenses;

  /// No description provided for @openSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可协议'**
  String get openSourceLicenses;

  /// No description provided for @changeMasterPassword.
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get changeMasterPassword;

  /// No description provided for @currentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get currentPassword;

  /// No description provided for @pleaseEnterCurrentPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码'**
  String get pleaseEnterCurrentPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @pleaseEnterNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入新密码'**
  String get pleaseEnterNewPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In zh, this message translates to:
  /// **'主密码已修改'**
  String get passwordChanged;

  /// No description provided for @history.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get history;

  /// No description provided for @noHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get noHistory;

  /// No description provided for @restoreVersion.
  ///
  /// In zh, this message translates to:
  /// **'恢复此版本'**
  String get restoreVersion;

  /// No description provided for @restoreVersionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定将条目恢复到此版本？当前状态会先保存到历史记录。'**
  String get restoreVersionConfirm;

  /// No description provided for @versionRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复到历史版本'**
  String get versionRestored;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get currentVersion;

  /// No description provided for @attachments.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get attachments;

  /// No description provided for @addAttachment.
  ///
  /// In zh, this message translates to:
  /// **'添加附件'**
  String get addAttachment;

  /// No description provided for @deleteAttachment.
  ///
  /// In zh, this message translates to:
  /// **'删除附件'**
  String get deleteAttachment;

  /// No description provided for @deleteAttachmentConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除此附件？'**
  String get deleteAttachmentConfirm;

  /// No description provided for @attachmentDeleted.
  ///
  /// In zh, this message translates to:
  /// **'附件已删除'**
  String get attachmentDeleted;

  /// No description provided for @attachmentAdded.
  ///
  /// In zh, this message translates to:
  /// **'附件已添加'**
  String get attachmentAdded;

  /// No description provided for @attachmentSaved.
  ///
  /// In zh, this message translates to:
  /// **'附件已保存'**
  String get attachmentSaved;

  /// No description provided for @saveAttachment.
  ///
  /// In zh, this message translates to:
  /// **'保存附件'**
  String get saveAttachment;

  /// No description provided for @noAttachments.
  ///
  /// In zh, this message translates to:
  /// **'暂无附件'**
  String get noAttachments;

  /// No description provided for @customFields.
  ///
  /// In zh, this message translates to:
  /// **'自定义字段'**
  String get customFields;

  /// No description provided for @addCustomField.
  ///
  /// In zh, this message translates to:
  /// **'添加字段'**
  String get addCustomField;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'字段名称'**
  String get fieldName;

  /// No description provided for @fieldValue.
  ///
  /// In zh, this message translates to:
  /// **'字段值'**
  String get fieldValue;

  /// No description provided for @protectField.
  ///
  /// In zh, this message translates to:
  /// **'保护字段'**
  String get protectField;

  /// No description provided for @unprotectField.
  ///
  /// In zh, this message translates to:
  /// **'取消保护'**
  String get unprotectField;

  /// No description provided for @fieldNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'字段名称不能为空'**
  String get fieldNameEmpty;

  /// No description provided for @fieldNameDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'字段名称重复: {name}'**
  String fieldNameDuplicate(Object name);

  /// No description provided for @fieldNameReserved.
  ///
  /// In zh, this message translates to:
  /// **'字段名称 \"{name}\" 是保留名称'**
  String fieldNameReserved(Object name);

  /// No description provided for @deleteCustomFieldConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除字段 \"{name}\"？'**
  String deleteCustomFieldConfirm(Object name);

  /// No description provided for @backupPasswordDifferent.
  ///
  /// In zh, this message translates to:
  /// **'备份使用了不同的密码（可能修改过主密码），请输入备份时的密码'**
  String get backupPasswordDifferent;

  /// No description provided for @backupPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入备份时的主密码'**
  String get backupPasswordHint;

  /// No description provided for @importCsv.
  ///
  /// In zh, this message translates to:
  /// **'导入 CSV'**
  String get importCsv;

  /// No description provided for @exportCsv.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV'**
  String get exportCsv;

  /// No description provided for @exportKdbx.
  ///
  /// In zh, this message translates to:
  /// **'导出 KDBX'**
  String get exportKdbx;

  /// No description provided for @importCsvTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入 CSV 文件'**
  String get importCsvTitle;

  /// No description provided for @importSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功导入 {count} 个条目'**
  String importSuccess(Object count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String importFailed(Object error);

  /// No description provided for @exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get exportSuccess;

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get exportFailed;

  /// No description provided for @noEntriesToExport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的条目'**
  String get noEntriesToExport;

  /// No description provided for @noEntriesInCsv.
  ///
  /// In zh, this message translates to:
  /// **'CSV 文件中未找到有效条目'**
  String get noEntriesInCsv;

  /// No description provided for @expiration.
  ///
  /// In zh, this message translates to:
  /// **'过期时间'**
  String get expiration;

  /// No description provided for @noExpiration.
  ///
  /// In zh, this message translates to:
  /// **'永不过期'**
  String get noExpiration;

  /// No description provided for @expired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get expired;

  /// No description provided for @expiresOn.
  ///
  /// In zh, this message translates to:
  /// **'过期于 {date}'**
  String expiresOn(Object date);

  /// No description provided for @keyFile.
  ///
  /// In zh, this message translates to:
  /// **'密钥文件'**
  String get keyFile;

  /// No description provided for @selectKeyFile.
  ///
  /// In zh, this message translates to:
  /// **'选择密钥文件（可选）'**
  String get selectKeyFile;

  /// No description provided for @keyFileSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择密钥文件'**
  String get keyFileSelected;

  /// No description provided for @changeKeyFile.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get changeKeyFile;

  /// No description provided for @removeKeyFile.
  ///
  /// In zh, this message translates to:
  /// **'移除密钥文件'**
  String get removeKeyFile;

  /// No description provided for @setupTotp.
  ///
  /// In zh, this message translates to:
  /// **'设置 TOTP'**
  String get setupTotp;

  /// No description provided for @totpUriLabel.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 otpauth:// 链接'**
  String get totpUriLabel;

  /// No description provided for @totpParseUri.
  ///
  /// In zh, this message translates to:
  /// **'解析链接'**
  String get totpParseUri;

  /// No description provided for @totpManualConfig.
  ///
  /// In zh, this message translates to:
  /// **'手动配置'**
  String get totpManualConfig;

  /// No description provided for @totpPasteUri.
  ///
  /// In zh, this message translates to:
  /// **'粘贴链接'**
  String get totpPasteUri;

  /// No description provided for @totpSecretLabel.
  ///
  /// In zh, this message translates to:
  /// **'密钥 (Base32)'**
  String get totpSecretLabel;

  /// No description provided for @totpPeriodLabel.
  ///
  /// In zh, this message translates to:
  /// **'周期（秒）'**
  String get totpPeriodLabel;

  /// No description provided for @totpDigitsLabel.
  ///
  /// In zh, this message translates to:
  /// **'位数'**
  String get totpDigitsLabel;

  /// No description provided for @totpAlgorithmLabel.
  ///
  /// In zh, this message translates to:
  /// **'算法'**
  String get totpAlgorithmLabel;

  /// No description provided for @totpAlgoSha1.
  ///
  /// In zh, this message translates to:
  /// **'SHA-1'**
  String get totpAlgoSha1;

  /// No description provided for @totpAlgoSha256.
  ///
  /// In zh, this message translates to:
  /// **'SHA-256'**
  String get totpAlgoSha256;

  /// No description provided for @totpAlgoSha512.
  ///
  /// In zh, this message translates to:
  /// **'SHA-512'**
  String get totpAlgoSha512;

  /// No description provided for @totpInvalidUri.
  ///
  /// In zh, this message translates to:
  /// **'无效的 otpauth:// 链接或 Base32 密钥'**
  String get totpInvalidUri;

  /// No description provided for @copiedUrl.
  ///
  /// In zh, this message translates to:
  /// **'已复制网址'**
  String get copiedUrl;

  /// No description provided for @copiedTotp.
  ///
  /// In zh, this message translates to:
  /// **'已复制 TOTP'**
  String get copiedTotp;

  /// No description provided for @copyUrl.
  ///
  /// In zh, this message translates to:
  /// **'复制网址'**
  String get copyUrl;

  /// No description provided for @copyTotp.
  ///
  /// In zh, this message translates to:
  /// **'复制 TOTP'**
  String get copyTotp;

  /// No description provided for @deleteTotp.
  ///
  /// In zh, this message translates to:
  /// **'删除 TOTP'**
  String get deleteTotp;

  /// No description provided for @deleteTotpConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定移除此条目的 TOTP 配置？'**
  String get deleteTotpConfirm;

  /// No description provided for @scanQrCode.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get scanQrCode;

  /// No description provided for @scanQrFromImage.
  ///
  /// In zh, this message translates to:
  /// **'从图片识别二维码'**
  String get scanQrFromImage;

  /// No description provided for @totpQrNoCode.
  ///
  /// In zh, this message translates to:
  /// **'未识别到二维码，请换一张更清晰的图片'**
  String get totpQrNoCode;

  /// No description provided for @totpQrNotOtpAuth.
  ///
  /// In zh, this message translates to:
  /// **'二维码内容不是有效的 otpauth:// TOTP 配置'**
  String get totpQrNotOtpAuth;

  /// No description provided for @scanQrHint.
  ///
  /// In zh, this message translates to:
  /// **'将摄像头对准 TOTP 二维码'**
  String get scanQrHint;

  /// No description provided for @toggleFlashlight.
  ///
  /// In zh, this message translates to:
  /// **'切换闪光灯'**
  String get toggleFlashlight;

  /// No description provided for @switchCamera.
  ///
  /// In zh, this message translates to:
  /// **'切换摄像头'**
  String get switchCamera;

  /// No description provided for @expirationReminder.
  ///
  /// In zh, this message translates to:
  /// **'过期提醒'**
  String get expirationReminder;

  /// No description provided for @expirationReminderDescription.
  ///
  /// In zh, this message translates to:
  /// **'密码即将过期时通知提醒'**
  String get expirationReminderDescription;

  /// No description provided for @daysBeforeExpiry.
  ///
  /// In zh, this message translates to:
  /// **'天前提醒'**
  String get daysBeforeExpiry;

  /// No description provided for @tags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tags;

  /// No description provided for @addTag.
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get addTag;

  /// No description provided for @filterByTag.
  ///
  /// In zh, this message translates to:
  /// **'按标签筛选'**
  String get filterByTag;

  /// No description provided for @allTags.
  ///
  /// In zh, this message translates to:
  /// **'全部标签'**
  String get allTags;

  /// No description provided for @noTags.
  ///
  /// In zh, this message translates to:
  /// **'无标签'**
  String get noTags;

  /// No description provided for @shortcutSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get shortcutSearch;

  /// No description provided for @shortcutSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get shortcutSave;

  /// No description provided for @biometricUnlock.
  ///
  /// In zh, this message translates to:
  /// **'指纹解锁'**
  String get biometricUnlock;

  /// No description provided for @biometricUnlockDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用指纹或面部识别解锁数据库'**
  String get biometricUnlockDescription;

  /// No description provided for @authenticateToEnableBiometric.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以启用指纹解锁'**
  String get authenticateToEnableBiometric;

  /// No description provided for @biometricEnabled.
  ///
  /// In zh, this message translates to:
  /// **'指纹解锁已启用'**
  String get biometricEnabled;

  /// No description provided for @biometricAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'指纹验证失败'**
  String get biometricAuthFailed;

  /// No description provided for @biometricDisabled.
  ///
  /// In zh, this message translates to:
  /// **'指纹解锁已禁用'**
  String get biometricDisabled;

  /// No description provided for @unlockMethod.
  ///
  /// In zh, this message translates to:
  /// **'解锁方式'**
  String get unlockMethod;

  /// No description provided for @unlockByPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码认证'**
  String get unlockByPassword;

  /// No description provided for @unlockByBiometric.
  ///
  /// In zh, this message translates to:
  /// **'指纹认证'**
  String get unlockByBiometric;

  /// No description provided for @unlockWithBiometric.
  ///
  /// In zh, this message translates to:
  /// **'使用指纹解锁'**
  String get unlockWithBiometric;

  /// No description provided for @authenticateToUnlock.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以解锁数据库'**
  String get authenticateToUnlock;

  /// No description provided for @noStoredPassword.
  ///
  /// In zh, this message translates to:
  /// **'没有存储的密码，请先使用密码解锁'**
  String get noStoredPassword;

  /// No description provided for @syncRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get syncRetry;

  /// No description provided for @syncRetrying.
  ///
  /// In zh, this message translates to:
  /// **'重试中... ({attempt}/{maxAttempts})'**
  String syncRetrying(Object attempt, Object maxAttempts);

  /// No description provided for @syncErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络和服务器设置。'**
  String get syncErrorNetwork;

  /// No description provided for @syncErrorAuth.
  ///
  /// In zh, this message translates to:
  /// **'认证失败，请在设置中检查用户名和密码。'**
  String get syncErrorAuth;

  /// No description provided for @syncErrorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'远程数据库不存在，请在设置中检查远程路径。'**
  String get syncErrorNotFound;

  /// No description provided for @syncErrorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时，服务器可能暂时不可用。'**
  String get syncErrorTimeout;

  /// No description provided for @syncErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后再试。'**
  String get syncErrorServer;

  /// No description provided for @databaseCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'数据库文件已损坏或格式不正确。'**
  String get databaseCorrupted;

  /// No description provided for @restoreFromBackup.
  ///
  /// In zh, this message translates to:
  /// **'从备份恢复'**
  String get restoreFromBackup;

  /// No description provided for @restoreFromBackupDescription.
  ///
  /// In zh, this message translates to:
  /// **'找到可用的备份，是否从最新备份恢复？'**
  String get restoreFromBackupDescription;

  /// No description provided for @noBackupAvailable.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的备份进行恢复，请从外部备份手动恢复。'**
  String get noBackupAvailable;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// No description provided for @sortTitleAsc.
  ///
  /// In zh, this message translates to:
  /// **'标题 A→Z'**
  String get sortTitleAsc;

  /// No description provided for @sortTitleDesc.
  ///
  /// In zh, this message translates to:
  /// **'标题 Z→A'**
  String get sortTitleDesc;

  /// No description provided for @sortCreatedNewest.
  ///
  /// In zh, this message translates to:
  /// **'最新创建'**
  String get sortCreatedNewest;

  /// No description provided for @sortCreatedOldest.
  ///
  /// In zh, this message translates to:
  /// **'最早创建'**
  String get sortCreatedOldest;

  /// No description provided for @sortModifiedNewest.
  ///
  /// In zh, this message translates to:
  /// **'最近修改'**
  String get sortModifiedNewest;

  /// No description provided for @sortModifiedOldest.
  ///
  /// In zh, this message translates to:
  /// **'最早修改'**
  String get sortModifiedOldest;

  /// No description provided for @sortExpiredFirst.
  ///
  /// In zh, this message translates to:
  /// **'过期优先'**
  String get sortExpiredFirst;

  /// No description provided for @batchSelect.
  ///
  /// In zh, this message translates to:
  /// **'批量选择'**
  String get batchSelect;

  /// No description provided for @batchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchDelete;

  /// No description provided for @batchMove.
  ///
  /// In zh, this message translates to:
  /// **'批量移动'**
  String get batchMove;

  /// No description provided for @batchTag.
  ///
  /// In zh, this message translates to:
  /// **'批量标签'**
  String get batchTag;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String selectedCount(Object count);

  /// No description provided for @cancelSelection.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get cancelSelection;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @batchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除选中的 {count} 个条目吗？'**
  String batchDeleteConfirm(Object count);

  /// No description provided for @batchTagTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get batchTagTitle;

  /// No description provided for @batchTagHint.
  ///
  /// In zh, this message translates to:
  /// **'输入标签名称'**
  String get batchTagHint;

  /// No description provided for @groupsTab.
  ///
  /// In zh, this message translates to:
  /// **'分组'**
  String get groupsTab;

  /// No description provided for @entriesTab.
  ///
  /// In zh, this message translates to:
  /// **'条目'**
  String get entriesTab;

  /// No description provided for @totpTab.
  ///
  /// In zh, this message translates to:
  /// **'TOTP'**
  String get totpTab;

  /// No description provided for @searchTab.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTab;

  /// No description provided for @toolsTab.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get toolsTab;

  /// No description provided for @noTotpEntries.
  ///
  /// In zh, this message translates to:
  /// **'暂无配置 TOTP 的条目'**
  String get noTotpEntries;

  /// No description provided for @unsavedChanges.
  ///
  /// In zh, this message translates to:
  /// **'有未保存的更改'**
  String get unsavedChanges;

  /// No description provided for @allSaved.
  ///
  /// In zh, this message translates to:
  /// **'所有更改已保存'**
  String get allSaved;

  /// No description provided for @strengthWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In zh, this message translates to:
  /// **'一般'**
  String get strengthFair;

  /// No description provided for @strengthGood.
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get strengthGood;

  /// No description provided for @strengthStrong.
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get strengthStrong;

  /// No description provided for @csvPlaintextWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出明文密码'**
  String get csvPlaintextWarningTitle;

  /// No description provided for @csvPlaintextWarningBody.
  ///
  /// In zh, this message translates to:
  /// **'CSV 文件不会加密，并包含所有条目的明文密码。任何能访问该文件的人都可以读取这些密码。建议优先导出 KDBX。是否仍要继续？'**
  String get csvPlaintextWarningBody;

  /// No description provided for @webDavInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址必须是有效的 HTTP 或 HTTPS URL'**
  String get webDavInvalidUrl;

  /// No description provided for @webDavInsecureHttpTitle.
  ///
  /// In zh, this message translates to:
  /// **'不安全的 WebDAV 连接'**
  String get webDavInsecureHttpTitle;

  /// No description provided for @webDavInsecureHttpBody.
  ///
  /// In zh, this message translates to:
  /// **'此服务器使用未加密的 HTTP，登录凭据和数据库可能被网络中的其他人截获。建议使用 HTTPS。是否仍要继续？'**
  String get webDavInsecureHttpBody;

  /// No description provided for @privacyProtection.
  ///
  /// In zh, this message translates to:
  /// **'隐私保护'**
  String get privacyProtection;

  /// No description provided for @blockScreenshots.
  ///
  /// In zh, this message translates to:
  /// **'禁止截屏'**
  String get blockScreenshots;

  /// No description provided for @blockScreenshotsDescription.
  ///
  /// In zh, this message translates to:
  /// **'在 Android 上阻止截屏和最近任务预览。'**
  String get blockScreenshotsDescription;

  /// No description provided for @hideInBackground.
  ///
  /// In zh, this message translates to:
  /// **'后台隐藏内容'**
  String get hideInBackground;

  /// No description provided for @hideInBackgroundDescription.
  ///
  /// In zh, this message translates to:
  /// **'应用失去焦点或进入后台时遮挡密码库内容。'**
  String get hideInBackgroundDescription;

  /// No description provided for @backupIntegrityFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份完整性校验失败'**
  String get backupIntegrityFailed;

  /// No description provided for @pendingUploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'待同步的云端更改上传失败，已保留本地加密副本。'**
  String get pendingUploadFailed;

  /// No description provided for @pendingUploadConflict.
  ///
  /// In zh, this message translates to:
  /// **'云端数据已发生变化，待同步的本地更改未覆盖远端。'**
  String get pendingUploadConflict;

  /// No description provided for @discardChangesTitle.
  ///
  /// In zh, this message translates to:
  /// **'有未保存的更改'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In zh, this message translates to:
  /// **'当前条目的修改尚未保存，确定放弃并离开吗？'**
  String get discardChangesBody;

  /// No description provided for @discardAndLeave.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get discardAndLeave;

  /// No description provided for @keepEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get keepEditing;

  /// No description provided for @entryNoLongerExists.
  ///
  /// In zh, this message translates to:
  /// **'该条目在当前打开的数据库中已不存在，修改未保存。'**
  String get entryNoLongerExists;

  /// No description provided for @closeUnsavedTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据库有未保存更改'**
  String get closeUnsavedTitle;

  /// No description provided for @closeUnsavedBody.
  ///
  /// In zh, this message translates to:
  /// **'部分更改未能写入磁盘。确定放弃这些更改并关闭吗？'**
  String get closeUnsavedBody;

  /// No description provided for @discardAndClose.
  ///
  /// In zh, this message translates to:
  /// **'放弃并关闭'**
  String get discardAndClose;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
