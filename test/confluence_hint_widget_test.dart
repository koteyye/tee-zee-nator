import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tee_zee_nator/widgets/main_screen/confluence_hint_widget.dart';
import 'package:tee_zee_nator/services/config_service.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/models/output_format.dart';

// Manual mock class following the project pattern
class MockConfigService extends ChangeNotifier implements ConfigService {
  AppConfig? _config;
  bool _confluenceEnabled = false;

  @override
  AppConfig? get config => _config;

  @override
  bool isConfluenceEnabled() => _confluenceEnabled;

  // Test helper methods
  void setConfluenceEnabled(bool enabled) {
    _confluenceEnabled = enabled;
    notifyListeners();
  }

  void setConfig(AppConfig? config) {
    _config = config;
  }

  // Unimplemented methods from ConfigService interface
  @override
  Future<void> init() async {}

  @override
  Future<void> saveConfig(AppConfig config) async {}

  @override
  Future<void> forceReset() async {}

  @override
  Future<void> clearConfig() async {}

  @override
  Future<void> clearConfluenceConfig() async {}

  @override
  Future<void> disableConfluence() async {}

  @override
  ConfluenceConfig? getConfluenceConfig() => null;

  @override
  Map<String, dynamic> getConfluenceConnectionStatus() => {};

  @override
  OutputFormat getPreferredFormat() => OutputFormat.defaultFormat;

  @override
  Future<bool> hasValidConfiguration() async => true;

  @override
  Future<void> saveConfluenceConfig(ConfluenceConfig confluenceConfig) async {}

  @override
  Future<void> updateConfluenceConnectionStatus({
    required bool isValid,
    DateTime? lastValidated,
  }) async {}

  @override
  Future<void> updatePreferredFormat(OutputFormat format) async {}

  @override
  Future<void> updatePreferredFormatWithValidation(OutputFormat? format) async {}

  @override
  Future<void> updateSelectedModel(String model) async {}

  @override
  bool validateConfluenceConfiguration() => false;
}

void main() {
  group('ConfluenceHintWidget', () {
    late MockConfigService mockConfigService;

    setUp(() {
      mockConfigService = MockConfigService();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<ConfigService>(
            create: (_) => mockConfigService,
            child: const ConfluenceHintWidget(),
          ),
        ),
      );
    }

    testWidgets('should display hint when Confluence is enabled and configured', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(ConfluenceHintWidget), findsOneWidget);
      expect(find.text('You can specify links to Confluence articles with information to consider in requirements'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      
      // Verify the container styling
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue.shade50);
      expect(decoration.borderRadius, BorderRadius.circular(6));
      expect(decoration.border, isA<Border>());
    });

    testWidgets('should hide hint when Confluence is not enabled', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(false);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('You can specify links to Confluence articles with information to consider in requirements'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      
      // Verify that SizedBox.shrink() is used
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('should hide hint when Confluence is not configured', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(false);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('You can specify links to Confluence articles with information to consider in requirements'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('should have proper styling when displayed', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      // Check container styling
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.margin, const EdgeInsets.only(top: 4, bottom: 8));
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
      
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue.shade50);
      expect(decoration.borderRadius, BorderRadius.circular(6));
      
      // Check icon styling
      final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
      expect(icon.size, 16);
      expect(icon.color, Colors.blue.shade600);
      
      // Check text styling
      final text = tester.widget<Text>(find.text('You can specify links to Confluence articles with information to consider in requirements'));
      final textStyle = text.style!;
      expect(textStyle.fontSize, 12);
      expect(textStyle.color, Colors.blue.shade700);
      expect(textStyle.fontWeight, FontWeight.w500);
    });

    testWidgets('should respond to ConfigService changes', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(false);

      // Act - Initial state (hidden)
      await tester.pumpWidget(createTestWidget());
      
      // Assert - Initially hidden
      expect(find.text('You can specify links to Confluence articles with information to consider in requirements'), findsNothing);
      
      // Act - Change to enabled
      mockConfigService.setConfluenceEnabled(true);
      await tester.pump();
      
      // Assert - Now visible
      expect(find.text('You can specify links to Confluence articles with information to consider in requirements'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('should have proper layout structure', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      // Check that Row contains Icon and Expanded Text
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.length, 3); // Icon, SizedBox, Expanded
      
      // Check that there's a SizedBox with width 8 for spacing
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacingSizedBox = sizedBoxes.firstWhere((box) => box.width == 8);
      expect(spacingSizedBox.width, 8);
      
      // Check Expanded widget
      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('should integrate properly with Consumer<ConfigService>', (WidgetTester tester) async {
      // Arrange
      mockConfigService.setConfluenceEnabled(true);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(Consumer<ConfigService>), findsOneWidget);
      
      // Verify that the Consumer is properly connected
      final consumer = tester.widget<Consumer<ConfigService>>(find.byType(Consumer<ConfigService>));
      expect(consumer.builder, isNotNull);
    });
  });
}