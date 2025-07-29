import 'output_format.dart';

class GenerationHistory {
  final String rawRequirements;
  final String? changes;
  final String generatedTz;
  final DateTime timestamp;
  final String model;
  final OutputFormat format;
  
  GenerationHistory({
    required this.rawRequirements,
    this.changes,
    required this.generatedTz,
    required this.timestamp,
    required this.model,
    required this.format,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'rawRequirements': rawRequirements,
      'changes': changes,
      'generatedTz': generatedTz,
      'timestamp': timestamp.toIso8601String(),
      'model': model,
      'format': format.name,
    };
  }
  
  factory GenerationHistory.fromJson(Map<String, dynamic> json) {
    return GenerationHistory(
      rawRequirements: json['rawRequirements'],
      changes: json['changes'],
      generatedTz: json['generatedTz'],
      timestamp: DateTime.parse(json['timestamp']),
      model: json['model'],
      format: json['format'] != null 
          ? OutputFormat.values.firstWhere(
              (f) => f.name == json['format'],
              orElse: () => OutputFormat.defaultFormat,
            )
          : OutputFormat.defaultFormat, // Default for legacy data
    );
  }
}
