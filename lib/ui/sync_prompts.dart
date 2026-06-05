import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/app_localizations.dart';

enum PromptChoice { confirm, skip, skipSession, cancel }

/// 操作前提示拉取。返回用户选择，且会把"会话内不再提示"写回 [AppState.sessionSkip]。
Future<PromptChoice> showPullPrompt(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return _showPrompt(
    context,
    title: l10n.pullTitle,
    message: l10n.pullMessage,
    confirmLabel: l10n.pull,
    skipLabel: l10n.skip,
    isBefore: true,
  );
}

/// 操作后提示推送。
Future<PromptChoice> showPushPrompt(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  return _showPrompt(
    context,
    title: l10n.pushTitle,
    message: l10n.pushMessage,
    confirmLabel: l10n.push,
    skipLabel: l10n.later,
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
              title: Text(AppLocalizations.of(ctx)!.dontPromptThisSession),
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
