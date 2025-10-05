import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' hide FileType;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path_lib;
import '../models/project.dart';
import '../models/project_file.dart';
import '../models/project_error.dart';

/// Сервис для управления проектами
class ProjectService extends ChangeNotifier {
  Project? _currentProject;
  List<Project> _recentProjects = [];
  static const int _maxFiles = 1000; // Защита от перегрузки
  static const String _recentProjectsBoxName = 'recent_projects';
  Box<dynamic>? _recentProjectsBox;

  /// Текущий открытый проект
  Project? get currentProject => _currentProject;

  /// Список недавних проектов
  List<Project> get recentProjects => _recentProjects;

  /// Инициализация сервиса
  Future<void> init() async {
    try {
      _recentProjectsBox = await Hive.openBox(_recentProjectsBoxName);
      await _loadRecentProjects();
    } catch (e) {
      debugPrint('[ProjectService] Init error: $e');
    }
  }

  /// Загрузить список недавних проектов из Hive
  Future<void> _loadRecentProjects() async {
    try {
      final projectsData = _recentProjectsBox?.get('projects') as List<dynamic>?;
      if (projectsData != null) {
        _recentProjects = projectsData
            .map((data) => Project.fromJson(Map<String, dynamic>.from(data as Map)))
            .toList();

        // Сортировка по дате последнего открытия
        _recentProjects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
      }
    } catch (e) {
      debugPrint('[ProjectService] Error loading recent projects: $e');
      _recentProjects = [];
    }
  }

  /// Сохранить список недавних проектов
  Future<void> _saveRecentProjects() async {
    try {
      final projectsData = _recentProjects.map((p) => p.toJson()).toList();
      await _recentProjectsBox?.put('projects', projectsData);
    } catch (e) {
      debugPrint('[ProjectService] Error saving recent projects: $e');
    }
  }

  /// Открыть проект из директории
  Future<Project> openProject(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);

      // Проверяем существование директории
      if (!await directory.exists()) {
        throw ProjectError.directoryNotFound(directoryPath);
      }

