import 'package:json_annotation/json_annotation.dart';

part 'file_change.g.dart';

/// Модель изменения файла от AI
/// Используется когда AI возвращает несколько файлов для изменения
@JsonSerializable()
class FileChange {
  /// Путь/имя целевого файла
  @JsonKey(name: 'target_file')
  final String targetFile;

  /// Контент файла
  final String content;

  /// Действие: create, update, delete
  final String action;

  FileChange({
    required this.targetFile,
    required this.content,
    required this.action,
  });

  /// Создание из JSON
  factory FileChange.fromJson(Map<String, dynamic> json) =>
      _$FileChangeFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$FileChangeToJson(this);

  /// Является ли действие созданием
  bool get isCreate => action.toLowerCase() == 'create';

  /// Является ли действие обновлением
  bool get isUpdate => action.toLowerCase() == 'update';

  /// Является ли действие удалением
  bool get isDelete => action.toLowerCase() == 'delete';

  @override
  String toString() {
    return 'FileChange(targetFile: $targetFile, action: $action, contentLength: ${content.length})';
  }
}
