// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get enterMasterKey => 'マスターキーを入力してください';

  @override
  String get masterKeyLabel => 'マスターキー';

  @override
  String get unlock => 'ロック解除';

  @override
  String get masterKeyHint =>
      'マスターキーは保存されず、起動のたびに再入力が必要です。\n空欄のままにすると半角スペース1文字をキーとして使用します（旧バージョンと互換）。';

  @override
  String get settings => '設定';

  @override
  String get lock => 'ロック';

  @override
  String get tabQuery => '検索';

  @override
  String get tabAdd => '追加';

  @override
  String get tabList => '一覧';

  @override
  String get syncIdle => '未同期';

  @override
  String get syncWorking => '同期中…';

  @override
  String get syncOk => '同期済み';

  @override
  String get syncOffline => 'オフライン';

  @override
  String get syncError => '同期に失敗';

  @override
  String get queryFieldLabel => 'サイト（キーワードの部分一致に対応）';

  @override
  String get queryInvalidKey => 'マスターキーが違います：一致するサイトはありますが復号できません';

  @override
  String get queryNoMatch => '一致するレコードが見つかりません';

  @override
  String get queryPrompt => 'サイトを入力し、Enterで検索';

  @override
  String get edit => '編集';

  @override
  String get delete => '削除';

  @override
  String get copyUsername => 'ユーザー名をコピー';

  @override
  String get hide => '非表示';

  @override
  String get show => '表示';

  @override
  String get copyPassword => 'パスワードをコピー';

  @override
  String get usernameCopied => 'ユーザー名をコピーしました';

  @override
  String get passwordCopied => 'パスワードをコピーしました';

  @override
  String get confirmDelete => '削除の確認';

  @override
  String deleteBody(String website) {
    return '$website のこのレコードを削除しますか？';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get deleted => '削除しました';

  @override
  String get generatePassword => 'パスワードを生成';

  @override
  String get length => '長さ';

  @override
  String get generate => '生成';

  @override
  String get charUpper => '大文字';

  @override
  String get charLower => '小文字';

  @override
  String get charDigits => '数字';

  @override
  String get charSpecial => '記号';

  @override
  String get saveToVault => '保管庫に保存';

  @override
  String get websiteRequired => 'サイト *';

  @override
  String get usernameOptional => 'ユーザー名（任意）';

  @override
  String get passwordRequired => 'パスワード *';

  @override
  String get save => '保存';

  @override
  String get websitePasswordEmpty => 'サイトとパスワードは空にできません';

  @override
  String get saved => '保存しました';

  @override
  String get duplicateEntry => '同じエントリが既に存在します';

  @override
  String get emptyVault => '保管庫は空です。「追加」から最初のエントリを登録してください';

  @override
  String totalCount(int count) {
    return '全 $count 件';
  }

  @override
  String get sortNameAsc => '名前 A→Z';

  @override
  String get sortNameDesc => '名前 Z→A';

  @override
  String get sortTimeDesc => '追加日時（新しい順）';

  @override
  String get sortTimeAsc => '追加日時（古い順）';

  @override
  String get sortTooltip => '並べ替え';

  @override
  String get decryptFailedCopy => '現在のマスターキーで復号できないため、コピーに失敗しました';

  @override
  String get noUsername => '（ユーザー名なし）';

  @override
  String get cannotDecrypt => '復号できません';

  @override
  String get cannotDecryptBody =>
      'このレコードは現在のマスターキーでは復号できません。\n左上の戻るをタップし、正しいマスターキーを入力し直してください。';

  @override
  String get website => 'サイト';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get updated => '更新しました';

  @override
  String get sectionLanguage => '言語';

  @override
  String get language => '言語';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get sectionCloudSync => 'クラウド同期';

  @override
  String get enableCloudSync => 'クラウド同期を有効にする';

  @override
  String get enableCloudSyncSub => '無効にすると、すべてのデータはこの端末にのみ保存されます';

  @override
  String get sectionSyncPrompt => '同期の確認';

  @override
  String get promptBeforePull => '操作前にプルを確認';

  @override
  String get promptBeforePullSub => '追加／編集／削除の前に「リモートからプル」の確認を表示';

  @override
  String get promptAfterPush => '操作後にプッシュを確認';

  @override
  String get smartSkip => 'スマートスキップ';

  @override
  String get smartSkipSub => 'リモートに更新がない場合は「プル」の確認を自動でスキップ';

  @override
  String get sectionMaintenance => 'メンテナンス';

  @override
  String get compactNow => '今すぐログを整理';

  @override
  String get sectionAbout => '情報';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String get aboutVersionLabel => 'バージョン';

  @override
  String get aboutAuthorLabel => '作者';

  @override
  String get aboutRepoLabel => 'リポジトリ';

  @override
  String compactDone(int count, String size) {
    return '整理しました：有効レコード $count 件、$size を節約';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return '現在 有効 $active 件 / $total 行（増幅率 $amp×）';
  }

  @override
  String get backendDisabled => '未設定';

  @override
  String get enable => '有効';

  @override
  String get roleLabel => '役割：';

  @override
  String get repoName => 'リポジトリ名';

  @override
  String get branch => 'ブランチ';

  @override
  String get filePath => 'ファイルパス';

  @override
  String get patHelper => 'OSキーチェーンに保存され、ファイルには書き込まれません';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return 'すべてのバックエンドで取得に失敗：$detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return '$backend から取得しました';
  }

  @override
  String get syncNoPrimary => '利用可能なプライマリバックエンドが未設定です';

  @override
  String syncPrimaryOffline(String detail) {
    return 'プライマリがオフライン：$detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return 'プライマリへの送信に失敗：$detail';
  }

  @override
  String get syncPushConflictManual => '送信が競合し、自動マージに失敗しました。手動で同期してください';

  @override
  String get syncPushedPrimary => 'プライマリに送信しました';

  @override
  String get syncRemoteEmptySkipped => 'リモートが空のため上書きをスキップ（ローカル消失を防止）';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return '$backend でローカルを上書きしました';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return 'プライマリの上書きに失敗：$detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging =>
      '上書き失敗：リモートが変化し続けています。再試行してください';

  @override
  String get syncOverwroteRemoteWithLocal => 'ローカルでリモートを上書きしました';

  @override
  String syncGenericError(String detail) {
    return 'エラー：$detail';
  }

  @override
  String get syncMirrorsLabel => 'ミラー';

  @override
  String get syncMirrorOk => '成功';

  @override
  String get syncMirrorConflict => '競合';

  @override
  String get syncMirrorFailed => '失敗';

  @override
  String syncPrimaryResult(String backend, String outcome) {
    return 'プライマリ $backend（$outcome）';
  }

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return 'リポジトリが見つからないか、トークンにアクセス権がありません：$repo';
  }

  @override
  String get webdavFolderMissing =>
      '対象フォルダが存在しません。先に WebDAV/Nutstore でフォルダを作成し、リモートファイルパスを一致させてください（例：/PassPro/passwords.log）。';

  @override
  String get owner => 'オーナー';

  @override
  String get personalAccessToken => '個人アクセストークン';

  @override
  String get webdavAccount => 'アカウント';

  @override
  String get webdavServer => 'サーバーアドレス';

  @override
  String get webdavRemotePath => 'リモートファイルパス';

  @override
  String get webdavAppPassword => 'アプリパスワード';

  @override
  String get webdavAppPasswordHelper =>
      'Nutstore：サードパーティアプリ管理で生成したアプリパスワードを入力してください';

  @override
  String get rolePrimary => 'プライマリ';

  @override
  String get roleMirror => 'ミラー';

  @override
  String get testOkNoFile => '接続成功（リモートファイルはまだ存在しません。初回プッシュ時に作成されます）';

  @override
  String testOkSha(String sha) {
    return '接続成功（現在の sha=$sha…）';
  }

  @override
  String testFailHttp(String code, String message) {
    return '失敗：HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return '失敗：$error';
  }

  @override
  String get testConnection => '接続をテスト';

  @override
  String get pullTitle => '先にリモートからプルしますか？';

  @override
  String get pullMessage => 'リモートに更新がある可能性があります。続行する前にプルしますか？';

  @override
  String get pull => 'プル';

  @override
  String get skip => 'スキップ';

  @override
  String get pushTitle => 'ローカルに保存しました';

  @override
  String get pushMessage => 'リモートにプッシュしますか？';

  @override
  String get push => 'プッシュ';

  @override
  String get later => '後で';

  @override
  String get dontPromptThisSession => '今回のセッションでは表示しない';

  @override
  String get syncMenu => '同期';

  @override
  String get syncPull => 'プルしてマージ';

  @override
  String get syncPush => '現在のデータをプッシュ';

  @override
  String get syncOverwriteLocal => 'クラウドでローカルを上書き';

  @override
  String get syncOverwriteRemote => 'ローカルでクラウドを上書き';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return 'クラウドの $file でローカルデータを上書きします。プッシュしていないローカルの変更は失われます。続行しますか？';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return 'ローカルデータでクラウドの $file を上書きします。現在のクラウドの内容は置き換えられます。続行しますか？';
  }

  @override
  String get continueLabel => '続行';

  @override
  String get overwroteLocal => 'クラウドでローカルを上書きしました';

  @override
  String get overwroteRemote => 'ローカルでクラウドを上書きしました';

  @override
  String get accountMenu => 'アカウント';

  @override
  String get changeMasterKey => 'マスターキーを変更';

  @override
  String get newMasterKey => '新しいマスターキー';

  @override
  String get confirmNewMasterKey => '新しいマスターキーの確認';

  @override
  String get masterKeyMismatch => '2つのマスターキーが一致しません';

  @override
  String get masterKeyChanged => 'マスターキーを変更しました';

  @override
  String get changeMasterKeyHint =>
      '現在のセッションで使用するマスターキーを切り替えます。以降の暗号化/復号にのみ影響し、既存のエントリは変更されません。';
}
