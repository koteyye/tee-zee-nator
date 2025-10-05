import 'package:json_annotation/json_annotation.dart';
import 'file_change.dart';

part 'ai_response.g.dart';

/// Модель ответа от AI
/// Содержит сообщение для пользователя и опционально контент для файлов
@JsonSerializable(explicitToJson: true)
class AIResponse {
  /// Сообщение для отображения пользователю в чате
  @JsonKey(name: 'user_message')
  final String userMessage;

  /// Контент для записи в файл (опционально, для одного файла)
  @JsonKey(name: 'file_content')
  final String? fileContent;

  /// Множественные изменения файлов (опционально)
  @JsonKey(name: 'file_changes')
  final List<FileChange>? fileChanges;

  /// Дополнительные метаданные
  final Map<String, dynamic>? metadata;

  AIResponse({
    required this.userMessage,
    this.fileContent,
    this.fileChanges,
    this.metadata,
  });

  /// Создание из JSON
  factory AIResponse.fromJson(Map<String, dynamic> json) =>
      _$AIResponseFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$AIResponseToJson(this);

  /// Есть ли контент для одного файла
  bool get hasSingleFileContent => fileContent != null;

  /// Есть ли множественные изменения
  bool get hasMultipleFileChanges =>
      fileChanges != null && fileChanges!.isNotEmpty;

  /// Есть ли какой-либо контент для файлов
  bool get hasAnyFileContent => hasSingleFileContent || hasMultipleFileChanges;

  /// Получить целевой файл из metadata (если указан)
  String? get targetFile => metadata?['target_file'] as String?;

  /// Получить действие из metadata
  String? get action => metadata?['action'] as String?;

  /// Получить Confluence ссылки из metadata
  List<String>? get confluenceLinks {
    final links = metadata?['confluence_links'];
    if (links is List) {
      return links.map((e) => e.toString()).toList();
    }
    return null;
  }

  @override
  String toString() {
    return 'AIResponse(userMessage: ${userMessage.substring(0, 50)}..., '
        'hasSingleFile: $hasSingleFileContent, '
        'hasMultipleChanges: $hasMultipleFileChanges)';
  }
}
