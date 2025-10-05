import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_session.dart';
import '../../../services/ai_chat_service.dart';
import '../../../theme/ide_theme.dart';

/// Виджет выбора режима AI-чата
class ChatModeSelector extends StatelessWidget {
  const ChatModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<AIChatService>(
      builder: (context, chatService, child) {
        final session = chatService.currentSession;
        final currentMode = session?.mode;

        return Container(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildModeChip(
                context: context,
                label: l10n.aiChatModeNew,
                mode: ChatMode.newSpecification,
                currentMode: currentMode,
                onSelected: () => _selectMode(context, ChatMode.newSpecification),
              ),
              _buildModeChip(
                context: context,
                label: l10n.aiChatModeAmendments,
                mode: ChatMode.amendments,
                currentMode: currentMode,
                onSelected: () => _selectMode(context, ChatMode.amendments),
              ),
              _buildModeChip(
                context: context,
                label: l10n.aiChatModeAnalysis,
                mode: ChatMode.analysis,
                currentMode: currentMode,
                onSelected: () => _selectMode(context, ChatMode.analysis),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Построить chip режима
  Widget _buildModeChip({
    required BuildContext context,
    required String label,
    required ChatMode mode,
    required ChatMode? currentMode,
    required VoidCallback onSelected,
  }) {
    final isSelected = mode == currentMode;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: IDETheme.primaryColorLight,
      backgroundColor: IDETheme.surfaceColor,
      labelStyle: IDETheme.bodyMediumStyle.copyWith(
        color: isSelected ? Colors.white : IDETheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? IDETheme.primaryColor : IDETheme.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  /// Выбрать режим
  Future<void> _selectMode(BuildContext context, ChatMode mode) async {
    final chatService = context.read<AIChatService>();

    // Если уже есть активная сессия с другим режимом, создаем новую
    if (chatService.currentSession != null &&
        chatService.currentSession!.mode != mode) {
      await chatService.startSession(mode);
    } else if (chatService.currentSession == null) {
      // Если сессии нет, создаем новую
      await chatService.startSession(mode);
    }
  }
}
