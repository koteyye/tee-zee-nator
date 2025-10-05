import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/project_error.dart';

/// Утилита для обработки и отображения ошибок
class ErrorHandler {
  /// Показать сообщение об ошибке (диалог для критичных, SnackBar для некритичных)
  static void showError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    bool forceDialog = false,
  }) {
    // Всегда показываем диалог для критичных ошибок или если forceDialog = true
    if (forceDialog || _isCriticalError(error)) {
      showErrorDialog(context, error, onRetry: onRetry);
    } else {
      // SnackBar только для некритичных ошибок
      final localizations = AppLocalizations.of(context)!;
      String message;

      if (error is ProjectError) {
        message = _getLocalizedErrorMessage(localizations, error);
      } else {
        message = localizations.errorGeneric(error.toString());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: onRetry != null
              ? SnackBarAction(
                  label: localizations.retryAction,
                  textColor: Colors.white,
                  onPressed: onRetry,
                )
              : null,
        ),
      );
    }
  }

  /// Определить, является ли ошибка критичной (требует диалога)
  static bool _isCriticalError(dynamic error) {
    if (error is ProjectError) {
      // Все ошибки проекта критичны
      return true;
    }

    // Assertion errors и другие фатальные ошибки
    if (error is AssertionError || error is StateError) {
      return true;
    }

    return false;
  }

  /// Показать диалог с ошибкой (с возможностью копирования)
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    String userMessage;
    String? technicalDetails;
    String title = 'Ошибка';

    if (error is ProjectError) {
      userMessage = _getLocalizedErrorMessage(localizations, error);
      technicalDetails = error.message;
      title = _getErrorTitle(error);
    } else {
      userMessage = localizations.errorGeneric(error.toString());
      technicalDetails = error.toString();
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                userMessage,
                style: const TextStyle(fontSize: 14),
              ),
              if (technicalDetails != null && technicalDetails != userMessage) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text(
                    'Технические детали',
                    style: TextStyle(fontSize: 14),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        technicalDetails,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(localizations.retryAction),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }

  /// Получить локализованное сообщение об ошибке
  static String _getLocalizedErrorMessage(
    AppLocalizations localizations,
    ProjectError error,
  ) {
    switch (error.type) {
      case ProjectErrorType.directoryNotFound:
        return localizations.errorDirectoryNotFound;

      case ProjectErrorType.directoryAccessDenied:
        return localizations.errorDirectoryAccessDenied;

      case ProjectErrorType.tooManyFiles:
        // Извлекаем количество файлов из сообщения
        final match = RegExp(r'(\d+)').firstMatch(error.message);
        final maxFiles = match != null ? int.tryParse(match.group(1)!) ?? 1000 : 1000;
        return localizations.errorTooManyFiles(maxFiles);

      case ProjectErrorType.noSupportedFiles:
        return localizations.errorNoSupportedFiles;

      case ProjectErrorType.fileNotFound:
        return localizations.errorFileNotFound;

      case ProjectErrorType.fileTooBig:
        // Извлекаем максимальный размер из сообщения (по умолчанию 5MB)
        return localizations.errorFileTooBig(5);

      case ProjectErrorType.fileReadPermission:
        return localizations.errorFileReadPermission;

      case ProjectErrorType.aiInvalidResponse:
        return localizations.errorAiInvalidResponse;

      case ProjectErrorType.aiNetworkError:
        return localizations.errorAiNetworkError;

      case ProjectErrorType.aiTimeout:
        return localizations.errorAiTimeout;

      case ProjectErrorType.generic:
        return localizations.errorGeneric(error.message);
    }
  }

  /// Получить заголовок ошибки по типу
  static String _getErrorTitle(ProjectError error) {
    switch (error.type) {
      case ProjectErrorType.directoryNotFound:
      case ProjectErrorType.directoryAccessDenied:
      case ProjectErrorType.tooManyFiles:
      case ProjectErrorType.noSupportedFiles:
        return 'Ошибка открытия проекта';

      case ProjectErrorType.fileNotFound:
      case ProjectErrorType.fileTooBig:
      case ProjectErrorType.fileReadPermission:
        return 'Ошибка загрузки файла';

      case ProjectErrorType.aiInvalidResponse:
      case ProjectErrorType.aiNetworkError:
      case ProjectErrorType.aiTimeout:
        return 'Ошибка AI';

      case ProjectErrorType.generic:
        return 'Ошибка';
    }
  }

  /// Обработать ошибку и вернуть локализованное сообщение
  static String getErrorMessage(BuildContext context, dynamic error) {
    final localizations = AppLocalizations.of(context)!;

    if (error is ProjectError) {
      return _getLocalizedErrorMessage(localizations, error);
    } else {
      return localizations.errorGeneric(error.toString());
    }
  }
}
