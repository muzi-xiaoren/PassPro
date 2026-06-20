/// 搜索模式（用户在设置里选）。
/// - exact   精确：按 `.`(及 `/`、`://`) 拆词求交；存在与查询完全相同的网址时只显示它们。
/// - contains 包含：同样拆词求交，但显示全部相关条目，按匹配度排序。
/// - fuzzy   模糊：网址只要包含查询整串即显示。
/// - custom  自定义：用自定义分隔符拆分后，按所选子策略匹配（默认模糊）。
enum SearchMode { exact, contains, fuzzy, custom }

/// 底层匹配策略。exact/contains 按分隔符取词集求交；fuzzy 子串匹配。
enum SearchStrategy { exact, contains, fuzzy }

/// 一次搜索的配置。
class SearchConfig {
  final SearchMode mode;

  /// 仅 [SearchMode.custom] 使用的分隔符。
  final String customDelimiter;

  /// 仅 [SearchMode.custom] 使用的子策略，默认模糊。
  final SearchStrategy customStrategy;

  const SearchConfig({
    this.mode = SearchMode.exact,
    this.customDelimiter = '.',
    this.customStrategy = SearchStrategy.fuzzy,
  });

  /// 归一化后的实际匹配策略。
  SearchStrategy get strategy => switch (mode) {
        SearchMode.exact => SearchStrategy.exact,
        SearchMode.contains => SearchStrategy.contains,
        SearchMode.fuzzy => SearchStrategy.fuzzy,
        SearchMode.custom => customStrategy,
      };

  /// 拆分网址/查询用的分隔符；`null` 表示用内置标准分割(`.` `/` `://`)。
  /// 仅 custom 模式用自定义分隔符；fuzzy/exact/contains 标准模式都返回 null。
  String? get delimiter => mode == SearchMode.custom && customDelimiter.isNotEmpty
      ? customDelimiter
      : null;
}
