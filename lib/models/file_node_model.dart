/// Модель узла в дереве файлов
/// Представляет файл или папку в файловой структуре проекта
class FileNode {
  /// Имя файла или папки
  final String name;

  /// Абсолютный путь
  final String path;

  /// Является ли папкой
  final bool isDirectory;

  /// Дочерние узлы (для папок)
  final List<FileNode>? children;

  /// Раскрыта ли папка (состояние UI)
  bool isExpanded;

  /// Уровень вложенности (для отступов в UI)
  final int level;

  FileNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children,
    this.isExpanded = false,
    this.level = 0,
  });

  /// Переключить состояние раскрытия
  void toggleExpand() {
    if (isDirectory) {
      isExpanded = !isExpanded;
    }
  }

  /// Найти узел по пути
  FileNode? findNodeByPath(String targetPath) {
    if (path == targetPath) {
      return this;
    }

    if (children != null) {
      for (final child in children!) {
        final found = child.findNodeByPath(targetPath);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  /// Получить плоский список всех узлов (для отображения)
  List<FileNode> flattenTree() {
    final result = <FileNode>[this];

    if (isDirectory && isExpanded && children != null) {
      for (final child in children!) {
        result.addAll(child.flattenTree());
      }
    }

    return result;
  }

  /// Сортировка дочерних узлов (папки первыми, потом файлы, алфавитно)
  void sortChildren() {
    if (children == null) return;

    children!.sort((a, b) {
      // Папки первыми
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      // Алфавитный порядок
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Рекурсивно сортировать вложенные папки
    for (final child in children!) {
      child.sortChildren();
    }
  }

  /// Получить количество файлов в узле (рекурсивно)
  int getFileCount() {
    if (!isDirectory) return 1;

    int count = 0;
    if (children != null) {
      for (final child in children!) {
        count += child.getFileCount();
      }
    }
    return count;
  }

  /// Копирование с изменениями
  FileNode copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    List<FileNode>? children,
    bool? isExpanded,
    int? level,
  }) {
    return FileNode(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      level: level ?? this.level,
    );
  }

  @override
  String toString() {
    return 'FileNode(name: $name, isDirectory: $isDirectory, level: $level, children: ${children?.length ?? 0})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FileNode && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}
