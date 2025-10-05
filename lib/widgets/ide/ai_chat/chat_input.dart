import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/ai_chat_service.dart';
import '../../../theme/ide_theme.dart';

/// Виджет ввода сообщения в чат
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: 'Введите сообщение...',
                hintStyle: IDETheme.bodyMediumStyle.copyWith(
                  color: IDETheme.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: IDETheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: IDETheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: IDETheme.primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: IDETheme.bodyMediumStyle,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          // Кнопка отправки или индикатор загрузки
          _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: IDETheme.primaryColor,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.send,
                    color: _controller.text.trim().isEmpty
                        ? IDETheme.textSecondary
                        : IDETheme.primaryColor,
                  ),
                  onPressed: _controller.text.trim().isEmpty ? null : _handleSend,
                  tooltip: 'Отправить',
                ),
        ],
      ),
    );
  }

  /// Обработать отправку сообщения
  Future<void> _handleSend() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isLoading) return;

    final chatService = context.read<AIChatService>();

    // Проверяем наличие сессии
    if (chatService.currentSession == null) {
      _showError('Сначала выберите режим чата');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Очищаем поле ввода сразу
    _controller.clear();

    try {
      // Отправляем сообщение в стриме
      await for (final _ in chatService.sendMessageStream(message)) {
        // Обрабатываем стрим ответов
        // Можно добавить обработку промежуточных состояний
      }
    } catch (e) {
      _showError('Ошибка отправки: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Показать ошибку
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: IDETheme.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
