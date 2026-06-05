import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BackendKind { github, gitee }

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
      filePath: j['filePath'] as String? ?? 'passwords.log',
    );
  }

  static String defaultBranchFor(BackendKind kind) =>
      kind == BackendKind.gitee ? 'master' : 'main';
}

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _kCloudEnabled = 'cloud_enabled';
  static const _kPromptBeforeEdit = 'prompt_before_edit';
  static const _kPromptAfterEdit = 'prompt_after_edit';
  static const _kSmartSkip = 'smart_skip';
  static const _kBackendGithub = 'backend_github_json';
  static const _kBackendGitee = 'backend_gitee_json';
  static const _kLocale = 'locale_code';

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

  BackendConfig get github => _loadBackend(_kBackendGithub, BackendKind.github);
  BackendConfig get gitee => _loadBackend(_kBackendGitee, BackendKind.gitee);

  BackendConfig _loadBackend(String key, BackendKind kind) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return BackendConfig(
        kind: kind,
        role: kind == BackendKind.github
            ? BackendRole.primary
            : BackendRole.mirror,
        branch: BackendConfig.defaultBranchFor(kind),
      );
    }
    try {
      return BackendConfig.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return BackendConfig(kind: kind);
    }
  }

  /// 返回当前 primary 后端（若启用），否则 null。
  BackendConfig? get primaryBackend {
    if (!cloudEnabled) return null;
    if (github.enabled && github.role == BackendRole.primary) return github;
    if (gitee.enabled && gitee.role == BackendRole.primary) return gitee;
    return null;
  }

  /// 返回所有启用的 mirror 后端。
  List<BackendConfig> get mirrorBackends {
    if (!cloudEnabled) return const [];
    final out = <BackendConfig>[];
    if (github.enabled && github.role == BackendRole.mirror) out.add(github);
    if (gitee.enabled && gitee.role == BackendRole.mirror) out.add(gitee);
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
    final key = config.kind == BackendKind.github
        ? _kBackendGithub
        : _kBackendGitee;
    await _prefs.setString(key, jsonEncode(config.toJson()));
    notifyListeners();
  }
}
