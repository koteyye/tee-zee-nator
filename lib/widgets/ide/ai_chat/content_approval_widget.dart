import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/ai_generated_content.dart';
import '../../../services/ai_chat_service.dart';
import '../../../theme/ide_theme.dart';

/// Виджет для одобрения/отклонения сгенерированного контента
class ContentApprovalWidget extends StatelessWidget {
  final AIGeneratedContent content;

  const ContentApprovalWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Показываем кнопки только для pending контента
    if (content.status != AIContentStatus.pending) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IDETheme.pendingColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: IDETheme.pendingColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                size: 16,
                color: IDETheme.pendingColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.generatedContentAwaitingApproval,
                  style: IDETheme.bodySmallStyle.copyWith(
                    color: IDETheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleApply(context),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.apply),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IDETheme.savedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleReject(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.cancel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IDETheme.errorColor,
                    side: BorderSide(color: IDETheme.errorColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Обработать применение контента
  Future<void> _handleApply(BuildContext context) async {
    final chatService = context.read<AIChatService>();

    try {
      await chatService.acceptGeneratedContent(content);

      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.contentAppliedSuccessfully),
            backgroundColor: IDETheme.savedColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorApplyingContent(e.toString())),
            backgroundColor: IDETheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Обработать отклонение контента
  void _handleReject(BuildContext context) {
    final chatService = context.read<AIChatService>();

    chatService.rejectGeneratedContent(content);

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.contentRejected),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
