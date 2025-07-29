import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/widgets/main_screen/format_selector.dart';

void main() {
  group('FormatSelector Widget Tests', () {
    testWidgets('should display both format options', (WidgetTester tester) async {
      OutputFormat? selectedFormat;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {
                selectedFormat = format;
              },
            ),
          ),
        ),
      );

      // Verify both format options are displayed
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Confluence Storage Format'), findsOneWidget);
      
      // Verify "По умолчанию" text is shown for Markdown
      expect(find.text('По умолчанию'), findsOneWidget);
    });

    testWidgets('should preselect Markdown as default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {},
            ),
          ),
        ),
      );

      // Find the radio buttons
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );

      expect(markdownRadio, findsOneWidget);
      expect(confluenceRadio, findsOneWidget);

      // Verify Markdown is selected
      final markdownRadioWidget = tester.widget<Radio<OutputFormat>>(markdownRadio);
      expect(markdownRadioWidget.groupValue, equals(OutputFormat.markdown));
    });

    testWidgets('should call onFormatChanged when selection changes', (WidgetTester tester) async {
      OutputFormat? changedFormat;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {
                changedFormat = format;
              },
            ),
          ),
        ),
      );

      // Tap on Confluence option
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Verify callback was called with correct format
      expect(changedFormat, equals(OutputFormat.confluence));
    });

    testWidgets('should update visual state when format changes', (WidgetTester tester) async {
      OutputFormat currentFormat = OutputFormat.markdown;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FormatSelector(
                  selectedFormat: currentFormat,
                  onFormatChanged: (format) {
                    setState(() {
                      currentFormat = format;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Initially Markdown should be selected
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      Radio<OutputFormat> markdownWidget = tester.widget<Radio<OutputFormat>>(markdownRadio);
      expect(markdownWidget.groupValue, equals(OutputFormat.markdown));

      // Tap on Confluence option
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Now Confluence should be selected
      Radio<OutputFormat> confluenceWidget = tester.widget<Radio<OutputFormat>>(confluenceRadio);
      expect(confluenceWidget.groupValue, equals(OutputFormat.confluence));
    });

    testWidgets('should handle container tap to change selection', (WidgetTester tester) async {
      OutputFormat? changedFormat;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {
                changedFormat = format;
              },
            ),
          ),
        ),
      );

      // Find and tap the Confluence container (not just the radio button)
      final confluenceContainer = find.byWidgetPredicate(
        (widget) => widget is InkWell,
      ).last; // Get the second InkWell (Confluence)
      
      await tester.tap(confluenceContainer);
      await tester.pump();

      // Verify callback was called with correct format
      expect(changedFormat, equals(OutputFormat.confluence));
    });

    testWidgets('should handle rapid format switching', (WidgetTester tester) async {
      final List<OutputFormat> formatChanges = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FormatSelector(
                  selectedFormat: formatChanges.isEmpty ? OutputFormat.markdown : formatChanges.last,
                  onFormatChanged: (format) {
                    setState(() {
                      formatChanges.add(format);
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Rapidly switch between formats
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );

      // Switch to Confluence
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Switch back to Markdown
      await tester.tap(markdownRadio);
      await tester.pump();

      // Switch to Confluence again
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Verify all changes were recorded
      expect(formatChanges, hasLength(3));
      expect(formatChanges[0], equals(OutputFormat.confluence));
      expect(formatChanges[1], equals(OutputFormat.markdown));
      expect(formatChanges[2], equals(OutputFormat.confluence));
    });

    testWidgets('should maintain visual state consistency during updates', (WidgetTester tester) async {
      OutputFormat currentFormat = OutputFormat.markdown;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: FormatSelector(
                  selectedFormat: currentFormat,
                  onFormatChanged: (format) {
                    setState(() {
                      currentFormat = format;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      // Verify initial visual state
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      Radio<OutputFormat> markdownWidget = tester.widget<Radio<OutputFormat>>(markdownRadio);
      expect(markdownWidget.groupValue, equals(OutputFormat.markdown));

      // Check visual styling for selected state
      expect(find.text('По умолчанию'), findsOneWidget);

      // Switch format and verify visual update
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Verify visual state changed
      Radio<OutputFormat> confluenceWidget = tester.widget<Radio<OutputFormat>>(confluenceRadio);
      expect(confluenceWidget.groupValue, equals(OutputFormat.confluence));
      
      // Verify markdown is no longer selected
      markdownWidget = tester.widget<Radio<OutputFormat>>(markdownRadio);
      expect(markdownWidget.groupValue, equals(OutputFormat.confluence));
    });

    testWidgets('should handle widget updates from parent', (WidgetTester tester) async {
      OutputFormat parentFormat = OutputFormat.markdown;
      OutputFormat? childCallback;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    FormatSelector(
                      selectedFormat: parentFormat,
                      onFormatChanged: (format) {
                        childCallback = format;
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          parentFormat = OutputFormat.confluence;
                        });
                      },
                      child: const Text('Change from Parent'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially Markdown should be selected
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      Radio<OutputFormat> markdownWidget = tester.widget<Radio<OutputFormat>>(markdownRadio);
      expect(markdownWidget.groupValue, equals(OutputFormat.markdown));

      // Change from parent
      await tester.tap(find.text('Change from Parent'));
      await tester.pump();

      // Verify widget updated to reflect parent change
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      Radio<OutputFormat> confluenceWidget = tester.widget<Radio<OutputFormat>>(confluenceRadio);
      expect(confluenceWidget.groupValue, equals(OutputFormat.confluence));

      // Verify callback wasn't called (parent initiated change)
      expect(childCallback, isNull);
    });

    testWidgets('should handle accessibility features', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {},
            ),
          ),
        ),
      );

      // Verify radio buttons are accessible
      final markdownRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.markdown,
      );
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );

      expect(markdownRadio, findsOneWidget);
      expect(confluenceRadio, findsOneWidget);

      // Verify text labels are present for screen readers
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Confluence Storage Format'), findsOneWidget);
      expect(find.text('По умолчанию'), findsOneWidget);
    });

    testWidgets('should handle theme changes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {},
            ),
          ),
        ),
      );

      // Verify widget renders with light theme
      expect(find.byType(FormatSelector), findsOneWidget);

      // Switch to dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {},
            ),
          ),
        ),
      );

      // Verify widget still renders correctly with dark theme
      expect(find.byType(FormatSelector), findsOneWidget);
      expect(find.text('Markdown'), findsOneWidget);
      expect(find.text('Confluence Storage Format'), findsOneWidget);
    });

    testWidgets('should handle edge case with null callback', (WidgetTester tester) async {
      // This test ensures the widget doesn't crash with null callback
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormatSelector(
              selectedFormat: OutputFormat.markdown,
              onFormatChanged: (format) {
                // Simulate null callback scenario
              },
            ),
          ),
        ),
      );

      expect(find.byType(FormatSelector), findsOneWidget);

      // Tap should not cause crashes even with minimal callback
      final confluenceRadio = find.byWidgetPredicate(
        (widget) => widget is Radio<OutputFormat> && widget.value == OutputFormat.confluence,
      );
      
      await tester.tap(confluenceRadio);
      await tester.pump();

      // Widget should still be present and functional
      expect(find.byType(FormatSelector), findsOneWidget);
    });
  });
}