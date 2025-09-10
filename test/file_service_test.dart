import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/file_service.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('FileService', () {
    group('_validateContentForFormat', () {
      test('should validate Markdown content successfully', () {
        const validMarkdown = '''# Technical Specification

## 1. User Story
As a user, I want to create technical specifications.

## 2. Requirements
- Requirement 1
- Requirement 2

### 2.1 Detailed Requirements
Some detailed content here.
''';

        expect(
          () => FileService.validateContentForFormat(validMarkdown, OutputFormat.markdown),
          returnsNormally,
        );
      });

      test('should throw exception for empty Markdown content', () {
        expect(
          () => FileService.validateContentForFormat('', OutputFormat.markdown),
          throwsA(isA<FileExportException>()),
        );
      });

      test('should throw exception for Markdown with unprocessed escape markers', () {
        const invalidMarkdown = '''@@@START@@@
# Technical Specification
Some content
@@@END@@@''';

        expect(
          () => FileService.validateContentForFormat(invalidMarkdown, OutputFormat.markdown),
          throwsA(isA<FileExportException>()),
        );
      });

      test('should validate HTML content successfully', () {
        const validHtml = '''<h1>Technical Specification</h1>
<h2>Requirements</h2>
<p>Some content here</p>''';

        expect(
          () => FileService.validateContentForFormat(validHtml, OutputFormat.confluence),
          returnsNormally,
        );
      });

      test('should throw exception for HTML without headings', () {
        const invalidHtml = '<p>Just some text without headings</p>';

        expect(
          () => FileService.validateContentForFormat(invalidHtml, OutputFormat.confluence),
          throwsA(isA<FileExportException>()),
        );
      });
    });

    group('validateMarkdownContent', () {
      test('should add proper spacing around headings for third-party editor compatibility', () {
        const input = '''# Main Title
Some content
## Subtitle
More content
### Sub-subtitle
Final content''';

        final result = FileService.validateMarkdownContent(input);
        final lines = result.split('\n');

        // Check that headings have proper spacing
        expect(lines.contains(''), true, reason: 'Should contain blank lines for spacing');
      });

      test('should preserve existing proper spacing', () {
        const input = '''# Main Title

Some content

## Subtitle

More content''';

        final result = FileService.validateMarkdownContent(input);
        expect(result.contains('\n\n'), true, reason: 'Should preserve existing spacing');
      });

      test('should throw exception for content without headings', () {
        const input = '''Just some plain text
without any headings
or structure''';

        expect(
          () => FileService.validateMarkdownContent(input),
          throwsA(isA<FileExportException>()),
        );
      });

      test('should throw exception for content with only headings', () {
        const input = '''# Heading 1
## Heading 2
### Heading 3''';

        expect(
          () => FileService.validateMarkdownContent(input),
          throwsA(isA<FileExportException>()),
        );
      });
    });

    group('generateFilename', () {
      test('should generate Markdown filename with format identifier', () {
        final filename = FileService.generateFilename(OutputFormat.markdown, null);
        
        expect(filename, matches(r'TZ_MD_\d+\.md'));
      });

      test('should generate HTML filename with format identifier', () {
        final filename = FileService.generateFilename(OutputFormat.confluence, null);
        
        expect(filename, matches(r'TZ_HTML_\d+\.html'));
      });

      test('should use custom filename with correct extension', () {
        final filename = FileService.generateFilename(OutputFormat.markdown, 'custom_spec');
        
        expect(filename, equals('custom_spec.md'));
      });

      test('should correct extension in custom filename', () {
        final filename = FileService.generateFilename(OutputFormat.markdown, 'custom_spec.html');
        
        expect(filename, equals('custom_spec.md'));
      });

      test('should preserve correct extension in custom filename', () {
        final filename = FileService.generateFilename(OutputFormat.markdown, 'custom_spec.md');
        
        expect(filename, equals('custom_spec.md'));
      });
    });

    group('getDialogTitle', () {
      test('should return Markdown-specific dialog title', () {
        final title = FileService.getDialogTitle(OutputFormat.markdown);
        
        expect(title, equals('Сохранить техническое задание (Markdown)'));
      });

      test('should return HTML-specific dialog title', () {
        final title = FileService.getDialogTitle(OutputFormat.confluence);
        
        expect(title, equals('Сохранить техническое задание (HTML)'));
      });
    });

    group('performMarkdownStructureValidation', () {
      test('should pass validation for well-structured Markdown', () {
        const validMarkdown = '''# Technical Specification

## Overview
This is a technical specification document.

## Requirements
- Requirement 1
- Requirement 2

### Detailed Requirements
More detailed information here.
''';

        expect(
          () => FileService.performMarkdownStructureValidation(validMarkdown),
          returnsNormally,
        );
      });

      test('should throw exception for Markdown without headings', () {
        const invalidMarkdown = '''This is just plain text
without any headings
or proper structure.''';

        expect(
          () => FileService.performMarkdownStructureValidation(invalidMarkdown),
          throwsA(isA<FileExportException>()),
        );
      });

      test('should throw exception for Markdown with only headings', () {
        const invalidMarkdown = '''# Heading 1
## Heading 2
### Heading 3''';

        expect(
          () => FileService.performMarkdownStructureValidation(invalidMarkdown),
          throwsA(isA<FileExportException>()),
        );
      });

      test('should accept Markdown with mixed content types', () {
        const validMarkdown = '''# Technical Specification

## Code Example
```dart
void main() {
  print('Hello World');
}
```

## List Items
- Item 1
- Item 2

> This is a blockquote

**Bold text** and *italic text*.
''';

        expect(
          () => FileService.performMarkdownStructureValidation(validMarkdown),
          returnsNormally,
        );
      });
    });
  });

  group('FileExportException', () {
    test('should create exception with message', () {
      const message = 'Test error message';
      final exception = FileExportException(message);
      
      expect(exception.message, equals(message));
      expect(exception.toString(), equals('FileExportException: $message'));
    });
  });
}