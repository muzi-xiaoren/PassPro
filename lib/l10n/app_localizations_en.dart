// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get enterMasterKey => 'Enter the master key';

  @override
  String get masterKeyLabel => 'Master Key';

  @override
  String get unlock => 'Unlock';

  @override
  String get masterKeyHint =>
      'The master key is never saved; you must re-enter it on every launch.\nLeave it empty to use a single space as the key (compatible with the old version).';

  @override
  String get settings => 'Settings';

  @override
  String get lock => 'Lock';

  @override
  String get tabQuery => 'Search';

  @override
  String get tabAdd => 'Add';

  @override
  String get tabList => 'List';

  @override
  String get syncIdle => 'Not synced';

  @override
  String get syncWorking => 'Syncing…';

  @override
  String get syncOk => 'Synced';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncError => 'Sync failed';

  @override
  String get queryFieldLabel => 'Website (partial keyword match supported)';

  @override
  String get queryInvalidKey =>
      'Wrong master key: matching website found but cannot decrypt';

  @override
  String get queryNoMatch => 'No matching records found';

  @override
  String get queryPrompt => 'Enter a website and press Enter to search';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get copyUsername => 'Copy username';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get usernameCopied => 'Username copied';

  @override
  String get passwordCopied => 'Password copied';

  @override
  String get confirmDelete => 'Confirm deletion';

  @override
  String deleteBody(String website) {
    return 'Delete this record for $website?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get deleted => 'Deleted';

  @override
  String get generatePassword => 'Generate password';

  @override
  String get length => 'Length';

  @override
  String get generate => 'Generate';

  @override
  String get charUpper => 'Upper';

  @override
  String get charLower => 'Lower';

  @override
  String get charDigits => 'Digits';

  @override
  String get charSpecial => 'Special';

  @override
  String get saveToVault => 'Save to vault';

  @override
  String get websiteRequired => 'Website *';

  @override
  String get usernameOptional => 'Username (optional)';

  @override
  String get passwordRequired => 'Password *';

  @override
  String get save => 'Save';

  @override
  String get websitePasswordEmpty => 'Website and password cannot be empty';

  @override
  String get saved => 'Saved';

  @override
  String get duplicateEntry => 'An identical entry already exists';

  @override
  String get emptyVault =>
      'The vault is empty. Add your first entry under \"Add\".';

  @override
  String totalCount(int count) {
    return '$count total';
  }

  @override
  String get sortNameAsc => 'Name A→Z';

  @override
  String get sortNameDesc => 'Name Z→A';

  @override
  String get sortTimeDesc => 'Date added (newest first)';

  @override
  String get sortTimeAsc => 'Date added (oldest first)';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get decryptFailedCopy =>
      'Cannot decrypt with the current master key; copy failed';

  @override
  String get noUsername => '(no username)';

  @override
  String get cannotDecrypt => 'Cannot decrypt';

  @override
  String get cannotDecryptBody =>
      'This record cannot be decrypted with the current master key.\nTap back at the top-left and re-enter the correct master key.';

  @override
  String get website => 'Website';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get updated => 'Updated';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow system';

  @override
  String get sectionCloudSync => 'Cloud sync';

  @override
  String get enableCloudSync => 'Enable cloud sync';

  @override
  String get enableCloudSyncSub =>
      'When off, all data stays only on this device';

  @override
  String get sectionSyncPrompt => 'Sync prompts';

  @override
  String get promptBeforePull => 'Prompt to pull before changes';

  @override
  String get promptBeforePullSub =>
      'Show a \"pull from remote\" prompt before add / edit / delete';

  @override
  String get promptAfterPush => 'Prompt to push after changes';

  @override
  String get smartSkip => 'Smart skip';

  @override
  String get smartSkipSub =>
      'Automatically skip the \"pull\" prompt when the remote has no updates';

  @override
  String get sectionMaintenance => 'Maintenance';

  @override
  String get compactNow => 'Compact the log now';

  @override
  String get sectionAbout => 'About';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String compactDone(int count, String size) {
    return 'Compacted: $count active records, saved $size';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return 'Now $active active / $total lines (amplification $amp×)';
  }

  @override
  String get backendDisabled => 'Not enabled';

  @override
  String get enable => 'Enable';

  @override
  String get roleLabel => 'Role:';

  @override
  String get repoName => 'Repository name';

  @override
  String get branch => 'Branch';

  @override
  String get filePath => 'File path';

  @override
  String get patHelper =>
      'Stored in the OS Keychain; never written to any file';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return 'All backends failed to pull: $detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return 'Pulled from $backend';
  }

  @override
  String get syncNoPrimary => 'No usable Primary backend configured';

  @override
  String syncPrimaryOffline(String detail) {
    return 'Primary offline: $detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return 'Primary push failed: $detail';
  }

  @override
  String get syncPushConflictManual =>
      'Push conflict; auto-merge failed — please sync manually';

  @override
  String get syncPushedPrimary => 'Pushed to Primary';

  @override
  String get syncRemoteEmptySkipped =>
      'Remote is empty; skipped overwrite (to avoid wiping local)';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return 'Overwrote local from $backend';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return 'Primary overwrite failed: $detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging =>
      'Overwrite failed: remote keeps changing, please retry';

  @override
  String get syncOverwroteRemoteWithLocal => 'Overwrote remote with local';

  @override
  String syncGenericError(String detail) {
    return 'Error: $detail';
  }

  @override
  String get syncMirrorsLabel => 'Mirrors';

  @override
  String get syncMirrorOk => 'ok';

  @override
  String get syncMirrorConflict => 'conflict';

  @override
  String get syncMirrorFailed => 'failed';

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return 'Repository not found, or the token has no access: $repo';
  }

  @override
  String get webdavFolderMissing =>
      'Target folder doesn\'t exist. Create it in your WebDAV/Nutstore account first, and set the remote file path to match (e.g. /PassPro/passwords.log).';

  @override
  String get owner => 'Owner';

  @override
  String get personalAccessToken => 'Personal Access Token';

  @override
  String get webdavAccount => 'Account';

  @override
  String get webdavServer => 'Server address';

  @override
  String get webdavRemotePath => 'Remote file path';

  @override
  String get webdavAppPassword => 'App password';

  @override
  String get webdavAppPasswordHelper =>
      'Nutstore: enter the app password from Third-Party App Management';

  @override
  String get rolePrimary => 'Primary';

  @override
  String get roleMirror => 'Mirror';

  @override
  String get testOkNoFile =>
      'Connected (the remote file does not exist yet; the first push will create it)';

  @override
  String testOkSha(String sha) {
    return 'Connected (current sha=$sha…)';
  }

  @override
  String testFailHttp(String code, String message) {
    return 'Failed: HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return 'Failed: $error';
  }

  @override
  String get testConnection => 'Test connection';

  @override
  String get pullTitle => 'Pull from remote first?';

  @override
  String get pullMessage =>
      'The remote may have updates. Pull before continuing?';

  @override
  String get pull => 'Pull';

  @override
  String get skip => 'Skip';

  @override
  String get pushTitle => 'Saved locally';

  @override
  String get pushMessage => 'Push to the remote?';

  @override
  String get push => 'Push';

  @override
  String get later => 'Later';

  @override
  String get dontPromptThisSession => 'Don\'t prompt again this session';

  @override
  String get syncMenu => 'Sync';

  @override
  String get syncPull => 'Pull and merge';

  @override
  String get syncPush => 'Push current data';

  @override
  String get syncOverwriteLocal => 'Overwrite local with cloud';

  @override
  String get syncOverwriteRemote => 'Overwrite cloud with local';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return 'This will overwrite local data with $file from the cloud. Unpushed local changes will be lost. Continue?';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return 'This will overwrite $file in the cloud with your local data. The current cloud content will be replaced. Continue?';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get overwroteLocal => 'Local data overwritten with cloud';

  @override
  String get overwroteRemote => 'Cloud data overwritten with local';

  @override
  String get accountMenu => 'Account';

  @override
  String get changeMasterKey => 'Change master key';

  @override
  String get newMasterKey => 'New master key';

  @override
  String get confirmNewMasterKey => 'Confirm new master key';

  @override
  String get masterKeyMismatch => 'The two master keys do not match';

  @override
  String get masterKeyChanged => 'Master key changed';

  @override
  String get changeMasterKeyHint =>
      'Hot-swaps the master key used by the current session. It only affects encryption/decryption from now on and does not modify existing entries.';
}
