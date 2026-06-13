// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get enterMasterKey => '请输入主密钥';

  @override
  String get masterKeyLabel => '主密钥';

  @override
  String get unlock => '解锁';

  @override
  String get masterKeyHint => '主密钥不会被保存，每次启动需要重新输入。\n留空将以单空格作为主密钥（与旧版兼容）。';

  @override
  String get settings => '设置';

  @override
  String get lock => '锁定';

  @override
  String get tabQuery => '查询';

  @override
  String get tabAdd => '新增';

  @override
  String get tabList => '列表';

  @override
  String get syncIdle => '未同步';

  @override
  String get syncWorking => '同步中…';

  @override
  String get syncOk => '已同步';

  @override
  String get syncOffline => '离线';

  @override
  String get syncError => '同步失败';

  @override
  String get queryFieldLabel => '网址（支持关键词部分匹配）';

  @override
  String get queryInvalidKey => '主密钥错误：找到匹配网址但无法解密';

  @override
  String get queryNoMatch => '没有找到匹配的记录';

  @override
  String get queryPrompt => '输入网址，回车开始查询';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get copyUsername => '复制用户名';

  @override
  String get hide => '隐藏';

  @override
  String get show => '显示';

  @override
  String get copyPassword => '复制密码';

  @override
  String get usernameCopied => '用户名已复制';

  @override
  String get passwordCopied => '密码已复制';

  @override
  String get confirmDelete => '确认删除';

  @override
  String deleteBody(String website) {
    return '删除 $website 的这条记录？';
  }

  @override
  String get cancel => '取消';

  @override
  String get deleted => '已删除';

  @override
  String get generatePassword => '生成密码';

  @override
  String get length => '长度';

  @override
  String get generate => '生成';

  @override
  String get charUpper => '大写';

  @override
  String get charLower => '小写';

  @override
  String get charDigits => '数字';

  @override
  String get charSpecial => '特殊';

  @override
  String get saveToVault => '保存到密码库';

  @override
  String get websiteRequired => '网址 *';

  @override
  String get usernameOptional => '用户名（可选）';

  @override
  String get passwordRequired => '密码 *';

  @override
  String get save => '保存';

  @override
  String get websitePasswordEmpty => '网址和密码不能为空';

  @override
  String get saved => '已保存';

  @override
  String get duplicateEntry => '已存在相同条目';

  @override
  String get emptyVault => '密码库为空，去“新增”添加第一条吧';

  @override
  String totalCount(int count) {
    return '共 $count 条';
  }

  @override
  String get sortNameAsc => '名称 A→Z';

  @override
  String get sortNameDesc => '名称 Z→A';

  @override
  String get sortTimeDesc => '加入时间（新→旧）';

  @override
  String get sortTimeAsc => '加入时间（旧→新）';

  @override
  String get sortTooltip => '排序';

  @override
  String get decryptFailedCopy => '无法用当前主密钥解密，复制失败';

  @override
  String get noUsername => '（无用户名）';

  @override
  String get cannotDecrypt => '无法解密';

  @override
  String get cannotDecryptBody => '该记录无法用当前主密钥解密。\n请点击左上角返回，重新输入正确的主密钥。';

  @override
  String get website => '网址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get updated => '已更新';

  @override
  String get sectionLanguage => '语言';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get sectionCloudSync => '云同步';

  @override
  String get enableCloudSync => '启用云同步';

  @override
  String get enableCloudSyncSub => '关闭后所有数据仅保留在本机';

  @override
  String get sectionSyncPrompt => '同步提示';

  @override
  String get promptBeforePull => '操作前提示拉取';

  @override
  String get promptBeforePullSub => '新增/修改/删除前先弹出“拉取远端”提示';

  @override
  String get promptAfterPush => '操作后提示推送';

  @override
  String get smartSkip => '智能跳过';

  @override
  String get smartSkipSub => '远端无更新时自动跳过“拉取”提示';

  @override
  String get sectionMaintenance => '维护';

  @override
  String get compactNow => '立即整理日志';

  @override
  String get sectionAbout => '关于';

  @override
  String get aboutSubtitle =>
      'GitHub: muzi-xiaoren · https://github.com/muzi-xiaoren/PassPro';

  @override
  String get aboutVersionLabel => '版本';

  @override
  String get aboutAuthorLabel => '作者';

  @override
  String get aboutRepoLabel => '仓库';

  @override
  String compactDone(int count, String size) {
    return '已整理：$count 条有效记录，节省 $size';
  }

  @override
  String compactionStatus(int active, int total, String amp) {
    return '当前 $active 条有效 / $total 行（放大率 $amp×）';
  }

  @override
  String get backendDisabled => '未启用';

  @override
  String get enable => '启用';

  @override
  String get roleLabel => '角色：';

  @override
  String get repoName => '仓库名';

  @override
  String get branch => '分支';

  @override
  String get filePath => '文件路径';

  @override
  String get patHelper => '存进 OS Keychain，不会写入任何文件';

  @override
  String syncAllBackendsPullFailed(String detail) {
    return '所有后端都拉取失败：$detail';
  }

  @override
  String syncPulledFrom(String backend) {
    return '已从 $backend 拉取';
  }

  @override
  String get syncNoPrimary => '未配置可用的主仓库(Primary)';

  @override
  String syncPrimaryOffline(String detail) {
    return '主仓库离线：$detail';
  }

  @override
  String syncPrimaryPushFailed(String detail) {
    return '主仓库推送失败：$detail';
  }

  @override
  String get syncPushConflictManual => '推送冲突且自动合并失败，请手动同步';

  @override
  String get syncPushedPrimary => '已推送到主仓库';

  @override
  String get syncRemoteEmptySkipped => '远端为空，已跳过覆盖（避免误清空本地）';

  @override
  String syncOverwroteLocalFrom(String backend) {
    return '已用 $backend 覆盖本地';
  }

  @override
  String syncPrimaryOverwriteFailed(String detail) {
    return '主仓库覆盖失败：$detail';
  }

  @override
  String get syncOverwriteRemoteStillChanging => '覆盖失败：远端持续变化，请重试';

  @override
  String get syncOverwroteRemoteWithLocal => '已用本地覆盖云端';

  @override
  String syncGenericError(String detail) {
    return '出错：$detail';
  }

  @override
  String get syncMirrorsLabel => '副仓库';

  @override
  String get syncMirrorOk => '成功';

  @override
  String get syncMirrorConflict => '冲突';

  @override
  String get syncMirrorFailed => '失败';

  @override
  String syncPrimaryResult(String backend, String outcome) {
    return '主仓库 $backend（$outcome）';
  }

  @override
  String repoNotFoundOrNoAccess(String repo) {
    return '仓库不存在或令牌无权访问：$repo';
  }

  @override
  String get webdavFolderMissing =>
      '目标文件夹不存在：请先在坚果云/WebDAV 里创建该文件夹，并让“远程文件路径”与之对应（例如 /PassPro/passwords.log）。';

  @override
  String get owner => '拥有者';

  @override
  String get personalAccessToken => '个人访问令牌';

  @override
  String get webdavAccount => '账户信息';

  @override
  String get webdavServer => '服务器地址';

  @override
  String get webdavRemotePath => '远程文件路径';

  @override
  String get webdavAppPassword => '应用密码';

  @override
  String get webdavAppPasswordHelper => '坚果云请填写“第三方应用管理”生成的应用密码';

  @override
  String get rolePrimary => '主仓库';

  @override
  String get roleMirror => '副仓库';

  @override
  String get testOkNoFile => '连接成功（远端文件还不存在，首次推送会创建）';

  @override
  String testOkSha(String sha) {
    return '连接成功（当前 sha=$sha…）';
  }

  @override
  String testFailHttp(String code, String message) {
    return '失败：HTTP $code $message';
  }

  @override
  String testFail(String error) {
    return '失败：$error';
  }

  @override
  String get testConnection => '测试连接';

  @override
  String get pullTitle => '建议先拉取远端';

  @override
  String get pullMessage => '远端可能有更新，是否在继续之前先拉取？';

  @override
  String get pull => '拉取';

  @override
  String get skip => '跳过';

  @override
  String get pushTitle => '本地已保存';

  @override
  String get pushMessage => '是否推送到远端？';

  @override
  String get push => '推送';

  @override
  String get later => '稍后';

  @override
  String get dontPromptThisSession => '本次会话内不再提示';

  @override
  String get syncMenu => '同步';

  @override
  String get syncPull => '拉取并合并';

  @override
  String get syncPush => '推送当前数据';

  @override
  String get syncOverwriteLocal => '用云端覆盖本地';

  @override
  String get syncOverwriteRemote => '用本地覆盖云端';

  @override
  String syncOverwriteLocalConfirm(String file) {
    return '这会用云端的 $file 覆盖本地数据，本地未推送的修改会丢失。是否继续？';
  }

  @override
  String syncOverwriteRemoteConfirm(String file) {
    return '这会用本地数据覆盖云端的 $file，云端当前内容会被覆盖。是否继续？';
  }

  @override
  String get continueLabel => '继续';

  @override
  String get overwroteLocal => '已用云端覆盖本地';

  @override
  String get overwroteRemote => '已用本地覆盖云端';

  @override
  String get accountMenu => '账户';

  @override
  String get changeMasterKey => '更换主密钥';

  @override
  String get newMasterKey => '新主密钥';

  @override
  String get confirmNewMasterKey => '确认新主密钥';

  @override
  String get masterKeyMismatch => '两次输入的主密钥不一致';

  @override
  String get masterKeyChanged => '主密钥已更换';

  @override
  String get changeMasterKeyHint => '热更换当前会话使用的主密钥，仅影响之后的加密/解密，不会改动已有条目。';
}
