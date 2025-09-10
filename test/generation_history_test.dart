import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/generation_history.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('GenerationHistory', () {
    test('should create GenerationHistory with format field', () {
      final history = GenerationHistory(
        rawRequirements: 'Test requirements',
        changes: 'Test changes',
        generatedTz: 'Test generated content',
        timestamp: DateTime.now(),
        model: 'gpt-4',
        format: OutputFormat.markdown,
      );

      expect(history.format, equals(OutputFormat.markdown));
      expect(history.rawRequirements, equals('Test requirements'));
      expect(history.model, equals('gpt-4'));
    });

    test('should serialize and deserialize with format field', () {
      final originalHistory = GenerationHistory(
        rawRequirements: 'Test requirements',
        changes: 'Test changes',
        generatedTz: 'Test generated content',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        model: 'gpt-4',
        format: OutputFormat.confluence,
      );

      final json = originalHistory.toJson();
      final deserializedHistory = GenerationHistory.fromJson(json);

      expect(deserializedHistory.format, equals(OutputFormat.confluence));
      expect(deserializedHistory.rawRequirements, equals('Test requirements'));
      expect(deserializedHistory.changes, equals('Test changes'));
      expect(deserializedHistory.generatedTz, equals('Test generated content'));
      expect(deserializedHistory.model, equals('gpt-4'));
      expect(deserializedHistory.timestamp, equals(DateTime(2024, 1, 1, 12, 0, 0)));
    });

    test('should handle legacy data without format field', () {
      final legacyJson = {
        'rawRequirements': 'Legacy requirements',
        'changes': null,
        'generatedTz': 'Legacy content',
        'timestamp': '2024-01-01T12:00:00.000',
        'model': 'gpt-3.5',
        // No format field - simulating legacy data
      };

      final history = GenerationHistory.fromJson(legacyJson);

      expect(history.format, equals(OutputFormat.defaultFormat));
      expect(history.rawRequirements, equals('Legacy requirements'));
      expect(history.model, equals('gpt-3.5'));
    });

    test('should handle invalid format in JSON gracefully', () {
      final invalidJson = {
        'rawRequirements': 'Test requirements',
        'changes': null,
        'generatedTz': 'Test content',
        'timestamp': '2024-01-01T12:00:00.000',
        'model': 'gpt-4',
        'format': 'invalid_format', // Invalid format
      };

      final history = GenerationHistory.fromJson(invalidJson);

      expect(history.format, equals(OutputFormat.defaultFormat));
      expect(history.rawRequirements, equals('Test requirements'));
    });
  });
}