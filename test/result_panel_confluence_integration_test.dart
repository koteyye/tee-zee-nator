import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';

import 'package:tee_zee_nator/widgets/main_screen/result_panel.dart';
import 'package:tee_zee_nator/services/config_service.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

import 'result_panel_confluence_integration_test.mocks.dart';

@GenerateMocks([ConfigService, ConfluenceService])
void main() {
  group('ResultPanel Confluence Integration', () {
    late MockConfigService mockConfigService;
    late MockConfluenceService mockConfluenceService;

    setUp(() {
      mockConfigService = MockConfigService();
      mockConfluenceService = MockConfluenceService();
    });

    Widget createTestWidget({
      String generatedTz = 'Test content',
      VoidCallback? onSave,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConfigService>.value(value: mockConfigService),
              ChangeNotifierProvider<ConfluenceService>.value(value: mockConfluenceService),
            ],
            child: ResultPanel(
              generatedTz: generatedTz,
              onSave: onSave ?? () {},
            ),
          ),
        ),
      );
    }

    group('Publish to Confluence Button Visibility', () {
      testWidgets('shows publish button when Confluence is enabled and mode is Markdown', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byKey(const Key('publish_to_confluence_button')), findsOneWidget);
        expect(find.text('Publish to Confluence'), findsOneWidget);
        expect(find.byIcon(Icons.publish), findsOneWidget);
      });

      testWidgets('hides publish button when Confluence is disabled', (tester) async {
        // Arrange
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: null,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(false);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);
        expect(find.text('Publish to Confluence'), findsNothing);
      });

      testWidgets('hides publish button when mode is not Markdown', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.confluence,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);
        expect(find.text('Publish to Confluence'), findsNothing);
      });

      testWidgets('hides publish button when Confluence is enabled but invalid', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: false, // Invalid connection
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(false); // Service returns false for invalid config

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);
        expect(find.text('Publish to Confluence'), findsNothing);
      });

      testWidgets('hides publish button when no content is generated', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget(generatedTz: ''));

        // Assert
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);
        expect(find.text('Publish to Confluence'), findsNothing);
      });
    });

    group('Publish Button Interaction', () {
      testWidgets('button is tappable when conditions are met', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget(generatedTz: 'Test markdown content'));
        await tester.pumpAndSettle();

        // Assert - Button should be present and enabled
        final button = find.byKey(const Key('publish_to_confluence_button'));
        expect(button, findsOneWidget);
        
        final buttonWidget = tester.widget<ElevatedButton>(button);
        expect(buttonWidget.onPressed, isNotNull); // Button should be enabled
      });
    });

    group('Button Styling and Accessibility', () {
      testWidgets('publish button has correct styling', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert
        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('publish_to_confluence_button')),
        );
        
        expect(button.style?.backgroundColor?.resolve({}), equals(Colors.blue));
        expect(button.style?.foregroundColor?.resolve({}), equals(Colors.white));
        
        // Check icon and text are present
        expect(find.descendant(
          of: find.byKey(const Key('publish_to_confluence_button')),
          matching: find.byIcon(Icons.publish),
        ), findsOneWidget);
        
        expect(find.descendant(
          of: find.byKey(const Key('publish_to_confluence_button')),
          matching: find.text('Publish to Confluence'),
        ), findsOneWidget);
      });

      testWidgets('publish button is accessible', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - Button should be semantically accessible
        final button = find.byKey(const Key('publish_to_confluence_button'));
        expect(button, findsOneWidget);
        
        // Verify the button can be found by semantic label
        expect(find.text('Publish to Confluence'), findsOneWidget);
      });
    });

    group('Integration with Other Buttons', () {
      testWidgets('publish button appears alongside other action buttons', (tester) async {
        // Arrange
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - All buttons should be present
        expect(find.text('Скопировать в буфер'), findsOneWidget);
        expect(find.text('Сохранить .md'), findsOneWidget);
        expect(find.text('Publish to Confluence'), findsOneWidget);
        
        // Verify all buttons are present in the UI
        expect(find.byKey(const Key('publish_to_confluence_button')), findsOneWidget);
      });

      testWidgets('button layout remains consistent when Confluence is disabled', (tester) async {
        // Arrange
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: null,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(false);

        // Act
        await tester.pumpWidget(createTestWidget());

        // Assert - Only original buttons should be present
        expect(find.text('Скопировать в буфер'), findsOneWidget);
        expect(find.text('Сохранить .md'), findsOneWidget);
        expect(find.text('Publish to Confluence'), findsNothing);
        
        // Layout should still work correctly
        expect(find.text('Скопировать в буфер'), findsOneWidget);
        expect(find.text('Сохранить .md'), findsOneWidget);
      });
    });

    group('Dynamic State Changes', () {
      testWidgets('button appears when Confluence is enabled dynamically', (tester) async {
        // Arrange - Start with Confluence disabled
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: null,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(false);

        await tester.pumpWidget(createTestWidget());
        
        // Assert - Button should not be present initially
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);

        // Act - Enable Confluence
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final updatedConfig = appConfig.copyWith(confluenceConfig: confluenceConfig);
        when(mockConfigService.config).thenReturn(updatedConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);
        
        // Rebuild the widget with new config
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - Button should now be present
        expect(find.byKey(const Key('publish_to_confluence_button')), findsOneWidget);
      });

      testWidgets('button disappears when switching from Markdown to Confluence mode', (tester) async {
        // Arrange - Start with Markdown mode and Confluence enabled
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime.now(),
        );
        
        final appConfig = AppConfig(
          apiUrl: 'test-url',
          apiToken: 'test-token',
          defaultModel: 'test-model',
          reviewModel: 'test-review-model',
          selectedTemplateId: 'test-template',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        when(mockConfigService.config).thenReturn(appConfig);
        when(mockConfigService.isConfluenceEnabled()).thenReturn(true);

        await tester.pumpWidget(createTestWidget());
        
        // Assert - Button should be present initially
        expect(find.byKey(const Key('publish_to_confluence_button')), findsOneWidget);

        // Act - Switch to Confluence mode
        final updatedConfig = appConfig.copyWith(preferredFormat: OutputFormat.confluence);
        when(mockConfigService.config).thenReturn(updatedConfig);
        
        // Rebuild the widget with new config
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert - Button should now be hidden
        expect(find.byKey(const Key('publish_to_confluence_button')), findsNothing);
      });
    });
  });
}