      // Проверяем права доступа
      try {
        await directory.list(recursive: false, followLinks: false).isEmpty;
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode == 5 || e.osError?.errorCode == 13) {
          // Windows: 5, Unix: 13 - Access denied
          throw ProjectError.directoryAccessDenied(directoryPath);
        }
        rethrow;
      }

      // Сканируем файлы (пустой список - это нормально для нового проекта)
      final files = await scanDirectory(directoryPath);

      // Создаем проект
      final projectName = path_lib.basename(directoryPath);
      final now = DateTime.now();
      final projectId = const Uuid().v4();

      final project = Project(
        id: projectId,
        name: projectName,
        path: directoryPath,
        createdAt: now,
        lastOpenedAt: now,
        files: files,
      );

      _currentProject = project;

      // Добавляем в недавние проекты
      await _addToRecentProjects(project);

      notifyListeners();
      return project;
    } on ProjectError {
      rethrow;
    } catch (e) {
      debugPrint('[ProjectService] Error opening project: $e');
      throw ProjectError.generic('Failed to open project', e);
    }
  }

  /// Открыть проект через диалог выбора папки
  Future<Project?> openProjectDialog() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Выберите папку с проектом',
      );

      if (result != null) {
        return await openProject(result);
      }
      return null;
    } catch (e) {
      debugPrint('[ProjectService] Error in openProjectDialog: $e');
      rethrow;
    }
  }

  /// Закрыть текущий проект
  Future<void> closeProject() async {
    _currentProject = null;
    notifyListeners();
  }

  /// Сканировать директорию и найти все поддерживаемые файлы
  Future<List<ProjectFile>> scanDirectory(String directoryPath) async {
    final files = <ProjectFile>[];
    final directory = Directory(directoryPath);

    await _scanDirectoryRecursive(directory, files);

    if (files.length > _maxFiles) {
      throw ProjectError.tooManyFiles(files.length, _maxFiles);
    }

    return files;
  }

  /// Рекурсивное сканирование директории
  Future<void> _scanDirectoryRecursive(
    Directory directory,
    List<ProjectFile> files,
  ) async {
    try {
      final entities = directory.listSync();

      for (final entity in entities) {
        if (entity is File) {
          final filePath = entity.path;
          final fileType = FileType.detectFileType(filePath);

          // Добавляем только поддерживаемые типы
          if (fileType != FileType.unknown) {
            final stat = await entity.stat();
            final projectFile = ProjectFile(
              id: const Uuid().v4(),
              name: path_lib.basename(filePath),
              path: filePath,
              type: fileType,
              modifiedAt: stat.modified,
              size: stat.size,
            );
            files.add(projectFile);
          }
        } else if (entity is Directory) {
          // Рекурсивно обходим вложенные директории
          // Пропускаем системные папки
          final dirName = path_lib.basename(entity.path);
          if (!dirName.startsWith('.') && dirName != 'node_modules') {
            await _scanDirectoryRecursive(entity, files);
          }
        }
      }
    } catch (e) {
      debugPrint('[ProjectService] Error scanning directory ${directory.path}: $e');
    }
  }

  /// Обновить проект (пересканировать файлы)
  Future<void> refreshProject() async {
    if (_currentProject == null) return;

    try {
      final files = await scanDirectory(_currentProject!.path);
      _currentProject = _currentProject!.copyWith(
        files: files,
        lastOpenedAt: DateTime.now(),
      );

      // Обновляем в недавних проектах
      await _updateRecentProject(_currentProject!);

      notifyListeners();
    } catch (e) {
      debugPrint('[ProjectService] Error refreshing project: $e');
      rethrow;
    }
  }

  /// Сохранить файл на диск
  Future<void> saveFile(ProjectFile file) async {
    try {
      final fileEntity = File(file.path);

      // Записываем контент
      final content = file.cachedContent ?? '';
      await fileEntity.writeAsString(content);

      // Обновляем метаданные
      final stat = await fileEntity.stat();
      final updatedFile = file.copyWith(
        modifiedAt: stat.modified,
        size: stat.size,
        isModified: false,
        originalContent: null,
        pendingContent: null,
      );

      // Обновляем файл в проекте
      if (_currentProject != null) {
        final fileIndex = _currentProject!.files.indexWhere((f) => f.id == file.id);
        if (fileIndex != -1) {
          final updatedFiles = List<ProjectFile>.from(_currentProject!.files);
          updatedFiles[fileIndex] = updatedFile;
          _currentProject = _currentProject!.copyWith(files: updatedFiles);
          notifyListeners();
        }
      }

      debugPrint('[ProjectService] File saved: ${file.name}');
    } catch (e) {
      debugPrint('[ProjectService] Error saving file: $e');
      rethrow;
    }
  }

  /// Добавить проект в недавние
  Future<void> _addToRecentProjects(Project project) async {
    // Удаляем дубликаты (по пути)
    _recentProjects.removeWhere((p) => p.path == project.path);

    // Добавляем в начало
    _recentProjects.insert(0, project);

    // Оставляем только последние 10
    if (_recentProjects.length > 10) {
      _recentProjects = _recentProjects.sublist(0, 10);
    }

    await _saveRecentProjects();
  }

  /// Обновить проект в недавних
  Future<void> _updateRecentProject(Project project) async {
    final index = _recentProjects.indexWhere((p) => p.path == project.path);
    if (index != -1) {
      _recentProjects[index] = project;
      await _saveRecentProjects();
    }
  }

  /// Получить файл по ID
  ProjectFile? getFileById(String fileId) {
    if (_currentProject == null) return null;

    try {
      return _currentProject!.files.firstWhere((f) => f.id == fileId);
    } catch (e) {
      return null;
    }
  }

  /// Получить файл по пути
  ProjectFile? getFileByPath(String filePath) {
    if (_currentProject == null) return null;

    try {
      return _currentProject!.files.firstWhere((f) => f.path == filePath);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _recentProjectsBox?.close();
    super.dispose();
  }
}
