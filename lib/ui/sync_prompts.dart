import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

enum PromptChoice { confirm, skip, skipSession, cancel }

/// 操作前提示拉取。返回用户选择，且会把"会话内不再提示"写回 [AppState.sessionSkip]。
Future<PromptChoice> showPullPrompt(BuildContext context) async {
  return _showPrompt(
    context,
    title: '建议先拉取远端',
    message: '远端可能有更新，是否在继续之前先拉取？',
    confirmLabel: '拉取',
    skipLabel: '跳过',
    isBefore: true,
  );
}

/// 操作后提示推送。
Future<PromptChoice> showPushPrompt(BuildContext context) async {
  return _showPrompt(
    context,
    title: '本地已保存',
    message: '是否推送到远端？',
    confirmLabel: '推送',
    skipLabel: '稍后',
    isBefore: false,
  );
}

Future<PromptChoice> _showPrompt(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String skipLabel,
  required bool isBefore,
}) async {
  bool skipSession = false;
  final result = await showDialog<PromptChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: skipSession,
              onChanged: (v) => setState(() => skipSession = v ?? false),
              title: const Text('本次会话内不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(PromptChoice.skip),
            child: Text(skipLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(
              skipSession ? PromptChoice.skipSession : PromptChoice.confirm,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  // 用户点了"会话内不再提示" → 标记并视为 confirm
  if (result == PromptChoice.skipSession) {
    final state = context.read<AppState>();
    if (isBefore) {
      state.sessionSkip.skipBefore = true;
    } else {
      state.sessionSkip.skipAfter = true;
    }
    return PromptChoice.confirm;
  }

  return result ?? PromptChoice.cancel;
}
