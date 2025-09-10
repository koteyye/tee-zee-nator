import 'package:flutter/material.dart';

/// Enhanced tooltip widget with better styling and accessibility
/// 
/// Provides:
/// - Rich text support
/// - Custom styling
/// - Better positioning
/// - Accessibility features
/// - Keyboard shortcuts display
class EnhancedTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final String? richMessage;
  final String? keyboardShortcut;
  final IconData? icon;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final Duration? showDuration;
  final Duration? waitDuration;

  const EnhancedTooltip({
    super.key,
    required this.child,
    required this.message,
    this.richMessage,
    this.keyboardShortcut,
    this.icon,
    this.backgroundColor,
    this.textStyle,
    this.padding,
    this.showDuration,
    this.waitDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    String fullMessage = message;
    if (keyboardShortcut != null) {
      fullMessage += ' ($keyboardShortcut)';
    }

    return Tooltip(
      message: richMessage != null ? null : fullMessage,
      richMessage: richMessage != null ? _buildRichMessage(context) : null,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: textStyle ?? const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      showDuration: showDuration ?? const Duration(seconds: 3),
      waitDuration: waitDuration ?? const Duration(milliseconds: 500),
      child: child,
    );
  }

  TextSpan _buildRichMessage(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextSpan(
      children: [
        if (icon != null) ...[
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                icon,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
        TextSpan(
          text: richMessage ?? message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (keyboardShortcut != null) ...[
          const TextSpan(text: '\n'),
          TextSpan(
            text: keyboardShortcut!,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// A specialized tooltip for buttons with keyboard shortcuts
class ButtonTooltip extends StatelessWidget {
  final Widget child;
  final String action;
  final String shortcut;
  final IconData? icon;
  final bool enabled;

  const ButtonTooltip({
    super.key,
    required this.child,
    required this.action,
    required this.shortcut,
    this.icon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTooltip(
      message: enabled ? action : '$action (disabled)',
      keyboardShortcut: enabled ? shortcut : null,
      icon: icon,
      backgroundColor: enabled ? null : Colors.grey.shade600,
      child: child,
    );
  }
}

/// A tooltip specifically for form fields
class FieldTooltip extends StatelessWidget {
  final Widget child;
  final String label;
  final String hint;
  final String? example;
  final bool required;

  const FieldTooltip({
    super.key,
    required this.child,
    required this.label,
    required this.hint,
    this.example,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    String message = hint;
    if (example != null) {
      message += '\nExample: $example';
    }
    if (required) {
      message += '\n(Required)';
    }

    return EnhancedTooltip(
      message: label,
      richMessage: message,
      icon: required ? Icons.star : Icons.help_outline,
      child: child,
    );
  }
}