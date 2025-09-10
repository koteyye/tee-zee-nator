import 'package:hive/hive.dart';

part 'output_format.g.dart';

/// Enum representing the available output formats for technical specification generation
@HiveType(typeId: 11)
enum OutputFormat {
  @HiveField(0)
  markdown('Markdown', 'md', true),
  
  @HiveField(1)
  confluence('Confluence Storage Format', 'html', false);
  
  const OutputFormat(this.displayName, this.fileExtension, this.isDefault);
  
  /// Human-readable name for the format
  final String displayName;
  
  /// File extension for this format
  final String fileExtension;
  
  /// Whether this format is the preferred default
  final bool isDefault;
  
  /// Returns the default format (Markdown as preferred)
  static OutputFormat get defaultFormat => 
      values.firstWhere((format) => format.isDefault);
}