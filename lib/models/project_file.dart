import 'package:json_annotation/json_annotation.dart';

part 'project_file.g.dart';

/// Тип файла в проекте
enum FileType {
  /// Markdown файл (.md)
  markdown,

  /// HTML файл (.html)
  html,

  /// Confluence файл (.confluence)
  confluence,

  /// Неизвестный тип
  unknown;

  /// Определить тип файла по расширению
  static FileType detectFileType(String filePath) {
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.md')) return FileType.markdown;
    if (lowerPath.endsWith('.html')) return FileType.html;
    if (lowerPath.endsWith('.confluence')) return FileType.confluence;
    return FileType.unknown;
  }
}

/// Модель файла в проекте
@JsonSerializable()
class ProjectFile {
  /// Уникальный идентификатор файла
  final String id;

  /// Имя файла (с расширением)
  final String name;

  /// Абсолютный путь к файлу
  final String path;

  /// Тип файла
  final FileType type;

  /// Дата последнего изменения
  final DateTime modifiedAt;

  /// Размер файла в байтах
  final int size;

  /// Кешированное содержимое файла (не сериализуется)
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? cachedContent;

  /// Контент, ожидающий применения от AI (не сериализуется)
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? pendingContent;

  /// Флаг несохраненных изменений
  @JsonKey(defaultValue: false)
  bool isModified;

  /// Оригинальный контент для отката (не сериализуется)
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? originalContent;

  ProjectFile({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.modifiedAt,
    required this.size,
    this.cachedContent,
    this.pendingContent,
    this.isModified = false,
    this.originalContent,
  });

  /// Создание из JSON
  factory ProjectFile.fromJson(Map<String, dynamic> json) =>
      _$ProjectFileFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$ProjectFileToJson(this);

  /// Копирование с изменениями
  ProjectFile copyWith({
    String? id,
    String? name,
    String? path,
    FileType? type,
    DateTime? modifiedAt,
    int? size,
    String? cachedContent,
    String? pendingContent,
    bool? isModified,
    String? originalContent,
  }) {
    return ProjectFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      size: size ?? this.size,
      cachedContent: cachedContent ?? this.cachedContent,
      pendingContent: pendingContent ?? this.pendingContent,
      isModified: isModified ?? this.isModified,
      originalContent: originalContent ?? this.originalContent,
    );
  }

  @override
  String toString() {
    return 'ProjectFile(id: $id, name: $name, type: $type, isModified: $isModified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProjectFile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
