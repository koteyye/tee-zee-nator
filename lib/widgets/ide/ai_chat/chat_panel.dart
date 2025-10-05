import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/ai_chat_service.dart';
import '../../../theme/ide_theme.dart';
import 'chat_mode_selector.dart';
import 'chat_message_widget.dart';
import 'chat_input.dart';

/// Плавающая панель AI-чата
class ChatPanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final double? width;

  const ChatPanel({
    super.key,
    required this.isVisible,
    required this.onClose,
    this.width,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: IDETheme.mediumDuration,
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Получить адаптивную ширину в зависимости от размера экрана
  double _getAdaptiveWidth(double screenWidth) {
    if (screenWidth < 1280) {
      return IDETheme.aiChatPanelMinWidth; // 320px на малых экранах
    } else if (screenWidth < 1600) {
      return IDETheme.aiChatPanelWidth; // 380px на средних
    } else {
      return 450; // 450px на больших экранах
    }
  }

  /// Получить адаптивную высоту в зависимости от размера экрана
  double _getAdaptiveHeight(double screenWidth) {
    if (screenWidth < 1280) {
      return 500; // Уменьшенная высота на малых экранах
    } else {
      return IDETheme.aiChatPanelHeight; // 600px на средних и больших
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final adaptiveWidth = widget.width ?? _getAdaptiveWidth(screenWidth);
    final adaptiveHeight = _getAdaptiveHeight(screenWidth);

    return Positioned(
      right: 16,
      bottom: 80,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: adaptiveWidth,
            height: _isMinimized ? 56 : adaptiveHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                if (!_isMinimized) ...[
                  const ChatModeSelector(),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: IDETheme.borderColor,
                  ),
                  Expanded(child: _buildMessageList()),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: IDETheme.borderColor,
                  ),
                  const ChatInput(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Построить header панели
  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: IDETheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: IDETheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy,
            size: 24,
            color: IDETheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI Ассистент',
              style: IDETheme.titleStyle,
            ),
          ),
          // Кнопка минимизации
          IconButton(
            icon: Icon(
              _isMinimized ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            tooltip: _isMinimized ? 'Развернуть' : 'Свернуть',
            onPressed: () {
              setState(() {
                _isMinimized = !_isMinimized;
              });
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
          const SizedBox(width: 8),
          // Кнопка закрытия
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Закрыть',
            onPressed: widget.onClose,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  /// Построить список сообщений
  Widget _buildMessageList() {
    return Consumer<AIChatService>(
      builder: (context, chatService, child) {
        final session = chatService.currentSession;

        if (session == null) {
          return _buildEmptyState();
        }

        if (session.messages.isEmpty) {
          return _buildWelcomeState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: session.messages.length,
          itemBuilder: (context, index) {
            final message = session.messages[index];
            return ChatMessageWidget(message: message);
          },
        );
      },
    );
  }

  /// Пустое состояние
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет активной сессии',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Выберите режим и начните общение',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Приветственное состояние
  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.waving_hand,
              size: 64,
              color: IDETheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Привет! Чем могу помочь?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Задайте вопрос или опишите задачу',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
