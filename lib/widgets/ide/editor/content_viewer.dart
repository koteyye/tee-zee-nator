import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/project_file.dart';
import '../../../services/content_renderer_service.dart';
import '../../../theme/ide_theme.dart';
import '../../../utils/error_handler.dart';
import 'diff_viewer.dart';
import 'markdown_viewer.dart';
import 'html_viewer.dart';

/// Виджет для отображения содержимого файла
class ContentViewer extends StatelessWidget {
  final ProjectFile? file;

  const ContentViewer({
    super.key,
    this.file,
  });

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return _buildEmptyState(context);
    }

    return Consumer<ContentRendererService>(
      builder: (context, rendererService, child) {
        return FutureBuilder<String>(
          future: rendererService.loadFileContent(file!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(context, snapshot.error);
            }

            final content = snapshot.data ?? '';

            // Если есть pending content, показать diff
            if (file!.pendingContent != null && file!.pendingContent!.isNotEmpty) {
              return DiffViewer(
                original: content,
                modified: file!.pendingContent!,
              );
            }

            // Иначе показать обычный рендер
            return _renderContent(context, file!, content);
          },
        );
      },
    );
  }

  /// Рендерить контент в зависимости от типа файла
  Widget _renderContent(BuildContext context, ProjectFile file, String content) {
    switch (file.type) {
      case FileType.markdown:
        return MarkdownViewer(content: content);
      case FileType.html:
      case FileType.confluence:
        return HtmlViewer(content: content);
      case FileType.unknown:
        return _buildPlainTextViewer(content);
    }
  }

  /// Plain text viewer для неизвестных типов
  Widget _buildPlainTextViewer(String content) {
    return Container(
      color: IDETheme.editorBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: IDETheme.codeStyle,
        ),
      ),
    );
  }

  /// Состояние загрузки
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: IDETheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Загрузка файла...',
            style: IDETheme.bodyMediumStyle.copyWith(
              color: IDETheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Пустое состояние
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Откройте файл для просмотра',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Выберите файл в проводнике',
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

  /// Состояние ошибки
  Widget _buildErrorState(BuildContext context, Object? error) {
    // Получаем локализованное сообщение об ошибке
    final errorMessage = error != null
        ? ErrorHandler.getErrorMessage(context, error)
        : 'Неизвестная ошибка';

    final technicalDetails = error?.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: IDETheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки файла',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                errorMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              if (technicalDetails != null && technicalDetails != errorMessage) ...[
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Повторная загрузка файла
                  if (file != null) {
                    final rendererService = context.read<ContentRendererService>();
                    try {
                      // Очищаем кеш и пытаемся загрузить снова
                      file!.cachedContent = null;
                      await rendererService.loadFileContent(file!);
                    } catch (e) {
                      if (context.mounted) {
                        ErrorHandler.showError(context, e);
                      }
                    }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: IDETheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
