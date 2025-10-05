import 'package:json_annotation/json_annotation.dart';
import 'project_file.dart';

part 'project.g.dart';

/// Модель проекта - папка с техническими заданиями
@JsonSerializable(explicitToJson: true)
class Project {
  /// Уникальный идентификатор проекта
  final String id;

  /// Название проекта (обычно название папки)
  final String name;

  /// Абсолютный путь к папке проекта
  final String path;

  /// Дата создания проекта
  final DateTime createdAt;

  /// Дата последнего открытия
  final DateTime lastOpenedAt;

  /// Список файлов в проекте
  final List<ProjectFile> files;

  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    required this.lastOpenedAt,
    required this.files,
  });

  /// Создание из JSON
  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$ProjectToJson(this);

  /// Копирование с изменениями
  Project copyWith({
    String? id,
    String? name,
    String? path,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    List<ProjectFile>? files,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      files: files ?? this.files,
    );
  }

  @override
  String toString() {
    return 'Project(id: $id, name: $name, path: $path, files: ${files.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
