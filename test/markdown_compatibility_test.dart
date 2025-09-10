import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/file_service.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('Markdown Third-Party Editor Compatibility', () {
    test('should generate VSCode-compatible Markdown structure', () {
      const sampleContent = '''# Technical Specification
## 1. User Story
As a user, I want to create technical specifications.
## 2. Requirements
### 2.1 Functional Requirements
- Requirement 1
- Requirement 2
### 2.2 Non-Functional Requirements
- Performance requirement
- Security requirement
## 3. Implementation Details
```dart
void main() {
  print('Hello World');
}
```
## 4. Testing Strategy
> This is important for testing
**Bold text** and *italic text* should work.''';

      final validatedContent = FileService.validateMarkdownContent(sampleContent);
      
      // Check that content has proper structure for VSCode preview
      expect(validatedContent, contains('# Technical Specification'));
      expect(validatedContent, contains('## 1. User Story'));
      expect(validatedContent, contains('### 2.1 Functional Requirements'));
      expect(validatedContent, contains('```dart'));
      expect(validatedContent, contains('> This is important'));
      expect(validatedContent, contains('**Bold text**'));
      expect(validatedContent, contains('*italic text*'));
      
      // Verify proper spacing around headings - the validateMarkdownContent method adds spacing
      final lines = validatedContent.split('\n');
      bool hasBlankLines = false;
      
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) {
          hasBlankLines = true;
          break;
        }
      }
      
      expect(hasBlankLines, true, reason: 'Should have blank lines for proper spacing and VSCode compatibility');
    });

    test('should generate Obsidian-compatible Markdown structure', () {
      const sampleContent = '''# Technical Specification

## Overview
This document describes the technical specification.

## Requirements
- [ ] Task 1
- [x] Task 2 (completed)
- [ ] Task 3

## Code Examples
```javascript
function example() {
  return "Hello World";
}
```

## Links and References
[External Link](https://example.com)

## Tables
| Feature | Status | Priority |
|---------|--------|----------|
| Feature 1 | Done | High |
| Feature 2 | In Progress | Medium |

## Math (if supported)
The formula is: `E = mc²`
''';

      final validatedContent = FileService.validateMarkdownContent(sampleContent);
      
      // Check Obsidian-specific features
      expect(validatedContent, contains('- [ ] Task 1'));
      expect(validatedContent, contains('- [x] Task 2'));
      expect(validatedContent, contains('| Feature | Status | Priority |'));
      expect(validatedContent, contains('[External Link](https://example.com)'));
      expect(validatedContent, contains('`E = mc²`'));
      
      // Verify structure is maintained
      expect(validatedContent, contains('# Technical Specification'));
      expect(validatedContent, contains('## Overview'));
      expect(validatedContent, contains('```javascript'));
    });

    test('should handle complex nested structures for editor compatibility', () {
      const complexContent = '''# Main Document

## Section 1
### Subsection 1.1
Content here.

#### Sub-subsection 1.1.1
More detailed content.

### Subsection 1.2
Different content.

## Section 2
### Code Examples
```python
def hello_world():
    print("Hello, World!")
    
if __name__ == "__main__":
    hello_world()
```

### Lists and Formatting
1. First item
   - Nested bullet
   - Another nested bullet
2. Second item
   1. Nested numbered
   2. Another nested numbered

**Important:** This is bold text.
*Emphasis:* This is italic text.

> This is a blockquote
> that spans multiple lines
> for better readability.

### Tables
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data 1   | Data 2   | Data 3   |
| Data 4   | Data 5   | Data 6   |

## Conclusion
Final thoughts here.
''';

      final validatedContent = FileService.validateMarkdownContent(complexContent);
      
      // Verify all structural elements are preserved
      expect(validatedContent, contains('# Main Document'));
      expect(validatedContent, contains('## Section 1'));
      expect(validatedContent, contains('### Subsection 1.1'));
      expect(validatedContent, contains('#### Sub-subsection 1.1.1'));
      expect(validatedContent, contains('```python'));
      expect(validatedContent, contains('1. First item'));
      expect(validatedContent, contains('   - Nested bullet'));
      expect(validatedContent, contains('**Important:**'));
      expect(validatedContent, contains('*Emphasis:*'));
      expect(validatedContent, contains('> This is a blockquote'));
      expect(validatedContent, contains('| Column 1 | Column 2 | Column 3 |'));
      
      // Verify no HTML remnants
      expect(validatedContent, isNot(contains('<div>')));
      expect(validatedContent, isNot(contains('<span>')));
      expect(validatedContent, isNot(contains('<p>')));
    });

    test('should validate file extension compatibility', () {
      // Test Markdown format
      final markdownFilename = FileService.generateFilename(OutputFormat.markdown, null);
      expect(markdownFilename, endsWith('.md'));
      
      // Test HTML format
      final htmlFilename = FileService.generateFilename(OutputFormat.confluence, null);
      expect(htmlFilename, endsWith('.html'));
      
      // Test custom filename correction
      final correctedFilename = FileService.generateFilename(OutputFormat.markdown, 'spec.txt');
      expect(correctedFilename, equals('spec.md'));
    });

    test('should generate proper format identifiers in filenames', () {
      final markdownFilename = FileService.generateFilename(OutputFormat.markdown, null);
      expect(markdownFilename, contains('TZ_MD_'));
      
      final htmlFilename = FileService.generateFilename(OutputFormat.confluence, null);
      expect(htmlFilename, contains('TZ_HTML_'));
    });

    test('should validate content structure for export compatibility', () {
      // Test valid Markdown content
      const validMarkdown = '''# Technical Specification

## Requirements
This section contains requirements.

### Functional Requirements
- Requirement 1
- Requirement 2

## Implementation
Implementation details here.
''';

      expect(
        () => FileService.validateContentForFormat(validMarkdown, OutputFormat.markdown),
        returnsNormally,
      );

      // Test invalid content (only headings)
      const invalidMarkdown = '''# Heading 1
## Heading 2
### Heading 3''';

      expect(
        () => FileService.validateContentForFormat(invalidMarkdown, OutputFormat.markdown),
        throwsA(isA<FileExportException>()),
      );

      // Test content with unprocessed markers
      const unprocessedContent = '''@@@START@@@
# Technical Specification
Content here
@@@END@@@''';

      expect(
        () => FileService.validateContentForFormat(unprocessedContent, OutputFormat.markdown),
        throwsA(isA<FileExportException>()),
      );
    });
  });
}