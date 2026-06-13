import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
    Locale('zh')
  ];

  /// No description provided for @enterMasterKey.
  ///
  /// In en, this message translates to:
  /// **'Enter the master key'**
  String get enterMasterKey;

  /// No description provided for @masterKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Master Key'**
  String get masterKeyLabel;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @masterKeyHint.
  ///
  /// In en, this message translates to:
  /// **'The master key is never saved; you must re-enter it on every launch.\nLeave it empty to use a single space as the key (compatible with the old version).'**
  String get masterKeyHint;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @tabQuery.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabQuery;

  /// No description provided for @tabAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tabAdd;

  /// No description provided for @tabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get tabList;

  /// No description provided for @syncIdle.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get syncIdle;

  /// No description provided for @syncWorking.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncWorking;

  /// No description provided for @syncOk.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncOk;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncOffline;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncError;

  /// No description provided for @queryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Website (partial keyword match supported)'**
  String get queryFieldLabel;

  /// No description provided for @queryInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'Wrong master key: matching website found but cannot decrypt'**
  String get queryInvalidKey;

  /// No description provided for @queryNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching records found'**
  String get queryNoMatch;

  /// No description provided for @queryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a website and press Enter to search'**
  String get queryPrompt;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copyUsername.
  ///
  /// In en, this message translates to:
  /// **'Copy username'**
  String get copyUsername;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// No description provided for @usernameCopied.
  ///
  /// In en, this message translates to:
  /// **'Username copied'**
  String get usernameCopied;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get passwordCopied;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmDelete;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete this record for {website}?'**
  String deleteBody(String website);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @generatePassword.
  ///
  /// In en, this message translates to:
  /// **'Generate password'**
  String get generatePassword;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @charUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper'**
  String get charUpper;

  /// No description provided for @charLower.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get charLower;

  /// No description provided for @charDigits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get charDigits;

  /// No description provided for @charSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get charSpecial;

  /// No description provided for @saveToVault.
  ///
  /// In en, this message translates to:
  /// **'Save to vault'**
  String get saveToVault;

  /// No description provided for @websiteRequired.
  ///
  /// In en, this message translates to:
  /// **'Website *'**
  String get websiteRequired;

  /// No description provided for @usernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get usernameOptional;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get passwordRequired;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @websitePasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Website and password cannot be empty'**
  String get websitePasswordEmpty;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @duplicateEntry.
  ///
  /// In en, this message translates to:
  /// **'An identical entry already exists'**
  String get duplicateEntry;

  /// No description provided for @emptyVault.
  ///
  /// In en, this message translates to:
  /// **'The vault is empty. Add your first entry under \"Add\".'**
  String get emptyVault;

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String totalCount(int count);

  /// No description provided for @sortNameAsc.
  ///
  /// In en, this message translates to:
  /// **'Name A→Z'**
  String get sortNameAsc;

  /// No description provided for @sortNameDesc.
  ///
  /// In en, this message translates to:
  /// **'Name Z→A'**
  String get sortNameDesc;

  /// No description provided for @sortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Date added (newest first)'**
  String get sortTimeDesc;

  /// No description provided for @sortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Date added (oldest first)'**
  String get sortTimeAsc;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @decryptFailedCopy.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt with the current master key; copy failed'**
  String get decryptFailedCopy;

  /// No description provided for @noUsername.
  ///
  /// In en, this message translates to:
  /// **'(no username)'**
  String get noUsername;

  /// No description provided for @cannotDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Cannot decrypt'**
  String get cannotDecrypt;

  /// No description provided for @cannotDecryptBody.
  ///
  /// In en, this message translates to:
  /// **'This record cannot be decrypted with the current master key.\nTap back at the top-left and re-enter the correct master key.'**
  String get cannotDecryptBody;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @updated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updated;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @sectionCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get sectionCloudSync;

  /// No description provided for @enableCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Enable cloud sync'**
  String get enableCloudSync;

  /// No description provided for @enableCloudSyncSub.
  ///
  /// In en, this message translates to:
  /// **'When off, all data stays only on this device'**
  String get enableCloudSyncSub;

  /// No description provided for @sectionSyncPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sync prompts'**
  String get sectionSyncPrompt;

  /// No description provided for @promptBeforePull.
  ///
  /// In en, this message translates to:
  /// **'Prompt to pull before changes'**
  String get promptBeforePull;

  /// No description provided for @promptBeforePullSub.
  ///
  /// In en, this message translates to:
  /// **'Show a \"pull from remote\" prompt before add / edit / delete'**
  String get promptBeforePullSub;

  /// No description provided for @promptAfterPush.
  ///
  /// In en, this message translates to:
  /// **'Prompt to push after changes'**
  String get promptAfterPush;

  /// No description provided for @smartSkip.
  ///
  /// In en, this message translates to:
  /// **'Smart skip'**
  String get smartSkip;

  /// No description provided for @smartSkipSub.
  ///
  /// In en, this message translates to:
  /// **'Automatically skip the \"pull\" prompt when the remote has no updates'**
  String get smartSkipSub;

  /// No description provided for @sectionMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get sectionMaintenance;

  /// No description provided for @compactNow.
  ///
  /// In en, this message translates to:
  /// **'Compact the log now'**
  String get compactNow;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro'**
  String get aboutSubtitle;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersionLabel;

  /// No description provided for @aboutAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthorLabel;

  /// No description provided for @aboutRepoLabel.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get aboutRepoLabel;

  /// No description provided for @compactDone.
  ///
  /// In en, this message translates to:
  /// **'Compacted: {count} active records, saved {size}'**
  String compactDone(int count, String size);

  /// No description provided for @compactionStatus.
  ///
  /// In en, this message translates to:
  /// **'Now {active} active / {total} lines (amplification {amp}×)'**
  String compactionStatus(int active, int total, String amp);

  /// No description provided for @backendDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get backendDisabled;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role:'**
  String get roleLabel;

  /// No description provided for @repoName.
  ///
  /// In en, this message translates to:
  /// **'Repository name'**
  String get repoName;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @filePath.
  ///
  /// In en, this message translates to:
  /// **'File path'**
  String get filePath;

  /// No description provided for @patHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored in the OS Keychain; never written to any file'**
  String get patHelper;

  /// No description provided for @syncAllBackendsPullFailed.
  ///
  /// In en, this message translates to:
  /// **'All backends failed to pull: {detail}'**
  String syncAllBackendsPullFailed(String detail);

  /// No description provided for @syncPulledFrom.
  ///
  /// In en, this message translates to:
  /// **'Pulled from {backend}'**
  String syncPulledFrom(String backend);

  /// No description provided for @syncNoPrimary.
  ///
  /// In en, this message translates to:
  /// **'No usable Primary backend configured'**
  String get syncNoPrimary;

  /// No description provided for @syncPrimaryOffline.
  ///
  /// In en, this message translates to:
  /// **'Primary offline: {detail}'**
  String syncPrimaryOffline(String detail);

  /// No description provided for @syncPrimaryPushFailed.
  ///
  /// In en, this message translates to:
  /// **'Primary push failed: {detail}'**
  String syncPrimaryPushFailed(String detail);

  /// No description provided for @syncPushConflictManual.
  ///
  /// In en, this message translates to:
  /// **'Push conflict; auto-merge failed — please sync manually'**
  String get syncPushConflictManual;

  /// No description provided for @syncPushedPrimary.
  ///
  /// In en, this message translates to:
  /// **'Pushed to Primary'**
  String get syncPushedPrimary;

  /// No description provided for @syncRemoteEmptySkipped.
  ///
  /// In en, this message translates to:
  /// **'Remote is empty; skipped overwrite (to avoid wiping local)'**
  String get syncRemoteEmptySkipped;

  /// No description provided for @syncOverwroteLocalFrom.
  ///
  /// In en, this message translates to:
  /// **'Overwrote local from {backend}'**
  String syncOverwroteLocalFrom(String backend);

  /// No description provided for @syncPrimaryOverwriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Primary overwrite failed: {detail}'**
  String syncPrimaryOverwriteFailed(String detail);

  /// No description provided for @syncOverwriteRemoteStillChanging.
  ///
  /// In en, this message translates to:
  /// **'Overwrite failed: remote keeps changing, please retry'**
  String get syncOverwriteRemoteStillChanging;

  /// No description provided for @syncOverwroteRemoteWithLocal.
  ///
  /// In en, this message translates to:
  /// **'Overwrote remote with local'**
  String get syncOverwroteRemoteWithLocal;

  /// No description provided for @syncGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String syncGenericError(String detail);

  /// No description provided for @syncMirrorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Mirrors'**
  String get syncMirrorsLabel;

  /// No description provided for @syncMirrorOk.
  ///
  /// In en, this message translates to:
  /// **'ok'**
  String get syncMirrorOk;

  /// No description provided for @syncMirrorConflict.
  ///
  /// In en, this message translates to:
  /// **'conflict'**
  String get syncMirrorConflict;

  /// No description provided for @syncMirrorFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get syncMirrorFailed;

  /// No description provided for @syncPrimaryResult.
  ///
  /// In en, this message translates to:
  /// **'Primary {backend} ({outcome})'**
  String syncPrimaryResult(String backend, String outcome);

  /// No description provided for @repoNotFoundOrNoAccess.
  ///
  /// In en, this message translates to:
  /// **'Repository not found, or the token has no access: {repo}'**
  String repoNotFoundOrNoAccess(String repo);

  /// No description provided for @webdavFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'Target folder doesn\'t exist. Create it in your WebDAV/Nutstore account first, and set the remote file path to match (e.g. /PassPro/passwords.log).'**
  String get webdavFolderMissing;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @personalAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Personal Access Token'**
  String get personalAccessToken;

  /// No description provided for @webdavAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get webdavAccount;

  /// No description provided for @webdavServer.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get webdavServer;

  /// No description provided for @webdavRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote file path'**
  String get webdavRemotePath;

  /// No description provided for @webdavAppPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get webdavAppPassword;

  /// No description provided for @webdavAppPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Nutstore: enter the app password from Third-Party App Management'**
  String get webdavAppPasswordHelper;

  /// No description provided for @rolePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get rolePrimary;

  /// No description provided for @roleMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get roleMirror;

  /// No description provided for @testOkNoFile.
  ///
  /// In en, this message translates to:
  /// **'Connected (the remote file does not exist yet; the first push will create it)'**
  String get testOkNoFile;

  /// No description provided for @testOkSha.
  ///
  /// In en, this message translates to:
  /// **'Connected (current sha={sha}…)'**
  String testOkSha(String sha);

  /// No description provided for @testFailHttp.
  ///
  /// In en, this message translates to:
  /// **'Failed: HTTP {code} {message}'**
  String testFailHttp(String code, String message);

  /// No description provided for @testFail.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String testFail(String error);

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @pullTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull from remote first?'**
  String get pullTitle;

  /// No description provided for @pullMessage.
  ///
  /// In en, this message translates to:
  /// **'The remote may have updates. Pull before continuing?'**
  String get pullMessage;

  /// No description provided for @pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @pushTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get pushTitle;

  /// No description provided for @pushMessage.
  ///
  /// In en, this message translates to:
  /// **'Push to the remote?'**
  String get pushMessage;

  /// No description provided for @push.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get push;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @dontPromptThisSession.
  ///
  /// In en, this message translates to:
  /// **'Don\'t prompt again this session'**
  String get dontPromptThisSession;

  /// No description provided for @syncMenu.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncMenu;

  /// No description provided for @syncPull.
  ///
  /// In en, this message translates to:
  /// **'Pull and merge'**
  String get syncPull;

  /// No description provided for @syncPush.
  ///
  /// In en, this message translates to:
  /// **'Push current data'**
  String get syncPush;

  /// No description provided for @syncOverwriteLocal.
  ///
  /// In en, this message translates to:
  /// **'Overwrite local with cloud'**
  String get syncOverwriteLocal;

  /// No description provided for @syncOverwriteRemote.
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud with local'**
  String get syncOverwriteRemote;

  /// No description provided for @syncOverwriteLocalConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite local data with {file} from the cloud. Unpushed local changes will be lost. Continue?'**
  String syncOverwriteLocalConfirm(String file);

  /// No description provided for @syncOverwriteRemoteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite {file} in the cloud with your local data. The current cloud content will be replaced. Continue?'**
  String syncOverwriteRemoteConfirm(String file);

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @overwroteLocal.
  ///
  /// In en, this message translates to:
  /// **'Local data overwritten with cloud'**
  String get overwroteLocal;

  /// No description provided for @overwroteRemote.
  ///
  /// In en, this message translates to:
  /// **'Cloud data overwritten with local'**
  String get overwroteRemote;

  /// No description provided for @accountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountMenu;

  /// No description provided for @changeMasterKey.
  ///
  /// In en, this message translates to:
  /// **'Change master key'**
  String get changeMasterKey;

  /// No description provided for @newMasterKey.
  ///
  /// In en, this message translates to:
  /// **'New master key'**
  String get newMasterKey;

  /// No description provided for @confirmNewMasterKey.
  ///
  /// In en, this message translates to:
  /// **'Confirm new master key'**
  String get confirmNewMasterKey;

  /// No description provided for @masterKeyMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two master keys do not match'**
  String get masterKeyMismatch;

  /// No description provided for @masterKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Master key changed'**
  String get masterKeyChanged;

  /// No description provided for @changeMasterKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Hot-swaps the master key used by the current session. It only affects encryption/decryption from now on and does not modify existing entries.'**
  String get changeMasterKeyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'fr',
        'ja',
        'ko',
        'ru',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
