import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'enhanced_tooltip.dart';
import 'accessibility_wrapper.dart';

/// Widget that provides contextual user guidance and tips
/// 
/// Provides:
/// - Contextual help messages
/// - Feature discovery
/// - Onboarding tips
/// - Progressive disclosure
class UserGuidanceWidget extends StatefulWidget {
  final String title;
  final String message;
  final List<GuidanceStep>? steps;
  final IconData? icon;
  final Color? backgroundColor;
  final bool dismissible;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const UserGuidanceWidget({
    super.key,
    required this.title,
    required this.message,
    this.steps,
    this.icon,
    this.backgroundColor,
    this.dismissible = true,
    this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  State<UserGuidanceWidget> createState() => _UserGuidanceWidgetState();
}

class _UserGuidanceWidgetState extends State<UserGuidanceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.backgroundColor?.withOpacity(0.3) ?? Colors.blue.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AccessibilityWrapper(
                label: 'User guidance: ${widget.title}',
                hint: widget.message,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: AppTheme.primaryRed,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.steps != null && widget.steps!.isNotEmpty) ...[
                            EnhancedTooltip(
                              message: _isExpanded ? 'Hide detailed steps' : 'Show detailed steps',
                              child: IconButton(
                                icon: Icon(
                                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: AppTheme.primaryRed,
                                ),
                                onPressed: _toggleExpanded,
                              ),
                            ),
                          ],
                          if (widget.dismissible) ...[
                            EnhancedTooltip(
                              message: 'Dismiss this guidance',
                              child: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                onPressed: _dismiss,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Expandable steps
                    if (widget.steps != null && widget.steps!.isNotEmpty)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: _isExpanded ? null : 0,
                        child: _isExpanded
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    ...widget.steps!.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final step = entry.value;
                                      return _buildStep(index + 1, step);
                                    }),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    
                    // Action button
                    if (widget.onAction != null && widget.actionLabel != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryRed,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(int stepNumber, GuidanceStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: step.isCompleted ? Colors.green : AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: step.isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      stepNumber.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: step.isCompleted ? Colors.green.shade700 : AppTheme.darkGray,
                    decoration: step.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (step.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Represents a single step in user guidance
class GuidanceStep {
  final String title;
  final String? description;
  final bool isCompleted;
  final VoidCallback? onTap;

  const GuidanceStep({
    required this.title,
    this.description,
    this.isCompleted = false,
    this.onTap,
  });
}

/// Specialized guidance widget for Confluence features
class ConfluenceGuidanceWidget extends StatelessWidget {
  final bool isConfluenceEnabled;
  final bool hasValidConnection;

  const ConfluenceGuidanceWidget({
    super.key,
    required this.isConfluenceEnabled,
    required this.hasValidConnection,
  });

  @override
  Widget build(BuildContext context) {
    if (isConfluenceEnabled && hasValidConnection) {
      return UserGuidanceWidget(
        title: 'Интеграция с Confluence активна',
        message: 'Теперь можно добавлять ссылки Confluence в требования!',
        icon: Icons.check_circle,
        backgroundColor: Colors.green.shade50,
        steps: const [
          GuidanceStep(
            title: 'Вставляйте ссылки на страницы Confluence прямо в требования',
            description: 'Система автоматически получит и обработает содержимое',
            isCompleted: true,
          ),
          GuidanceStep(
            title: 'Генерируйте спецификации с учетом контента из Confluence',
            description: 'Спецификация включит релевантную информацию со связанных страниц',
          ),
          GuidanceStep(
            title: 'Публикуйте обратно в Confluence',
            description: 'Используйте кнопку «Опубликовать в Confluence», чтобы поделиться ТЗ',
          ),
        ],
      );
    } else if (isConfluenceEnabled && !hasValidConnection) {
      return UserGuidanceWidget(
        title: 'Проблема с подключением к Confluence',
        message: 'Интеграция с Confluence требует внимания.',
        icon: Icons.warning,
        backgroundColor: Colors.orange.shade50,
        actionLabel: 'Исправить подключение',
        onAction: () {
          // Navigate to settings
        },
      );
    } else {
      return UserGuidanceWidget(
        title: 'Включите интеграцию с Confluence',
        message: 'Подключите Confluence, чтобы ссылаться на существующую документацию в ваших спецификациях.',
        icon: Icons.link,
        backgroundColor: Colors.blue.shade50,
        steps: const [
          GuidanceStep(
            title: 'Перейдите в Настройки',
            description: 'Нажмите кнопку «Настройки» в правом верхнем углу',
          ),
          GuidanceStep(
            title: 'Включите интеграцию Confluence',
            description: 'Переключите тумблер Confluence и введите учетные данные',
          ),
          GuidanceStep(
            title: 'Проверьте подключение',
            description: 'Убедитесь, что подключение работает, перед сохранением',
          ),
        ],
      );
    }
  }
}

/// Quick tips widget for keyboard shortcuts
class KeyboardShortcutsWidget extends StatelessWidget {
  const KeyboardShortcutsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return UserGuidanceWidget(
      title: 'Keyboard Shortcuts',
      message: 'Speed up your workflow with these shortcuts',
      icon: Icons.keyboard,
      backgroundColor: Colors.purple.shade50,
      steps: const [
        GuidanceStep(
          title: 'Ctrl+Enter - Generate/Update specification',
          isCompleted: true,
        ),
        GuidanceStep(
          title: 'Ctrl+S - Save specification to file',
          isCompleted: true,
        ),
        GuidanceStep(
          title: 'Ctrl+C - Copy specification to clipboard',
          isCompleted: true,
        ),
        GuidanceStep(
          title: 'Ctrl+P - Publish to Confluence (if enabled)',
          isCompleted: true,
        ),
        GuidanceStep(
          title: 'Ctrl+R - Clear all fields',
          isCompleted: true,
        ),
        GuidanceStep(
          title: 'F1 - Show help',
          isCompleted: true,
        ),
      ],
    );
  }
}