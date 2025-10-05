import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../../../theme/ide_theme.dart';

/// Виджет сообщения в чате
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 32 : 0,
        right: isUser ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Метка отправителя
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
            child: Text(
              isUser ? 'Вы' : 'AI Ассистент',
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Сообщение
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? IDETheme.selectedColor
                  : IDETheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUser
                    ? IDETheme.primaryColorLight
                    : IDETheme.borderColor,
                width: isUser ? 2 : 1,
              ),
            ),
            child: SelectableText(
              message.content,
              style: IDETheme.bodyLargeStyle.copyWith(
                color: IDETheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          // Временная метка
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
            child: Text(
              _formatTimestamp(message.timestamp),
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Форматировать временную метку
  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ч назад';
    } else {
      return '${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
