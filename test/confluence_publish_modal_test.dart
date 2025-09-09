import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/widgets/main_screen/confluence_publish_modal.dart';

import 'confluence_publish_modal_test.mocks.dart';

@GenerateMocks([ConfluenceService])
void main() {
  group('ConfluencePublishModal', () {
    late MockConfluenceService mockConfluenceService;

    setUp(() {
      mockConfluenceService = MockConfluenceService();
      
      // Setup default mock behavior
      when(mockConfluenceService.isConfigured).thenReturn(true);
      when(mockConfluenceService.config).thenReturn(
        const ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://test.atlassian.net',
          token: 'test-token',
          isValid: true,
        ),
      );
    });

    Widget createTestWidget({
      String content = 'Test content',
      String? suggestedTitle,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ConfluenceService>.value(
            value: mockConfluenceService,
            child: ConfluencePublishModal(
              content: content,
              suggestedTitle: suggestedTitle,
            ),
          ),
        ),
      );
    }

    group('Initial State', () {
      testWidgets('displays modal with correct title and close button', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Publish to Confluence'), findsOneWidget);
        expect(find.byIcon(Icons.publish), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('shows create new page option selected by default', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Create New Page'), findsOneWidget);
        expect(find.text('Update Existing Page'), findsOneWidget);
      });

      testWidgets('displays create page fields when create option is selected', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Parent Page URL'), findsOneWidget);
        expect(find.text('Page Title'), findsOneWidget);
        expect(find.byKey(const Key('parent_page_url_field')), findsOneWidget);
        expect(find.byKey(const Key('page_title_field')), findsOneWidget);
      });

      testWidgets('pre-fills title when suggestedTitle is provided', (tester) async {
        await tester.pumpWidget(createTestWidget(suggestedTitle: 'Test Title'));

        final titleField = find.byKey(const Key('page_title_field'));
        expect(titleField, findsOneWidget);
        
        final textField = tester.widget<TextFormField>(titleField);
        expect(textField.controller?.text, equals('Test Title'));
      });
    });

    group('Operation Selection', () {
      testWidgets('switches to update fields when update option is selected', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Tap update radio button
        await tester.tap(find.text('Update Existing Page'));
        await tester.pumpAndSettle();

        expect(find.text('Page URL'), findsOneWidget);
        expect(find.byKey(const Key('page_url_field')), findsOneWidget);
        expect(find.byKey(const Key('parent_page_url_field')), findsNothing);
        expect(find.byKey(const Key('page_title_field')), findsNothing);
      });

      testWidgets('switches back to create fields when create option is selected', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // First switch to update
        await tester.tap(find.text('Update Existing Page'));
        await tester.pumpAndSettle();

        // Then switch back to create
        await tester.tap(find.text('Create New Page'));
        await tester.pumpAndSettle();

        expect(find.text('Parent Page URL'), findsOneWidget);
        expect(find.text('Page Title'), findsOneWidget);
        expect(find.byKey(const Key('parent_page_url_field')), findsOneWidget);
        expect(find.byKey(const Key('page_title_field')), findsOneWidget);
        expect(find.byKey(const Key('page_url_field')), findsNothing);
      });
    });

    group('Form Fields', () {
      testWidgets('displays input fields for create operation', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byKey(const Key('parent_page_url_field')), findsOneWidget);
        expect(find.byKey(const Key('page_title_field')), findsOneWidget);
        expect(find.byKey(const Key('page_url_field')), findsNothing);
      });

      testWidgets('displays input fields for update operation', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Switch to update operation
        await tester.tap(find.text('Update Existing Page'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('page_url_field')), findsOneWidget);
        expect(find.byKey(const Key('parent_page_url_field')), findsNothing);
        expect(find.byKey(const Key('page_title_field')), findsNothing);
      });

      testWidgets('accepts text input in form fields', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Test parent URL field
        await tester.enterText(
          find.byKey(const Key('parent_page_url_field')),
          'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Parent',
        );
        
        // Test title field
        await tester.enterText(
          find.byKey(const Key('page_title_field')),
          'Test Page Title',
        );

        await tester.pumpAndSettle();

        // Verify text was entered
        expect(find.text('https://test.atlassian.net/wiki/spaces/TEST/pages/123/Parent'), findsOneWidget);
        expect(find.text('Test Page Title'), findsOneWidget);
      });
    });

    group('Button States', () {
      testWidgets('create button is disabled when form is invalid', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Find the create button and check if it's disabled
        final createButtonFinder = find.text('Create Page');
        expect(createButtonFinder, findsOneWidget);
        
        final createButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: createButtonFinder,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(createButton.onPressed, isNull);
      });

      testWidgets('create button is enabled when form is valid', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Fill valid data
        await tester.enterText(
          find.byKey(const Key('parent_page_url_field')),
          'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Parent',
        );
        await tester.enterText(
          find.byKey(const Key('page_title_field')),
          'Test Title',
        );
        await tester.pumpAndSettle();

        final createButtonFinder = find.text('Create Page');
        final createButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: createButtonFinder,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(createButton.onPressed, isNotNull);
      });

      testWidgets('update button is enabled when page URL is provided', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Switch to update operation
        await tester.tap(find.text('Update Existing Page'));
        await tester.pumpAndSettle();

        // Fill valid page URL
        await tester.enterText(
          find.byKey(const Key('page_url_field')),
          'https://test.atlassian.net/wiki/spaces/TEST/pages/456/Existing',
        );
        await tester.pumpAndSettle();

        final updateButtonFinder = find.text('Update Page');
        final updateButton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: updateButtonFinder,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(updateButton.onPressed, isNotNull);
      });
    });



    group('Modal Actions', () {
      testWidgets('displays close button', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
      });

      testWidgets('displays action buttons based on operation', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should show Create Page button by default
        expect(find.text('Create Page'), findsOneWidget);
        expect(find.text('Update Page'), findsNothing);

        // Switch to update operation
        await tester.tap(find.text('Update Existing Page'));
        await tester.pumpAndSettle();

        // Should show Update Page button
        expect(find.text('Update Page'), findsOneWidget);
        expect(find.text('Create Page'), findsNothing);
      });
    });
  });
}