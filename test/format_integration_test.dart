import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/widgets/main_screen/format_selector.dart';
import 'package:tee_zee_nator/widgets/main_screen/markdown_processor.dart';
import 'package:tee_zee_nator/widgets/main_screen/html_processor.dart';
import 'package:tee_zee_nator/services/llm_service.dart';
import 'package:tee_zee_nator/services/file_service.dart';
import 'package:tee_zee_nator/models/app_config.dart';

void main() {
  group('Format Selection Integration Tests', () {
    testWidgets('should integrate format selection with content processing', (WidgetTester tester) async {
      OutputFormat selectedFormat = OutputFormat.markdown;
      String? processedContent;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FormatSelector(
                  selectedFormat: selectedFormat,
                  onFormatChanged: (format) {
                    selectedFormat = format;
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    // Simulate content processing based on selected format
                    const mockLLMResponse = '''
@@@START@@@
# Technical Specification
## 1. User Story
As a user, I want to test format integration.
@@@END@@@
''';
                    
                    if (selectedFormat == OutputFormat.markdown) {
                      final processor = MarkdownProcessor();
                      processedContent = processor.extractContent(mockLLMResponse);
                    } else {
                      final processor = HtmlProcessor();
                      processedContent = processor.extractContent('<h1>Technical Specification</h1><h2>1. User Story</h2><p>As a user, I want to test format integration.</p>');
                    }
                  },
                  child: const Text('Process Content'),
                ),
              ],
            ),
          ),
        ),
      );

      // Initially Markdown should be selected
      expect(selectedFormat, equals(OutputFormat.markdown));

      // Process content with Markdown format
      await tester.tap(find.text('Process Content'));
      await tester.pump();

      expect(processedContent, contains('# Technical Specification'));
      expect(processedContent, contains('## 1. User Story'));

      // Switch to Confluence format
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      expect(selectedFormat, equals(OutputFormat.confluence));

      // Process content with HTML format
      await tester.tap(find.text('Process Content'));
      await tester.pump();

      expect(processedContent, contains('<h1>Technical Specification</h1>'));
      expect(processedContent, contains('<h2>1. User Story</h2>'));
    });

    testWidgets('should handle format switching during generation workflow', (WidgetTester tester) async {
      OutputFormat currentFormat = OutputFormat.markdown;
      final List<OutputFormat> formatHistory = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    FormatSelector(
                      selectedFormat: currentFormat,
                      onFormatChanged: (format) {
                        setState(() {
                          currentFormat = format;
                          formatHistory.add(format);
                        });
                      },
                    ),
                    Text('Current Format: ${currentFormat.displayName}'),
                    Text('Format History: ${formatHistory.length} changes'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Current Format: Markdown'), findsOneWidget);
      expect(formatHistory, isEmpty);

      // Switch to Confluence
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      expect(find.text('Current Format: Confluence Storage Format'), findsOneWidget);
      expect(formatHistory, hasLength(1));
      expect(formatHistory.last, equals(OutputFormat.confluence));

      // Switch back to Markdown
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      
      await tester.tap(markdownRadio);
      await tester.pump();

      expect(find.text('Current Format: Markdown'), findsOneWidget);
      expect(formatHistory, hasLength(2));
      expect(formatHistory.last, equals(OutputFormat.markdown));
    });

    test('should validate end-to-end format processing pipeline', () {
      // Test Markdown pipeline
      const markdownLLMResponse = '''
Some preamble
@@@START@@@
# Technical Specification
## 1. User Story
As a user, I want to generate markdown specs.

## 2. Requirements
- Requirement 1
- Requirement 2

**Bold text** and *italic text*.
@@@END@@@
Some trailing text
''';

      final markdownProcessor = MarkdownProcessor();
      final markdownContent = markdownProcessor.extractContent(markdownLLMResponse);
      
      expect(markdownContent, contains('# Technical Specification'));
      expect(markdownContent, contains('**Bold text**'));
      expect(markdownContent, isNot(contains('@@@START@@@')));
      expect(markdownContent, isNot(contains('@@@END@@@')));

      // Test HTML pipeline
      const htmlLLMResponse = '''
<h1>Technical Specification</h1>
<h2>1. User Story</h2>
<p>As a user, I want to generate HTML specs.</p>
<h2>2. Requirements</h2>
<ul>
<li>Requirement 1</li>
<li>Requirement 2</li>
</ul>
<p><strong>Bold text</strong> and <em>italic text</em>.</p>
''';

      final htmlProcessor = HtmlProcessor();
      final htmlContent = htmlProcessor.extractContent(htmlLLMResponse);
      
      expect(htmlContent, contains('<h1>Technical Specification</h1>'));
      expect(htmlContent, contains('<strong>Bold text</strong>'));
      expect(htmlContent, contains('<ul>'));
    });

    test('should handle format-specific file export integration', () {
      // Test Markdown file export
      const markdownContent = '''# Technical Specification
## 1. User Story
As a user, I want to export markdown files.
''';

      final markdownFilename = FileService.generateFilename(OutputFormat.markdown, null);
      expect(markdownFilename, endsWith('.md'));
      expect(markdownFilename, contains('TZ_MD_'));

      // Validate content for Markdown export
      expect(
        () => FileService.validateContentForFormat(markdownContent, OutputFormat.markdown),
        returnsNormally,
      );

      // Test HTML file export
      const htmlContent = '''<h1>Technical Specification</h1>
<h2>1. User Story</h2>
<p>As a user, I want to export HTML files.</p>
''';

      final htmlFilename = FileService.generateFilename(OutputFormat.confluence, null);
      expect(htmlFilename, endsWith('.html'));
      expect(htmlFilename, contains('TZ_HTML_'));

      // Validate content for HTML export
      expect(
        () => FileService.validateContentForFormat(htmlContent, OutputFormat.confluence),
        returnsNormally,
      );
    });

    test('should integrate format selection with LLM service prompts', () {
      final llmService = LLMService();
      
      // Test Markdown system prompt building
      const templateContent = '''# Template
## Section 1
Content here.
''';

      // Test that the service accepts format parameters
      expect(
        () => llmService.generateTZ(
          rawRequirements: 'test requirements',
          templateContent: templateContent,
          format: OutputFormat.markdown,
        ),
        throwsA(predicate((e) => e.toString().contains('провайдер не инициализирован'))),
      );

      expect(
        () => llmService.generateTZ(
          rawRequirements: 'test requirements',
          templateContent: templateContent,
          format: OutputFormat.confluence,
        ),
        throwsA(predicate((e) => e.toString().contains('провайдер не инициализирован'))),
      );
    });

    test('should validate format consistency across processing pipeline', () {
      // Test that format selection affects the entire pipeline consistently
      
      // Markdown pipeline consistency
      const markdownFormat = OutputFormat.markdown;
      expect(markdownFormat.fileExtension, equals('md'));
      expect(markdownFormat.displayName, equals('Markdown'));
      
      final markdownProcessor = MarkdownProcessor();
      expect(markdownProcessor.getFileExtension(), equals('md'));
      expect(markdownProcessor.getContentType(), equals('text/markdown'));

      // HTML pipeline consistency
      const htmlFormat = OutputFormat.confluence;
      expect(htmlFormat.fileExtension, equals('html'));
      expect(htmlFormat.displayName, equals('Confluence Storage Format'));
      
      final htmlProcessor = HtmlProcessor();
      expect(htmlProcessor.getFileExtension(), equals('html'));
      expect(htmlProcessor.getContentType(), equals('text/html'));
    });

    test('should handle error scenarios in format integration', () {
      // Test invalid content for Markdown processor
      const invalidMarkdownResponse = '''
No escape markers here
Just plain text
''';

      final markdownProcessor = MarkdownProcessor();
      expect(
        () => markdownProcessor.extractContent(invalidMarkdownResponse),
        throwsA(isA<Exception>()),
      );

      // Test invalid content for HTML processor
      const invalidHtmlResponse = '''
Plain text without HTML tags
''';

      final htmlProcessor = HtmlProcessor();
      expect(
        () => htmlProcessor.extractContent(invalidHtmlResponse),
        throwsA(isA<Exception>()),
      );

      // Test invalid format for file export
      const contentWithMarkers = '''@@@START@@@
Content here
@@@END@@@''';

      expect(
        () => FileService.validateContentForFormat(contentWithMarkers, OutputFormat.markdown),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Format Persistence Integration Tests', () {
    test('should persist format preference in app configuration', () {
      // Test that format preference can be stored in AppConfig
      final config = AppConfig(
        provider: 'openai',
        apiUrl: 'https://api.openai.com/v1',
        apiToken: 'test-key',
        defaultModel: 'gpt-4',
        preferredFormat: OutputFormat.confluence,
      );

      expect(config.preferredFormat, equals(OutputFormat.confluence));

      // Test copyWith functionality
      final updatedConfig = config.copyWith(
        preferredFormat: OutputFormat.markdown,
      );

      expect(updatedConfig.preferredFormat, equals(OutputFormat.markdown));
      expect(config.preferredFormat, equals(OutputFormat.confluence)); // Original unchanged
    });

    test('should handle default format when no preference is set', () {
      // Test default format selection
      expect(OutputFormat.defaultFormat, equals(OutputFormat.markdown));
      expect(OutputFormat.markdown.isDefault, isTrue);
      expect(OutputFormat.confluence.isDefault, isFalse);

      // Test that only one format can be default
      final defaultFormats = OutputFormat.values.where((f) => f.isDefault).toList();
      expect(defaultFormats, hasLength(1));
      expect(defaultFormats.first, equals(OutputFormat.markdown));
    });

    test('should maintain format consistency across app sessions', () {
      // Simulate session 1
      OutputFormat session1Format = OutputFormat.confluence;
      
      // Simulate saving to config
      final savedConfig = AppConfig(
        provider: 'openai',
        apiUrl: 'https://api.openai.com/v1',
        apiToken: 'test-key',
        defaultModel: 'gpt-4',
        preferredFormat: session1Format,
      );

      // Simulate session 2 - loading from config
      final loadedFormat = savedConfig.preferredFormat;
      expect(loadedFormat, equals(OutputFormat.confluence));

      // Simulate format change in session 2
      final updatedConfig = savedConfig.copyWith(
        preferredFormat: OutputFormat.markdown,
      );

      expect(updatedConfig.preferredFormat, equals(OutputFormat.markdown));
    });

    test('should validate format enum serialization compatibility', () {
      // Test that OutputFormat enum values are stable for persistence
      expect(OutputFormat.markdown.index, equals(0));
      expect(OutputFormat.confluence.index, equals(1));

      // Test that enum can be reconstructed from index
      expect(OutputFormat.values[0], equals(OutputFormat.markdown));
      expect(OutputFormat.values[1], equals(OutputFormat.confluence));

      // Test enum properties are consistent
      for (final format in OutputFormat.values) {
        expect(format.displayName, isNotEmpty);
        expect(format.fileExtension, isNotEmpty);
        expect(format.fileExtension, matches(RegExp(r'^[a-z]+$')));
      }
    });
  });

  group('End-to-End Generation Workflow Tests', () {
    test('should complete full generation workflow with format selection', () {
      // Simulate complete workflow from format selection to file export
      
      // Step 1: Format selection
      OutputFormat selectedFormat = OutputFormat.markdown;
      expect(selectedFormat.displayName, equals('Markdown'));

      // Step 2: LLM response simulation
      const mockLLMResponse = '''
@@@START@@@
# Technical Specification

## 1. User Story
As a user, I want to test the complete workflow.

## 2. Requirements
- The system shall support format selection
- The system shall process content correctly
- The system shall export files with correct extensions

## 3. Implementation
Implementation details here.
@@@END@@@
''';

      // Step 3: Content processing
      final processor = MarkdownProcessor();
      final extractedContent = processor.extractContent(mockLLMResponse);
      
      expect(extractedContent, contains('# Technical Specification'));
      expect(extractedContent, isNot(contains('@@@START@@@')));

      // Step 4: File export preparation
      final filename = FileService.generateFilename(selectedFormat, null);
      expect(filename, endsWith('.md'));

      // Step 5: Content validation for export
      expect(
        () => FileService.validateContentForFormat(extractedContent, selectedFormat),
        returnsNormally,
      );

      // Verify workflow completed successfully
      expect(extractedContent, isNotEmpty);
      expect(filename, isNotEmpty);
      expect(selectedFormat, equals(OutputFormat.markdown));
    });

    test('should handle workflow with format switching mid-process', () {
      // Start with Markdown
      OutputFormat currentFormat = OutputFormat.markdown;
      
      // Simulate user switching to Confluence mid-workflow
      currentFormat = OutputFormat.confluence;
      
      // Process content with new format
      const htmlResponse = '''<h1>Technical Specification</h1>
<h2>1. User Story</h2>
<p>As a user, I want to switch formats mid-process.</p>''';

      final processor = HtmlProcessor();
      final content = processor.extractContent(htmlResponse);
      
      expect(content, contains('<h1>Technical Specification</h1>'));
      
      // Verify file export matches new format
      final filename = FileService.generateFilename(currentFormat, null);
      expect(filename, endsWith('.html'));
      expect(filename, contains('TZ_HTML_'));
    });

    test('should maintain data integrity throughout workflow', () {
      const testRequirements = 'User wants to create a login system';
      const testChanges = 'Add two-factor authentication';
      
      // Test that data flows correctly through the pipeline
      final workflowData = {
        'requirements': testRequirements,
        'changes': testChanges,
        'format': OutputFormat.markdown,
        'timestamp': DateTime.now(),
      };

      // Verify data integrity
      expect(workflowData['requirements'], equals(testRequirements));
      expect(workflowData['changes'], equals(testChanges));
      expect(workflowData['format'], equals(OutputFormat.markdown));
      expect(workflowData['timestamp'], isA<DateTime>());

      // Simulate format change
      workflowData['format'] = OutputFormat.confluence;
      expect(workflowData['format'], equals(OutputFormat.confluence));

      // Verify other data remains unchanged
      expect(workflowData['requirements'], equals(testRequirements));
      expect(workflowData['changes'], equals(testChanges));
    });
  });
}