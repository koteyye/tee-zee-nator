class GenerationHistory {
  final String rawRequirements;
  final String? changes;
  final String generatedTz;
  final DateTime timestamp;
  final String model;
  
  GenerationHistory({
    required this.rawRequirements,
    this.changes,
    required this.generatedTz,
    required this.timestamp,
    required this.model,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'rawRequirements': rawRequirements,
      'changes': changes,
      'generatedTz': generatedTz,
      'timestamp': timestamp.toIso8601String(),
      'model': model,
    };
  }
  
  factory GenerationHistory.fromJson(Map<String, dynamic> json) {
    return GenerationHistory(
      rawRequirements: json['rawRequirements'],
      changes: json['changes'],
      generatedTz: json['generatedTz'],
      timestamp: DateTime.parse(json['timestamp']),
      model: json['model'],
    );
  }
}
