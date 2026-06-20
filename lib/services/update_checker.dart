import 'dart:convert';

import 'package:http/http.dart' as http;

/// 一次更新检查的结果。
class UpdateInfo {
  /// 远端最新版本号（已去掉前缀 v，如 "1.0.3"）。
  final String latestVersion;

  /// Release 页面地址，供"前往下载"跳转。
  final String htmlUrl;

  /// 远端是否比当前版本更新。
  final bool hasUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.htmlUrl,
    required this.hasUpdate,
  });
}

/// 通过 GitHub Releases API 检查是否有新版本。
class UpdateChecker {
  static const String _api =
      'https://api.github.com/repos/muzi-xiaoren/PassPro/releases/latest';
  static const String releasesPage =
      'https://github.com/muzi-xiaoren/PassPro/releases/latest';

  /// 查询最新 Release 并与 [currentVersion]（如 "1.0.2"）比较。
  /// 网络/解析失败会抛异常，由调用方处理。
  static Future<UpdateInfo> check(String currentVersion) async {
    final resp = await http.get(
      Uri.parse(_api),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'PassPro-app',
      },
    ).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final latest = _stripV((json['tag_name'] as String?) ?? '');
    final url = (json['html_url'] as String?) ?? releasesPage;
    return UpdateInfo(
      latestVersion: latest.isEmpty ? currentVersion : latest,
      htmlUrl: url,
      hasUpdate: latest.isNotEmpty && _isNewer(latest, currentVersion),
    );
  }

  static String _stripV(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    return t;
  }

  /// a 是否比 b 新（按点分数字逐段比较，忽略非数字后缀）。
  static bool _isNewer(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String v) {
    if (v.isEmpty) return const [0];
    return v.split('.').map((s) {
      final m = RegExp(r'\d+').firstMatch(s);
      return m == null ? 0 : int.parse(m.group(0)!);
    }).toList();
  }
}
