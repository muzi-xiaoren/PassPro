import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 输入了一把库里不认识的主密钥时问一句：是输错了，还是要用它新开一个密钥空间。
///
/// 老版本这里是无条件放行的——于是输错一个字就悄悄进了一个空空间，之后存的
/// 东西全落在一把记不住的密钥下，而且要等到某天点开某条才发现解不出来。
/// 一个库装多个密钥空间是有意为之的用法，手滑不是，所以这里必须问一句。
Future<bool> confirmCreateKeySpace(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.newKeySpaceTitle),
      content: Text(l10n.newKeySpaceBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.retryKey),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.newKeySpaceCreate),
        ),
      ],
    ),
  );
  return ok ?? false;
}
