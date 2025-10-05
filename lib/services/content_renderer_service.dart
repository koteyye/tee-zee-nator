import 'dart:io';
import 'package:flutter/material.dart';
import '../models/project_file.dart';
import '../models/project_error.dart';

/// Сервис для рендеринга содержимого файлов
class ContentRendererService {
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB

  /// Загрузить содержимое файла
  Future<String> loadFileContent(ProjectFile file) async {
    try {
      // Если контент уже закеширован, возвращаем его
      if (file.cachedContent != null) {
        return file.cachedContent!;
      }

      // Проверяем размер файла
      if (file.size > _maxFileSize) {
        throw ProjectError.fileTooBig(file.size, _maxFileSize);
      }

      // Загружаем с диска
      final fileEntity = File(file.path);

      if (!await fileEntity.exists()) {
        throw ProjectError.fileNotFound(file.path);
      }

      // Пытаемся прочитать файл с обработкой ошибок доступа
      try {
        final content = await fileEntity.readAsString();

        // Кешируем
        file.cachedContent = content;

        return content;
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode == 5 || e.osError?.errorCode == 13) {
          // Windows: 5, Unix: 13 - Access denied
          throw ProjectError.fileReadPermission(file.path);
        }
        rethrow;
      }
    } on ProjectError {
      rethrow;
    } catch (e) {
      debugPrint('[ContentRendererService] Error loading file: $e');
      throw ProjectError.generic('Failed to load file', e);
    }
  }

  /// Может ли сервис отрендерить данный тип файла
  bool canRender(FileType type) {
    return type == FileType.markdown ||
        type == FileType.html ||
        type == FileType.confluence;
  }

  /// Получить виджет для рендеринга контента
  /// (Это будет использоваться в ContentViewer виджетах позже)
  Widget renderContent(
    BuildContext context,
    ProjectFile file,
    String content,
  ) {
    // Базовая реализация - простой текст
    // Позже будем использовать flutter_markdown и flutter_html виджеты
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }

  /// Рендерить diff между оригиналом и измененной версией
  Widget renderDiff(
    BuildContext context,
    String original,
    String modified,
  ) {
    // Базовая реализация - показываем оба варианта
    // Позже будем использовать построчный diff
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оригинал:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              original,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Изменено:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              modified,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Получить иконку для типа файла
  IconData getFileIcon(FileType type) {
    switch (type) {
      case FileType.markdown:
        return Icons.description;
      case FileType.html:
        return Icons.code;
      case FileType.confluence:
        return Icons.cloud;
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  /// Получить цвет для типа файла
  Color getFileColor(FileType type) {
    switch (type) {
      case FileType.markdown:
        return Colors.blue;
      case FileType.html:
        return Colors.orange;
      case FileType.confluence:
        return Colors.green;
      case FileType.unknown:
        return Colors.grey;
    }
  }
}
