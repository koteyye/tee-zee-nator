import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'template.g.dart';

/// (Deprecated) Enum for template format – retained only for backward compatibility.
/// Все шаблоны теперь считаются Markdown. Значение игнорируется.
@HiveType(typeId: 13)
enum TemplateFormat {
  @HiveField(0)
  @JsonValue('markdown')
  markdown,
  @HiveField(1)
  @JsonValue('confluence')
  confluence,
}

@HiveType(typeId: 3)
@JsonSerializable()
class Template {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String content;
  
  @HiveField(3)
  final bool isDefault;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime? updatedAt;
  
  @HiveField(6)
  @JsonKey(name: 'format')
  final TemplateFormat format; // Deprecated: always treated as markdown
  
  Template({
    required this.id,
    required this.name,
    required this.content,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  required this.format,
  });
  
  factory Template.fromJson(Map<String, dynamic> json) => _$TemplateFromJson(json);
  Map<String, dynamic> toJson() => _$TemplateToJson(this);
  
  Template copyWith({
    String? id,
    String? name,
    String? content,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  TemplateFormat? format,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
  format: format ?? this.format,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Template &&
          runtimeType == other.runtimeType &&
          id == other.id;
  
  @override
  int get hashCode => id.hashCode;
  
  
  @override
  String toString() {
  return 'Template{id: $id, name: $name, isDefault: $isDefault}';
  }
}
