import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/search_config.dart';

enum BackendKind { github, gitee, webdav }

enum BackendRole { primary, mirror }

class BackendConfig {
  final BackendKind kind;
  final bool enabled;
  final BackendRole role;
  final String owner;
  final String repo;
  final String branch;
  final String filePath;

  const BackendConfig({
    required this.kind,
    this.enabled = false,
    this.role = BackendRole.primary,
    this.owner = '',
    this.repo = '',
    this.branch = 'main',
    this.filePath = 'passwords.log',
  });

  BackendConfig copyWith({
    bool? enabled,
    BackendRole? role,
    String? owner,
    String? repo,
    String? branch,
    String? filePath,
  }) {
    return BackendConfig(
      kind: kind,
      enabled: enabled ?? this.enabled,
      role: role ?? this.role,
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      branch: branch ?? this.branch,
      filePath: filePath ?? this.filePath,
    );
  }

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'enabled': enabled,
        'role': role.name,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'filePath': filePath,
      };

  static BackendConfig fromJson(Map<String, Object?> j) {
    final kind = BackendKind.values.firstWhere((e) => e.name == j['kind']);
    return BackendConfig(
      kind: kind,
      enabled: j['enabled'] as bool? ?? false,
      role: BackendRole.values
          .firstWhere((e) => e.name == (j['role'] ?? 'primary')),
      owner: j['owner'] as String? ?? '',
      repo: j['repo'] as String? ?? '',
      branch: j['branch'] as String? ?? defaultBranchFor(kind),
      filePath: j['filePath'] as String? ?? defaultFilePathFor(kind),
    );
  }

  static String defaultBranchFor(BackendKind kind) => switch (kind) {
        BackendKind.gitee => 'master',
        BackendKind.webdav => '',
        BackendKind.github => 'main',
      };

  static String defaultFilePathFor(BackendKind kind) =>
      kind == BackendKind.webdav ? '/PassPro/passwords.log' : 'passwords.log';

  static String defaultRepoFor(BackendKind kind) =>
      kind == BackendKind.webdav ? 'https://dav.jianguoyun.com/dav/' : '';
}

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _kCloudEnabled = 'cloud_enabled';
  static const _kPromptBeforeEdit = 'prompt_before_edit';
  static const _kPromptAfterEdit = 'prompt_after_edit';
  static const _kSmartSkip = 'smart_skip';
  static const _kBackendGithub = 'backend_github_json';
  static const _kBackendGitee = 'backend_gitee_json';
  static const _kBackendWebDav = 'backend_webdav_json';
  static const _kLocale = 'locale_code';
  static const _kListSort = 'list_sort';
  static const _kMasterKeyVisible = 'master_key_visible';
  static const _kWindowFrame = 'window_frame';
  static const _kSearchMode = 'search_mode';
  static const _kSearchCustomDelimiter = 'search_custom_delimiter';
  static const _kSearchCustomStrategy = 'search_custom_strategy';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  bool get cloudEnabled => _prefs.getBool(_kCloudEnabled) ?? false;
  bool get promptBeforeEdit => _prefs.getBool(_kPromptBeforeEdit) ?? true;
  bool get promptAfterEdit => _prefs.getBool(_kPromptAfterEdit) ?? true;
  bool get smartSkip => _prefs.getBool(_kSmartSkip) ?? true;

  /// 界面语言代码：'' 表示跟随系统，否则如 'en' / 'zh' / 'ja' / 'ko' / 'fr' / 'ru' / 'de'。
  String get localeCode => _prefs.getString(_kLocale) ?? '';

  /// 供 MaterialApp.locale 使用；null = 跟随系统。
  Locale? get locale => localeCode.isEmpty ? null : Locale(localeCode);

  /// 列表排序方式（持久化，按 _ListSort.name 存储）。默认按名称升序。
  String get listSort => _prefs.getString(_kListSort) ?? 'nameAsc';

  /// 主密钥输入框是否默认明文可见（持久化）。默认 false（隐藏）。
  /// 解锁页与“更换密钥”弹窗共用此偏好。
  bool get masterKeyVisible => _prefs.getBool(_kMasterKeyVisible) ?? false;

  /// 搜索模式（持久化）。默认精确匹配（与旧行为一致）。
  SearchMode get searchMode => SearchMode.values.firstWhere(
        (e) => e.name == _prefs.getString(_kSearchMode),
        orElse: () => SearchMode.exact,
      );

  /// 自定义模式的分隔符（持久化），默认 `.`。
  String get searchCustomDelimiter =>
      _prefs.getString(_kSearchCustomDelimiter) ?? '.';

  /// 自定义模式的子策略（持久化），默认模糊。
  SearchStrategy get searchCustomStrategy => SearchStrategy.values.firstWhere(
        (e) => e.name == _prefs.getString(_kSearchCustomStrategy),
        orElse: () => SearchStrategy.fuzzy,
      );

  /// 当前生效的搜索配置，供查询界面使用。
  SearchConfig get searchConfig => SearchConfig(
        mode: searchMode,
        customDelimiter: searchCustomDelimiter,
        customStrategy: searchCustomStrategy,
      );

  /// 上次关闭时的桌面窗口位置/大小：[left, top, width, height]。
  /// 无记录（首次启动）返回 null —— 此时由调用方居中并用默认尺寸。
  List<double>? get windowFrame {
    final raw = _prefs.getString(_kWindowFrame);
    if (raw == null) return null;
    try {
      final l = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
      return l.length == 4 ? l : null;
    } catch (_) {
      return null;
    }
  }

  /// 持久化桌面窗口位置/大小。不触发 UI 重建（窗口几何与 widget 树无关）。
  Future<void> setWindowFrame(double left, double top, double width, double height) async {
    await _prefs.setString(_kWindowFrame, jsonEncode([left, top, width, height]));
  }

  BackendConfig get github => _loadBackend(_kBackendGithub, BackendKind.github);
  BackendConfig get gitee => _loadBackend(_kBackendGitee, BackendKind.gitee);
  BackendConfig get webdav => _loadBackend(_kBackendWebDav, BackendKind.webdav);

  BackendConfig _loadBackend(String key, BackendKind kind) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return BackendConfig(
        kind: kind,
        role: kind == BackendKind.github ? BackendRole.primary : BackendRole.mirror,
        branch: BackendConfig.defaultBranchFor(kind),
        repo: BackendConfig.defaultRepoFor(kind),
        filePath: BackendConfig.defaultFilePathFor(kind),
      );
    }
    try {
      return BackendConfig.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return BackendConfig(
        kind: kind,
        branch: BackendConfig.defaultBranchFor(kind),
        repo: BackendConfig.defaultRepoFor(kind),
        filePath: BackendConfig.defaultFilePathFor(kind),
      );
    }
  }

  /// 返回当前 primary 后端（若启用），否则 null。
  BackendConfig? get primaryBackend {
    if (!cloudEnabled) return null;
    if (github.enabled && github.role == BackendRole.primary) return github;
    if (gitee.enabled && gitee.role == BackendRole.primary) return gitee;
    if (webdav.enabled && webdav.role == BackendRole.primary) return webdav;
    return null;
  }

  /// 返回所有启用的 mirror 后端。
  List<BackendConfig> get mirrorBackends {
    if (!cloudEnabled) return const [];
    final out = <BackendConfig>[];
    if (github.enabled && github.role == BackendRole.mirror) out.add(github);
    if (gitee.enabled && gitee.role == BackendRole.mirror) out.add(gitee);
    if (webdav.enabled && webdav.role == BackendRole.mirror) out.add(webdav);
    return out;
  }

  Future<void> setCloudEnabled(bool v) async {
    await _prefs.setBool(_kCloudEnabled, v);
    notifyListeners();
  }

  Future<void> setPromptBeforeEdit(bool v) async {
    await _prefs.setBool(_kPromptBeforeEdit, v);
    notifyListeners();
  }

  Future<void> setPromptAfterEdit(bool v) async {
    await _prefs.setBool(_kPromptAfterEdit, v);
    notifyListeners();
  }

  Future<void> setSmartSkip(bool v) async {
    await _prefs.setBool(_kSmartSkip, v);
    notifyListeners();
  }

  /// 持久化列表排序方式（_ListSort.name）。
  Future<void> setListSort(String name) async {
    await _prefs.setString(_kListSort, name);
    notifyListeners();
  }

  /// 持久化“主密钥是否默认可见”。仅在解锁/换钥页打开时按需读取，
  /// 无需触发全局重建，故不调用 notifyListeners。
  Future<void> setMasterKeyVisible(bool v) async {
    await _prefs.setBool(_kMasterKeyVisible, v);
  }

  Future<void> setSearchMode(SearchMode mode) async {
    await _prefs.setString(_kSearchMode, mode.name);
    notifyListeners();
  }

  Future<void> setSearchCustomDelimiter(String delimiter) async {
    await _prefs.setString(_kSearchCustomDelimiter, delimiter);
    notifyListeners();
  }

  Future<void> setSearchCustomStrategy(SearchStrategy strategy) async {
    await _prefs.setString(_kSearchCustomStrategy, strategy.name);
    notifyListeners();
  }

  /// 设置界面语言；传空字符串表示跟随系统。
  Future<void> setLocale(String code) async {
    if (code.isEmpty) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
    notifyListeners();
  }

  Future<void> updateBackend(BackendConfig config) async {
    final key = switch (config.kind) {
      BackendKind.github => _kBackendGithub,
      BackendKind.gitee => _kBackendGitee,
      BackendKind.webdav => _kBackendWebDav,
    };
    await _prefs.setString(key, jsonEncode(config.toJson()));
    notifyListeners();
  }
}
