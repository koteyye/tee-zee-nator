import 'package:flutter/material.dart';
import '../widgets/common/error_notification.dart';

/// Сервис для отображения уведомлений в приложении
class NotificationService {
  static final List<OverlayEntry> _overlayStack = [];
  static const int _maxNotifications = 3;

  /// Показывает уведомление об ошибке
  static void showError(
    BuildContext context,
    String message, {
    String? technicalDetails,
    Duration? duration,
  }) {
    _showNotification(
      context,
      message: message,
      technicalDetails: technicalDetails,
      backgroundColor: const Color(0xFFF44336), // Material Red 500
      textColor: Colors.white,
      icon: Icons.error,
      duration: duration ?? const Duration(seconds: 10),
    );
  }

  /// Показывает уведомление об успехе
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showNotification(
      context,
      message: message,
      backgroundColor: const Color(0xFF4CAF50), // Material Green 500
      textColor: Colors.white,
      icon: Icons.check_circle,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Показывает информационное уведомление
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showNotification(
      context,
      message: message,
      backgroundColor: const Color(0xFF2196F3), // Material Blue 500
      textColor: Colors.white,
      icon: Icons.info,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// Показывает предупреждение
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showNotification(
      context,
      message: message,
      backgroundColor: const Color(0xFFFF9800), // Material Orange 500
      textColor: Colors.white,
      icon: Icons.warning,
      duration: duration ?? const Duration(seconds: 7),
    );
  }

  /// Внутренний метод для показа уведомления
  static void _showNotification(
    BuildContext context, {
    required String message,
    String? technicalDetails,
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    required Duration duration,
  }) {
    // Если достигнут максимум уведомлений, удаляем самое старое
    if (_overlayStack.length >= _maxNotifications) {
      final oldest = _overlayStack.removeAt(0);
      oldest.remove();
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 16.0 + (_overlayStack.length * 76.0), // Отступ для стека
        left: 0,
        right: 0,
        child: ErrorNotification(
          message: message,
          technicalDetails: technicalDetails,
          backgroundColor: backgroundColor,
          textColor: textColor,
          icon: icon,
          autoCloseDuration: duration,
          onClose: () {
            overlayEntry.remove();
            _overlayStack.remove(overlayEntry);
          },
        ),
      ),
    );

    _overlayStack.add(overlayEntry);
    overlay.insert(overlayEntry);

    // Автоматическое удаление через duration
    Future.delayed(duration, () {
      if (_overlayStack.contains(overlayEntry)) {
        overlayEntry.remove();
        _overlayStack.remove(overlayEntry);
      }
    });
  }

  /// Закрывает все уведомления
  static void closeAll() {
    for (final entry in _overlayStack) {
      entry.remove();
    }
    _overlayStack.clear();
  }
}