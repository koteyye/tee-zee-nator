import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tee_zee_nator/widgets/main_screen/confluence_settings_widget.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/services/config_service.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/models/confluence_page.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/theme/app_theme.dart';

// Manual mock classes
class MockConfluenceService extends ChangeNotifier implements ConfluenceService {
  ConfluenceConfig? _config;
  bool _isLoading = false;
  String? _lastError;
  bool _testConnectionResult = false;
  bool _initializeCalled = false;

  @override
  ConfluenceConfig? get config => _config;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get lastError => _lastError;

  @override
  bool get isConfigured => _config?.isConfigurationComplete ?? false;

  @override
  bool get isConnected => _config?.isValid ?? false;

  @override
  void initialize(ConfluenceConfig? config) {
    _config = config;
    _initializeCalled = true;
    notifyListeners();
  }

  @override
  Future<bool> testConnection(String baseUrl, String email, String token) async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    _isLoading = false;
    if (!_testConnectionResult) {
      _lastError = 'Connection failed';
    } else {
      _lastError = null;
    }
    notifyListeners();
    
    return _testConnectionResult;
  }

  @override
  Future<String> getPageContent(String pageId) async {
    throw UnimplementedError();
  }

  @override
  Future<ConfluencePage> getPageInfo(String pageUrl) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> resolvePageIdFromUrl(String tinyUrl) async {
    // Для тестов можно вернуть null
    return null;
  }

  // Test helper methods
  void setTestConnectionResult(bool result) {
    _testConnectionResult = result;
  }

  void setLastError(String? error) {
    _lastError = error;
  }

  bool get initializeCalled => _initializeCalled;
}

class MockConfigService extends ChangeNotifier implements ConfigService {
  AppConfig? _config;
  bool _saveConfigCalled = false;
  Exception? _saveConfigException;

  @override
  AppConfig? get config => _config;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveConfig(AppConfig config) async {
    _saveConfigCalled = true;
    if (_saveConfigException != null) {
      throw _saveConfigException!;
    }
    _config = config;
    notifyListeners();
  }

  @override
  Future<void> forceReset() async {}

  // Test helper methods
  void setConfig(AppConfig? config) {
    _config = config;
  }

  void setSaveConfigException(Exception? exception) {
    _saveConfigException = exception;
  }

  bool get saveConfigCalled => _saveConfigCalled;

