import 'package:flutter/foundation.dart';
import '../models/project_file.dart';
import 'project_service.dart';

/// Сервис для управления изменениями файлов
class FileModificationService extends ChangeNotifier {
  final Map<String, ProjectFile> _modifiedFiles = {};
  final ProjectService _projectService;

  FileModificationService(this._projectService);

  /// Измененные файлы
  Map<String, ProjectFile> get modifiedFiles => _modifiedFiles;

  /// Есть ли несохраненные изменения
  bool get hasUnsavedChanges => _modifiedFiles.isNotEmpty;

  /// Применить pending контент к файлу
  void applyPendingContent(ProjectFile file, String newContent) {
    try {
      // Сохраняем оригинальный контент (если еще не сохранен)
      if (file.originalContent == null) {
        file.originalContent = file.cachedContent;
      }

      // Устанавливаем новый контент как pending
      file.pendingContent = newContent;
      file.isModified = true;

      // Добавляем в список измененных
      _modifiedFiles[file.id] = file;

      notifyListeners();
      debugPrint('[FileModificationService] Applied pending content to ${file.name}');
    } catch (e) {
      debugPrint('[FileModificationService] Error applying pending content: $e');
      rethrow;
    }
  }

  /// Откатить изменения файла
  void revertChanges(ProjectFile file) {
    try {
      // Восстанавливаем оригинальный контент
      if (file.originalContent != null) {
        file.cachedContent = file.originalContent;
        file.originalContent = null;
      }

      // Очищаем pending контент
      file.pendingContent = null;
      file.isModified = false;

      // Удаляем из списка измененных
      _modifiedFiles.remove(file.id);

      notifyListeners();
      debugPrint('[FileModificationService] Reverted changes for ${file.name}');
    } catch (e) {
      debugPrint('[FileModificationService] Error reverting changes: $e');
      rethrow;
    }
  }

  /// Сохранить файл на диск
  Future<void> saveToFile(ProjectFile file) async {
    try {
      // Если есть pending контент, применяем его
      if (file.pendingContent != null) {
        file.cachedContent = file.pendingContent;
        file.pendingContent = null;
      }

      // Делегируем сохранение в ProjectService
      await _projectService.saveFile(file);

      // Очищаем состояние модификации
      file.originalContent = null;
      file.isModified = false;

      // Удаляем из списка измененных
      _modifiedFiles.remove(file.id);

      notifyListeners();
      debugPrint('[FileModificationService] File saved: ${file.name}');
    } catch (e) {
      debugPrint('[FileModificationService] Error saving file: $e');
      rethrow;
    }
  }

  /// Сохранить все измененные файлы
  Future<void> saveAllModified() async {
    final filesToSave = List<ProjectFile>.from(_modifiedFiles.values);

    for (final file in filesToSave) {
      try {
        await saveToFile(file);
      } catch (e) {
        debugPrint('[FileModificationService] Error saving ${file.name}: $e');
        // Продолжаем сохранять остальные файлы
      }
    }

    notifyListeners();
  }

  /// Проверить есть ли несохраненные изменения у файла
  bool hasUnsavedChangesForFile(ProjectFile file) {
    return _modifiedFiles.containsKey(file.id);
  }

  /// Получить количество несохраненных файлов
  int get unsavedFilesCount => _modifiedFiles.length;

  /// Отменить все изменения
  void revertAllChanges() {
    final filesToRevert = List<ProjectFile>.from(_modifiedFiles.values);

    for (final file in filesToRevert) {
      revertChanges(file);
    }

    notifyListeners();
  }

  /// Очистить состояние сервиса
  void clear() {
    _modifiedFiles.clear();
    notifyListeners();
  }
}
