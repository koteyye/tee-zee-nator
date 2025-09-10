import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/widgets/main_screen/markdown_processor.dart';
import 'package:tee_zee_nator/exceptions/content_processing_exceptions.dart';

void main() {
  group('MarkdownProcessor', () {
    late MarkdownProcessor processor;

    setUp(() {
      processor = MarkdownProcessor();
    });

    group('Interface Implementation', () {
      test('should return correct file extension', () {
        expect(processor.getFileExtension(), equals('md'));
      });

      test('should return correct content type', () {
        expect(processor.getContentType(), equals('text/markdown'));
      });
    });

    group('extractContent', () {
      test('should extract content between valid escape markers', () {
        const input = '''
Some preamble text
@@@START@@@
# Technical Specification
## 1. User Story
This is markdown content.
@@@END@@@
Some trailing text
''';
        
        final result = processor.extractContent(input);
        expect(result, equals('# Technical Specification\n## 1. User Story\nThis is markdown content.'));
      });

      test('should handle content with extra whitespace around markers', () {
        const input = '''
@@@START@@@   
  # Technical Specification  
  ## 1. User Story  
  This is markdown content.  
   @@@END@@@
''';
        
        final result = processor.extractContent(input);
        expect(result, equals('# Technical Specification  \n  ## 1. User Story  \n  This is markdown content.'));
      });

      test('should throw exception for empty content between markers', () {
        const input = '''
@@@START@@@
   
@@@END@@@
''';
        
        expect(
          () => processor.extractContent(input),
          throwsA(isA<ContentProcessingException>()
              .having((e) => e.message, 'message', contains('пуст'))),
        );
      });

      test('should throw exception for malformed escape markers', () {
        const input = '''
@@@START@@@
# Technical Specification
Missing end marker
''';
        
        expect(
          () => processor.extractContent(input),
          throwsA(isA<ContentProcessingException>()
              .having((e) => e.message, 'message', contains('не найден'))),
        );
      });

      test('should throw exception when no escape markers found', () {
        const input = '''
# Technical Specification
## 1. User Story
This content has no markers.
''';
        
        expect(
          () => processor.extractContent(input),
          throwsA(isA<ContentProcessingException>()
              .having((e) => e.message, 'message', contains('не найдены'))),
        );
      });

      test('should reject multiple marker pairs', () {
        const input = '''
@@@START@@@
# First Content
@@@END@@@
@@@START@@@
# Second Content
@@@END@@@
''';
        
        expect(
          () => processor.extractContent(input),
          throwsA(isA<EscapeMarkerException>()
              .having((e) => e.message, 'message', contains('слишком много маркеров'))),
        );
      });
    });

    group('extractMarkdown static method', () {
      test('should extract valid markdown content', () {
        const input = '''
@@@START@@@
# Technical Specification

## 1. User Story
As a user, I want to generate markdown.

## 2. Requirements
- Requirement 1
- Requirement 2

**Bold text** and *italic text*.

```dart
void main() {
  print('Hello World');
}
```
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('# Technical Specification'));
        expect(result, contains('## 1. User Story'));
        expect(result, contains('**Bold text**'));
        expect(result, contains('```dart'));
      });

      test('should remove disallowed HTML tags', () {
        const input = '''
@@@START@@@
# Technical Specification

<div>This div should be removed</div>
<p>This paragraph should be removed</p>
<span>This span should be removed</span>

But <code>this code</code> should remain.
And <strong>this strong</strong> should remain.
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, isNot(contains('<div>')));
        expect(result, isNot(contains('<p>')));
        expect(result, isNot(contains('<span>')));
        expect(result, contains('<code>this code</code>'));
        expect(result, contains('<strong>this strong</strong>'));
      });

      test('should clean HTML entities', () {
        const input = '''
@@@START@@@
# Technical Specification

&lt;script&gt; should become <script>
&amp; should become &
&quot;quotes&quot; should become "quotes"
&#39;apostrophe&#39; should become 'apostrophe'
&nbsp; should become space
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('<script>'));
        expect(result, contains('&'));
        expect(result, contains('"quotes"'));
        expect(result, contains("'apostrophe'"));
        expect(result, contains(' should become space'));
      });

      test('should handle content with only plain text', () {
        const input = '''
@@@START@@@
This is just plain text without any markdown formatting.
It should still be processed successfully.
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, equals('This is just plain text without any markdown formatting.\nIt should still be processed successfully.'));
      });

      test('should handle content with mixed markdown elements', () {
        const input = '''
@@@START@@@
# Main Header

## Sub Header

### Sub-sub Header

- List item 1
- List item 2
  - Nested item

1. Numbered item 1
2. Numbered item 2

> This is a blockquote

`inline code` and **bold** and *italic*

```javascript
function test() {
  return true;
}
```

[Link text](https://example.com)

![Image alt](image.png)
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('# Main Header'));
        expect(result, contains('## Sub Header'));
        expect(result, contains('### Sub-sub Header'));
        expect(result, contains('- List item 1'));
        expect(result, contains('1. Numbered item 1'));
        expect(result, contains('> This is a blockquote'));
        expect(result, contains('`inline code`'));
        expect(result, contains('**bold**'));
        expect(result, contains('*italic*'));
        expect(result, contains('```javascript'));
        expect(result, contains('[Link text](https://example.com)'));
        expect(result, contains('![Image alt](image.png)'));
      });
    });

    group('Edge Cases', () {
      test('should handle markers with different casing', () {
        const input = '''
@@@start@@@
# Content
@@@end@@@
''';
        
        expect(
          () => MarkdownProcessor.extractMarkdown(input),
          throwsA(isA<ContentProcessingException>()),
        );
      });

      test('should handle markers with extra characters', () {
        const input = '''
Some text before
@@@START@@@ extra text after marker
# Content
@@@END@@@ extra text after marker
Some text after
''';
        
        // The improved implementation should extract content successfully
        // even with extra text after markers
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('# Content'));
      });

      test('should reject nested markers', () {
        const input = '''
@@@START@@@
# Content
@@@START@@@
Nested content
@@@END@@@
More content
@@@END@@@
''';
        
        expect(
          () => MarkdownProcessor.extractMarkdown(input),
          throwsA(isA<EscapeMarkerException>()
              .having((e) => e.message, 'message', contains('слишком много маркеров'))),
        );
      });

      test('should handle very large content', () {
        final largeContent = List.generate(1000, (i) => '# Header $i\nContent $i\n').join('\n');
        final input = '@@@START@@@\n$largeContent\n@@@END@@@';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result.length, greaterThan(10000));
        expect(result, contains('# Header 0'));
        expect(result, contains('# Header 999'));
      });

      test('should handle content with special characters', () {
        const input = '''
@@@START@@@
# Special Characters: !@#\$%^&*()_+-={}[]|\\:";'<>?,./

Unicode: 你好 🌟 ñáéíóú

Markdown escapes: \\* \\_ \\# \\`
@@@END@@@
''';
        
        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('!@#\$%^&*()_+-={}[]|\\:";\'<>?,./'));
        expect(result, contains('你好 🌟 ñáéíóú'));
        expect(result, contains('\\* \\_ \\# \\`'));
      });

      test('should handle malformed LLM responses', () {
        const malformedInputs = [
          // Missing start marker
          '''
# Content without start marker
@@@END@@@
''',
          // Missing end marker
          '''
@@@START@@@
# Content without end marker
''',
          // Reversed markers
          '''
@@@END@@@
# Content with reversed markers
@@@START@@@
''',
          // Multiple start markers
          '''
@@@START@@@
@@@START@@@
# Content with multiple start markers
@@@END@@@
''',
          // Empty content
          '''
@@@START@@@


@@@END@@@
''',
        ];

        for (final input in malformedInputs) {
          expect(
            () => MarkdownProcessor.extractMarkdown(input),
            throwsA(isA<ContentProcessingException>()),
            reason: 'Should throw exception for malformed input: $input',
          );
        }
      });

      test('should handle various whitespace scenarios', () {
        const scenarios = [
          // Tabs and spaces mixed
          '''
@@@START@@@
\t# Header with tab
    ## Header with spaces
\t\t- List item with tabs
@@@END@@@
''',
          // Windows line endings
          '''
@@@START@@@\r\n# Windows Line Endings\r\n## Content here\r\n@@@END@@@
''',
          // Mixed line endings
          '''
@@@START@@@\n# Mixed\r\n## Line Endings\n@@@END@@@
''',
        ];

        for (final scenario in scenarios) {
          final result = MarkdownProcessor.extractMarkdown(scenario);
          expect(result, isNotEmpty);
          expect(result, contains('#'));
        }
      });

      test('should handle content with code blocks and special formatting', () {
        const input = '''
@@@START@@@
# Technical Specification

## Code Examples

```dart
void main() {
  print("Hello World");
}
```

```json
{
  "content": "test data",
  "format": "markdown"
}
```

## Inline Code
Use backticks for `inline code` formatting.

## Tables
| Column 1 | Column 2 |
|----------|----------|
| Data 1 | Data 2 |

## Links
[External Link](https://example.com)

## Formatting
**Bold text** and *italic text* work correctly.
@@@END@@@
''';

        final result = MarkdownProcessor.extractMarkdown(input);
        expect(result, contains('```dart'));
        expect(result, contains('```json'));
        expect(result, contains('`inline code`'));
        expect(result, contains('| Data 1 | Data 2 |'));
        expect(result, contains('[External Link](https://example.com)'));
        expect(result, contains('**Bold text**'));
        expect(result, contains('*italic text*'));
      });

      test('should handle performance with deeply nested content', () {
        final nestedContent = StringBuffer();
        nestedContent.writeln('@@@START@@@');
        
        // Create deeply nested structure
        for (int i = 1; i <= 100; i++) {
          nestedContent.writeln('${'#' * (i % 6 + 1)} Header Level $i');
          nestedContent.writeln('Content for section $i');
          if (i % 10 == 0) {
            nestedContent.writeln('```code');
            nestedContent.writeln('Code block $i');
            nestedContent.writeln('```');
          }
        }
        
        nestedContent.writeln('@@@END@@@');
        
        final stopwatch = Stopwatch()..start();
        final result = MarkdownProcessor.extractMarkdown(nestedContent.toString());
        stopwatch.stop();
        
        expect(result, contains('# Header Level 1'));
        expect(result, contains('## Header Level 2'));
        expect(result, contains('Code block 10'));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should process quickly
      });
    });

    group('MarkdownProcessingException', () {
      test('should have correct message', () {
        const exception = MarkdownProcessingException('Test message');
        expect(exception.message, equals('Test message'));
        expect(exception.toString(), equals('MarkdownProcessingException: Test message'));
      });
    });
  });
}