  // Unimplemented methods from ConfigService
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
  bool isConfluenceEnabled() => false;

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
  group('ConfluenceSettingsWidget', () {
    late MockConfluenceService mockConfluenceService;
    late MockConfigService mockConfigService;
    late AppConfig testAppConfig;

    setUp(() {
      mockConfluenceService = MockConfluenceService();
      mockConfigService = MockConfigService();
      
      testAppConfig = AppConfig(
        apiUrl: 'https://api.openai.com/v1',
        apiToken: 'test-token',
        provider: 'openai',
        defaultModel: 'gpt-3.5-turbo',
        reviewModel: 'gpt-3.5-turbo',
      );
      
      // Setup default mock behaviors
      mockConfigService.setConfig(testAppConfig);
    });

    Widget createTestWidget() {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConfluenceService>.value(
                value: mockConfluenceService,
              ),
              ChangeNotifierProvider<ConfigService>.value(
                value: mockConfigService,
              ),
            ],
            child: const ConfluenceSettingsWidget(),
          ),
        ),
      );
    }

    testWidgets('displays initial disabled state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Verify header and toggle switch
      expect(find.text('Confluence Integration'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
      
      // Verify description text for disabled state
      expect(find.text('Enable to connect to Confluence workspace'), findsOneWidget);
      
      // Verify input fields are not visible when disabled
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Test Connection'), findsNothing);
    });

    testWidgets('shows input fields when toggle is enabled', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Verify input fields are now visible
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('API Token'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
      
      // Verify helper texts
      expect(find.text('Your Confluence domain (without /wiki/rest/api)'), findsOneWidget);
      expect(find.text('Generate from Atlassian Account Settings > Security > API tokens'), findsOneWidget);
    });

    testWidgets('validates Base URL field correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Try to test connection with empty Base URL
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      // Verify validation error appears
      expect(find.text('Base URL is required when Confluence is enabled'), findsOneWidget);
      
      // Enter invalid URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'invalid-url',
      );
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      expect(find.text('Please enter a valid URL (e.g., https://company.atlassian.net)'), findsOneWidget);
      
      // Enter URL with /wiki/rest/api suffix
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net/wiki/rest/api',
      );
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      expect(find.text('Please remove /wiki/rest/api from the URL'), findsOneWidget);
    });

    testWidgets('validates Token field correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid Base URL but leave token empty
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      // Verify token validation error appears
      expect(find.text('Token is required when Confluence is enabled'), findsOneWidget);
      
      // Enter too short token
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'short',
      );
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      expect(find.text('Token appears to be too short'), findsOneWidget);
    });

    testWidgets('performs connection test successfully', (WidgetTester tester) async {
      // Setup successful connection test
      mockConfluenceService.setTestConnectionResult(true);
      
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'valid-token-123456',
      );
      
      // Tap test connection button
      await tester.tap(find.text('Test Connection'));
      await tester.pump();
      
      // Verify loading state
      expect(find.text('Testing Connection...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for async operation to complete
      await tester.pumpAndSettle();
      
      // Verify successful connection state
      expect(find.text('Connection Successful'), findsOneWidget);
      expect(find.text('Connection established successfully! You can now save the configuration.'), findsOneWidget);
      expect(find.text('Save Configuration'), findsOneWidget);
    });

    testWidgets('handles connection test failure', (WidgetTester tester) async {
      // Setup failed connection test
      mockConfluenceService.setTestConnectionResult(false);
      mockConfluenceService.setLastError('Authentication failed: Invalid credentials');
      
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'invalid-token',
      );
      
      // Tap test connection button
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      
      // Verify error state
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Save Configuration'), findsNothing);
    });

    testWidgets('saves configuration successfully', (WidgetTester tester) async {
      // Setup successful connection test
      mockConfluenceService.setTestConnectionResult(true);
      
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'valid-token-123456',
      );
      
      // Test connection
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      
      // Save configuration
      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      
      // Verify save was called
      expect(mockConfigService.saveConfigCalled, true);
      expect(mockConfluenceService.initializeCalled, true);
      
      // Verify success message
      expect(find.text('Confluence configuration saved successfully'), findsOneWidget);
    });

    testWidgets('loads existing configuration on init', (WidgetTester tester) async {
      // Setup existing configuration
      final existingConfig = testAppConfig.copyWith(
        confluenceConfig: const ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://existing.atlassian.net',
          token: 'existing-token',
          isValid: true,
        ),
      );
      mockConfigService.setConfig(existingConfig);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      
      // Verify toggle is enabled
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
      
      // Verify fields are populated
      expect(find.text('https://existing.atlassian.net'), findsOneWidget);
      expect(find.text('Connection Successful'), findsOneWidget);
    });

    testWidgets('clears fields when toggle is disabled', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter some data
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'some-token',
      );
      
      // Disable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enable again to check if fields are cleared
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Verify fields are empty
      final baseUrlField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Base URL'),
      );
      final tokenField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'API Token'),
      );
      
      expect(baseUrlField.controller?.text, isEmpty);
      expect(tokenField.controller?.text, isEmpty);
    });

    testWidgets('resets connection status when fields change', (WidgetTester tester) async {
      // Setup successful connection test
      mockConfluenceService.setTestConnectionResult(true);
      
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid credentials and test connection
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'valid-token-123456',
      );
      
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      
      // Verify successful connection
      expect(find.text('Connection Successful'), findsOneWidget);
      
      // Change the Base URL
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://different.atlassian.net',
      );
      await tester.pump();
      
      // Verify connection status is reset
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.text('Connection Successful'), findsNothing);
    });

    testWidgets('handles save configuration error', (WidgetTester tester) async {
      // Setup successful connection test but failed save
      mockConfluenceService.setTestConnectionResult(true);
      mockConfigService.setSaveConfigException(Exception('Save failed'));
      
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'valid-token-123456',
      );
      
      // Test connection
      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      
      // Try to save configuration
      await tester.tap(find.text('Save Configuration'));
      await tester.pumpAndSettle();
      
      // Verify error message
      expect(find.text('Failed to save configuration: Exception: Save failed'), findsOneWidget);
    });

    testWidgets('save button is disabled when connection test not successful', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Enter valid credentials but don't test connection
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Base URL'),
        'https://company.atlassian.net',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API Token'),
        'valid-token-123456',
      );
      
      // Verify save button is not visible (connection not tested)
      expect(find.text('Save Configuration'), findsNothing);
    });

    testWidgets('displays correct icons and styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      
      // Enable the toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pump();
      
      // Verify icons are present
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.key), findsOneWidget);
      expect(find.byIcon(Icons.wifi_find), findsOneWidget);
      
      // Verify card styling
      expect(find.byType(Card), findsOneWidget);
    });
  });
}