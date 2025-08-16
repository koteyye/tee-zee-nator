import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/confluence_config.dart';
import '../../models/app_config.dart';
import '../../models/output_format.dart';
import '../../services/confluence_service.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';
import '../common/enhanced_tooltip.dart';
import '../common/accessibility_wrapper.dart';


/// Widget for configuring Confluence integration settings
/// 
/// Provides UI for:
/// - Enabling/disabling Confluence integration
/// - Configuring Base URL and Token
/// - Testing connection with visual feedback
/// - Saving configuration after successful test
class ConfluenceSettingsWidget extends StatefulWidget {
  const ConfluenceSettingsWidget({super.key});

  @override
  State<ConfluenceSettingsWidget> createState() => _ConfluenceSettingsWidgetState();
}

class _ConfluenceSettingsWidgetState extends State<ConfluenceSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  
  final _baseUrlFocusNode = FocusNode();
  final _tokenFocusNode = FocusNode();
  
  bool _isEnabled = false;
  bool _isTestingConnection = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _baseUrlFocusNode.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  /// Loads current Confluence configuration from ConfigService
  Future<void> _loadCurrentConfig() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;
    
    if (config?.confluenceConfig != null) {
      final confluenceConfig = config!.confluenceConfig!;
      setState(() {
        _isEnabled = confluenceConfig.enabled;
        _baseUrlController.text = confluenceConfig.baseUrl;
        _tokenController.text = confluenceConfig.token;
        _connectionSuccess = confluenceConfig.isValid;
      });
    }
  }

  /// Tests connection to Confluence using provided credentials
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Remove focus from active field
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isTestingConnection = true;
      _connectionSuccess = false;
      _errorMessage = null;
    });
    
    try {
      final confluenceService = Provider.of<ConfluenceService>(context, listen: false);
      final success = await confluenceService.testConnection(
        _baseUrlController.text.trim(),
        _tokenController.text.trim(),
      );
      
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = success;
          if (!success && confluenceService.lastError != null) {
            _errorMessage = confluenceService.lastError;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _connectionSuccess = false;
          _errorMessage = 'Connection test failed: $e';
        });
      }
    }
  }

  /// Saves Confluence configuration after connection test
  /// If connection test was not performed, saves as draft configuration
  Future<void> _saveConfiguration() async {
    try {
      final configService = Provider.of<ConfigService>(context, listen: false);
      final confluenceService = Provider.of<ConfluenceService>(context, listen: false);
      final currentConfig = configService.config;
      
      // Создаем новую конфигурацию даже если основной конфиг еще не существует
      if (currentConfig == null) {
        // Создаем базовый конфиг с минимальными настройками
        final newConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1', // Временные значения
          apiToken: '', // Будет заполнено позже
          provider: 'openai',
          defaultModel: 'gpt-3.5-turbo',
          reviewModel: 'gpt-3.5-turbo',
          preferredFormat: OutputFormat.defaultFormat,
          confluenceConfig: ConfluenceConfig(
            enabled: _isEnabled,
            baseUrl: _baseUrlController.text.trim(),
            token: _tokenController.text.trim(),
            lastValidated: _connectionSuccess ? DateTime.now() : null,
            isValid: _connectionSuccess,
          ),
        );
        
        await configService.saveConfig(newConfig);
        
        if (_connectionSuccess) {
          // Инициализируем сервис только если соединение проверено успешно
          confluenceService.initialize(newConfig.confluenceConfig!);
        }
        
        if (mounted) {
          _showSuccessSnackBar(_connectionSuccess 
              ? 'Confluence configuration saved successfully' 
              : 'Confluence configuration saved as draft');
        }
        return;
      }
      
      // Если конфиг уже существует, обновляем только настройки Confluence
      final confluenceConfig = ConfluenceConfig(
        enabled: _isEnabled,
        baseUrl: _baseUrlController.text.trim(),
        token: _tokenController.text.trim(),
        lastValidated: _connectionSuccess ? DateTime.now() : null,
        isValid: _connectionSuccess,
      );
      
      final updatedConfig = currentConfig.copyWith(
        confluenceConfig: confluenceConfig,
      );
      
      await configService.saveConfig(updatedConfig);
      
      // Initialize ConfluenceService with new configuration only if connection was successful
      if (_connectionSuccess) {
        confluenceService.initialize(confluenceConfig);
      }
      
      if (mounted) {
        _showSuccessSnackBar(_connectionSuccess 
            ? 'Confluence configuration saved successfully' 
            : 'Confluence configuration saved as draft');
      }
      
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to save configuration: $e');
      }
    }
  }

  /// Handles toggle switch changes
  void _onToggleChanged(bool value) {
    setState(() {
      _isEnabled = value;
      if (!value) {
        // Clear fields and reset state when disabled
        _baseUrlController.clear();
        _tokenController.clear();
        _connectionSuccess = false;
        _errorMessage = null;
      }
    });
  }

  /// Validates Base URL format
  String? _validateBaseUrl(String? value) {
    if (!_isEnabled) return null;
    
    if (value == null || value.trim().isEmpty) {
      return 'Base URL is required when Confluence is enabled';
    }
    
    final trimmedValue = value.trim();
    final uri = Uri.tryParse(trimmedValue);
    
    if (uri == null || !uri.isAbsolute || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Please enter a valid URL (e.g., https://company.atlassian.net)';
    }
    
    // Check if URL contains /wiki/rest/api suffix (should be removed)
    if (trimmedValue.contains('/wiki/rest/api')) {
      return 'Please remove /wiki/rest/api from the URL';
    }
    
    return null;
  }

  /// Validates token format
  String? _validateToken(String? value) {
    if (!_isEnabled) return null;
    
    if (value == null || value.trim().isEmpty) {
      return 'Token is required when Confluence is enabled';
    }
    
    final trimmedValue = value.trim();
    if (trimmedValue.length < 10) {
      return 'Token appears to be too short';
    }
    
    return null;
  }

  /// Shows success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Shows help dialog for API token generation
  void _showTokenHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryRed),
            SizedBox(width: 8),
            Text('How to Generate API Token'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To generate a Confluence API token:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('1. Go to your Atlassian Account Settings'),
              SizedBox(height: 8),
              Text('2. Navigate to Security > API tokens'),
              SizedBox(height: 8),
              Text('3. Click "Create API token"'),
              SizedBox(height: 8),
              Text('4. Give it a descriptive label (e.g., "TeeZeeNator")'),
              SizedBox(height: 8),
              Text('5. Copy the generated token'),
              SizedBox(height: 12),
              Text(
                'Important: Save the token securely as you won\'t be able to see it again.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Checks if connection test can be performed
  bool get _canTestConnection {
    return _baseUrlController.text.trim().isNotEmpty &&
           _tokenController.text.trim().isNotEmpty &&
           !_isTestingConnection;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              if (_canTestConnection) {
                _testConnection();
              }
              return null;
            },
          ),
          SubmitIntent: CallbackAction<SubmitIntent>(
            onInvoke: (SubmitIntent intent) {
              if (_connectionSuccess) {
                _saveConfiguration();
              }
              return null;
            },
          ),
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with toggle switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confluence Integration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: _onToggleChanged,
                    activeColor: AppTheme.primaryRed,
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _isEnabled 
                    ? 'Connect to your Confluence workspace to reference articles and publish specifications'
                    : 'Enable to connect to Confluence workspace',
                style: const TextStyle(
                  color: AppTheme.darkGray,
                  fontSize: 14,
                ),
              ),
              
              if (_isEnabled) ...[
                const SizedBox(height: 24),
                
                // Base URL field
                AccessibleFormField(
                  label: 'Confluence Base URL',
                  hint: 'Enter your Confluence domain URL without the API path',
                  required: true,
                  enabled: !_isTestingConnection,
                  child: FieldTooltip(
                    label: 'Base URL',
                    hint: 'Enter your Confluence domain URL without the API path',
                    example: 'https://company.atlassian.net',
                    required: true,
                    child: TextFormField(
                      controller: _baseUrlController,
                      focusNode: _baseUrlFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Base URL *',
                        hintText: 'https://company.atlassian.net',
                        helperText: 'Your Confluence domain (without /wiki/rest/api)',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _baseUrlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _baseUrlController.clear();
                                  setState(() {
                                    _connectionSuccess = false;
                                    _errorMessage = null;
                                  });
                                },
                                tooltip: 'Clear URL',
                              )
                            : null,
                      ),
                      validator: _validateBaseUrl,
                      enabled: !_isTestingConnection,
                      onChanged: (_) {
                        // Reset connection status when URL changes
                        if (_connectionSuccess) {
                          setState(() {
                            _connectionSuccess = false;
                            _errorMessage = null;
                          });
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')), // No spaces
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Token field
                AccessibleFormField(
                  label: 'Confluence API Token',
                  hint: 'Enter your Confluence API token for authentication',
                  required: true,
                  enabled: !_isTestingConnection,
                  child: FieldTooltip(
                    label: 'API Token',
                    hint: 'Generate API token from Atlassian Account Settings > Security > API tokens',
                    example: 'ATATT3xFfGF0T4JNjBrel...',
                    required: true,
                    child: TextFormField(
                      controller: _tokenController,
                      focusNode: _tokenFocusNode,
                      decoration: InputDecoration(
                        labelText: 'API Token *',
                        hintText: 'Your Confluence API token',
                        helperText: 'Generate from Atlassian Account Settings > Security > API tokens',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_tokenController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _tokenController.clear();
                                  setState(() {
                                    _connectionSuccess = false;
                                    _errorMessage = null;
                                  });
                                },
                                tooltip: 'Clear token',
                              ),
                            IconButton(
                              icon: const Icon(Icons.help_outline, size: 18),
                              onPressed: () => _showTokenHelpDialog(),
                              tooltip: 'How to generate API token',
                            ),
                          ],
                        ),
                      ),
                      obscureText: true,
                      validator: _validateToken,
                      enabled: !_isTestingConnection,
                      onChanged: (_) {
                        // Reset connection status when token changes
                        if (_connectionSuccess) {
                          setState(() {
                            _connectionSuccess = false;
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Test connection button
                AccessibleButton(
                  label: _isTestingConnection 
                      ? 'Testing connection to Confluence, please wait'
                      : _connectionSuccess
                          ? 'Connection test successful'
                          : 'Test connection to Confluence',
                  hint: _isTestingConnection 
                      ? 'Please wait while we test your connection'
                      : _connectionSuccess
                          ? 'Connection established successfully'
                          : 'Click to test your Confluence connection with the provided credentials',
                  enabled: !_isTestingConnection && _canTestConnection,
                  onPressed: _isTestingConnection ? null : _testConnection,
                  child: ButtonTooltip(
                    action: _isTestingConnection 
                        ? 'Testing connection...'
                        : _connectionSuccess
                            ? 'Connection established successfully'
                            : 'Test your Confluence connection',
                    shortcut: 'Ctrl+T',
                    enabled: !_isTestingConnection && _canTestConnection,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                _connectionSuccess ? Icons.check_circle : Icons.wifi_find,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isTestingConnection
                              ? 'Testing Connection...'
                              : _connectionSuccess
                                  ? 'Connection Successful'
                                  : 'Test Connection',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _connectionSuccess 
                              ? Colors.green 
                              : AppTheme.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Connection status messages
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Всегда показываем кнопку сохранения, но с разными сообщениями в зависимости от статуса соединения
                ...[
                  const SizedBox(height: 16),
                  if (_connectionSuccess) Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connection established successfully! You can now save the configuration.',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_connectionSuccess && !_isTestingConnection && _canTestConnection && _errorMessage == null) Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connection not tested yet. You can save as draft or test connection first.',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Save button (всегда активна, если заполнены обязательные поля)
                  AccessibleButton(
                    label: _connectionSuccess 
                        ? 'Save Confluence configuration'
                        : 'Save Confluence configuration as draft',
                    hint: _connectionSuccess 
                        ? 'Save your Confluence configuration to enable integration features'
                        : 'Save your configuration as draft (connection not verified)',
                    enabled: _canTestConnection, // Активна, если заполнены обязательные поля
                    onPressed: _canTestConnection ? _saveConfiguration : null,
                    child: ButtonTooltip(
                      action: _connectionSuccess 
                          ? 'Save your Confluence configuration'
                          : 'Save your configuration as draft',
                      shortcut: 'Ctrl+S',
                      enabled: _canTestConnection,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _canTestConnection ? _saveConfiguration : null,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(_connectionSuccess ? 'Save Configuration' : 'Save as Draft'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _connectionSuccess ? AppTheme.primaryRed : Colors.amber.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom intents for keyboard shortcuts
class SubmitIntent extends Intent {
  const SubmitIntent();
}