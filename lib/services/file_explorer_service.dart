import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_lib;
import '../models/file_node_model.dart';
import '../models/project_file.dart';
import '../models/project.dart';

/// Сервис для управления навигацией по файлам в проекте
class FileExplorerService extends ChangeNotifier {
  List<FileNode> _fileTree = [];
  ProjectFile? _selectedFile;

  /// Дерево файлов
  List<FileNode> get fileTree => _fileTree;

  /// Выбранный файл
  ProjectFile? get selectedFile => _selectedFile;

  /// Построить дерево файлов из проекта
  Future<void> buildFileTree(Project project) async {
    try {
      // Группируем файлы по директориям
      final rootPath = project.path;
      final filesByPath = <String, List<ProjectFile>>{};

      for (final file in project.files) {
        final relativePath = path_lib.relative(file.path, from: rootPath);
        final dirPath = path_lib.dirname(relativePath);

        if (!filesByPath.containsKey(dirPath)) {
          filesByPath[dirPath] = [];
        }
        filesByPath[dirPath]!.add(file);
      }

      // Строим дерево
      _fileTree = _buildTreeFromFiles(project.files, rootPath);

      // Сортируем
      for (final node in _fileTree) {
        node.sortChildren();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[FileExplorerService] Error building file tree: $e');
      _fileTree = [];
      notifyListeners();
    }
  }

  /// Построить дерево из списка файлов
  List<FileNode> _buildTreeFromFiles(List<ProjectFile> files, String rootPath) {
    final Map<String, FileNode> nodeMap = {};
    final List<FileNode> rootNodes = [];

    // Создаем узлы для всех уникальных путей
    for (final file in files) {
      final relativePath = path_lib.relative(file.path, from: rootPath);
      final parts = path_lib.split(relativePath);

      String currentPath = '';
      int level = 0;

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final previousPath = currentPath;
        currentPath = currentPath.isEmpty ? part : path_lib.join(currentPath, part);
        final absolutePath = path_lib.join(rootPath, currentPath);
        final isDirectory = i < parts.length - 1;

        if (!nodeMap.containsKey(currentPath)) {
          final node = FileNode(
            name: part,
            path: absolutePath,
            isDirectory: isDirectory,
            children: isDirectory ? [] : null,
            level: level,
          );

          nodeMap[currentPath] = node;

          // Добавляем к родителю или в корень
          if (previousPath.isEmpty) {
            rootNodes.add(node);
          } else {
            final parentNode = nodeMap[previousPath];
            if (parentNode != null && parentNode.children != null) {
              parentNode.children!.add(node);
            }
          }
        }

        level++;
      }
    }

    return rootNodes;
  }

  /// Переключить состояние узла (раскрыть/свернуть)
  void toggleNode(FileNode node) {
    if (!node.isDirectory) return;

    node.toggleExpand();
    notifyListeners();
  }

  /// Выбрать файл
  void selectFile(ProjectFile? file) {
    _selectedFile = file;
    notifyListeners();
  }

  /// Раскрыть узел по пути
  void expandNodeByPath(String filePath) {
    for (final rootNode in _fileTree) {
      final node = rootNode.findNodeByPath(filePath);
      if (node != null) {
        // Раскрываем все родительские узлы
        _expandParentNodes(filePath);
        notifyListeners();
        return;
      }
    }
  }

  /// Раскрыть все родительские узлы для пути
  void _expandParentNodes(String filePath) {
    for (final rootNode in _fileTree) {
      _expandParentNodesRecursive(rootNode, filePath);
    }
  }

  /// Рекурсивное раскрытие родительских узлов
  bool _expandParentNodesRecursive(FileNode node, String targetPath) {
    if (node.path == targetPath) {
      return true;
    }

    if (node.children != null) {
      for (final child in node.children!) {
        if (_expandParentNodesRecursive(child, targetPath)) {
          node.isExpanded = true;
          return true;
        }
      }
    }

    return false;
  }

  /// Получить плоский список видимых узлов (для отображения)
  List<FileNode> getFlattenedTree() {
    final result = <FileNode>[];
    for (final node in _fileTree) {
      result.addAll(node.flattenTree());
    }
    return result;
  }

  /// Раскрыть все узлы
  void expandAll() {
    for (final node in _fileTree) {
      _expandAllRecursive(node);
    }
    notifyListeners();
  }

  /// Свернуть все узлы
  void collapseAll() {
    for (final node in _fileTree) {
      _collapseAllRecursive(node);
    }
    notifyListeners();
  }

  /// Рекурсивное раскрытие всех узлов
  void _expandAllRecursive(FileNode node) {
    if (node.isDirectory) {
      node.isExpanded = true;
      if (node.children != null) {
        for (final child in node.children!) {
          _expandAllRecursive(child);
        }
      }
    }
  }

  /// Рекурсивное сворачивание всех узлов
  void _collapseAllRecursive(FileNode node) {
    if (node.isDirectory) {
      node.isExpanded = false;
      if (node.children != null) {
        for (final child in node.children!) {
          _collapseAllRecursive(child);
        }
      }
    }
  }

  /// Очистить дерево
  void clear() {
    _fileTree = [];
    _selectedFile = null;
    notifyListeners();
  }
}
