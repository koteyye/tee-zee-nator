import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import '../lib/widgets/main_screen/input_panel.dart';
import '../lib/services/config_service.dart';
import '../lib/services/confluence_service.dart';
import '../lib/services/confluence_content_processor.dart';
import '../lib/services/confluence_session_manager.dart';
import '../lib/models/confluence_config.dart';
import '../lib/models/generation_history.dart';
import '../lib/models/output_format.dart';

@GenerateMocks([ConfigService, ConfluenceService])
import 'input_panel_memory_management_test.mocks.dart';

void main() {
  group('InputPanel Memory Management', () {
    late MockConfigService mockConfigService;
    late MockConfluenceService mockConfluenceService;
    late ConfluenceConfig testConfig;
    late TextEditingController rawRequirementsController;
    late TextEditingController changesController;

    setUp(() {
      mockConfigService = MockConfigService();
      mockConfluenceService = MockConfluenceService();
      
      testConfig = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
      
      rawRequirementsController = TextEditingController();
      changesController = TextEditingController();
      
      // Setup mock responses
      when(mockConfigService.getConfluenceConfig()).thenReturn(testConfig);
      when(mockConfigService.isConfluenceEnabled()).thenReturn(true);
    });

    tearDown(() {
      rawRequirementsController.dispose();
      changesController.dispose();
    });

    Widget createTestWidget({
      required VoidCallback onGenerate,
      required VoidCallback onClear,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ConfigService>.value(
            value: mockConfigService,
            child: InputPanel(
              rawRequirementsController: rawRequirementsController,
              changesController: changesController,
              generatedTz: '',
              history: const [],
              isGenerating: false,
              errorMessage: null,
              onGenerate: onGenerate,
              onClear: onClear,
              onHistoryItemTap: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('should clear all data when Clear button is pressed', (WidgetTester tester) async {
      // Arrange
      bool onClearCalled = false;
      bool onGenerateCalled = false;
      
      await tester.pumpWidget(createTestWidget(
        onGenerate: () => onGenerateCalled = true,
        onClear: () => onClearCalled = true,
      ));
      
      // Add some text to the controllers
      rawRequirementsController.text = 'Test requirements with https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      changesController.text = 'Test changes';
      
      await tester.pump();
      
      // Act - Find and tap the Clear button
      final clearButton = find.widgetWithText(ElevatedButton, 'Очистить');
      expect(clearButton, findsOneWidget);
      
      await tester.tap(clearButton);
      await tester.pump();
      
      // Assert
      expect(onClearCalled, isTrue);
      // Note: We can't directly test the internal state clearing without exposing it,
      // but we can verify the callback was called
    });

    testWidgets('should initialize session manager when Confluence is configured', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(
        onGenerate: () {},
        onClear: () {},
      ));
      
      // Act - Widget should initialize automatically
      await tester.pump();
      
      // Assert - Session manager should be initialized
      final sessionManager = ConfluenceSessionManager();
      final stats = sessionManager.getMemoryStats();
      expect(stats['isInitialized'], isTrue);
    });

    testWidgets('should handle disposal properly', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget(
        onGenerate: () {},
        onClear: () {},
      ));
      
      await tester.pump();
      
      // Act - Dispose the widget by navigating away
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('New Page'))));
      await tester.pump();
      
      // Assert - Should not throw any exceptions during disposal
      // The actual cleanup verification would require access to internal state
    });

    testWidgets('should process Confluence links and manage memory', (WidgetTester tester) async {
      // Arrange
      when(mockConfluenceService.getPageContent('123456'))
          .thenAnswer((_) async => 'Test page content');
      
      await tester.pumpWidget(createTestWidget(
        onGenerate: () {},
        onClear: () {},
      ));
      
      await tester.pump();
      
      // Act - Enter text with Confluence link
      await tester.enterText(
        find.byType(TextField).first,
        'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test',
      );
      
      // Wait for debounce and processing
      await tester.pump(const Duration(milliseconds: 600));
      
      // Assert - Text should be entered (processing happens in background)
      expect(rawRequirementsController.text, contains('https://test.atlassian.net'));
    });

    testWidgets('should show processing indicators during link processing', (WidgetTester tester) async {
      // Arrange
      when(mockConfluenceService.getPageContent('123456'))
          .thenAnswer((_) async {
            // Simulate slow response
            await Future.delayed(const Duration(milliseconds: 100));
            return 'Test page content';
          });
      
      await tester.pumpWidget(createTestWidget(
        onGenerate: () {},
        onClear: () {},
      ));
      
      await tester.pump();
      
      // Act - Enter text with Confluence link
      await tester.enterText(
        find.byType(TextField).first,
        'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test',
      );
      
      // Wait for debounce to trigger processing
      await tester.pump(const Duration(milliseconds: 600));
      
      // Assert - Should show processing indicator
      // Note: The exact widget finder depends on the implementation
      // This test verifies the structure exists for showing processing state
      expect(find.text('Обработка ссылок...'), findsWidgets);
    });
  });

  group('Memory Management Integration Tests', () {
    testWidgets('should coordinate with session manager for cleanup', (WidgetTester tester) async {
      // Arrange
      final mockConfigService = MockConfigService();
      final testConfig = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
      
      when(mockConfigService.getConfluenceConfig()).thenReturn(testConfig);
      when(mockConfigService.isConfluenceEnabled()).thenReturn(true);
      
      final rawController = TextEditingController();
      final changesController = TextEditingController();
      
      bool clearCalled = false;
      
      final widget = MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ConfigService>.value(
            value: mockConfigService,
            child: InputPanel(
              rawRequirementsController: rawController,
              changesController: changesController,
              generatedTz: '',
              history: const [],
              isGenerating: false,
              errorMessage: null,
              onGenerate: () {},
              onClear: () => clearCalled = true,
              onHistoryItemTap: (_) {},
            ),
          ),
        ),
      );
      
      await tester.pumpWidget(widget);
      await tester.pump();
      
      // Act - Trigger cleanup through session manager
      final sessionManager = ConfluenceSessionManager();
      sessionManager.triggerCleanup(fullCleanup: true);
      
      // Assert - Should not throw exceptions
      expect(sessionManager.getMemoryStats()['isInitialized'], isTrue);
      
      // Cleanup
      rawController.dispose();
      changesController.dispose();
    });
  });
}