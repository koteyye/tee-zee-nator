import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/spec_music_config.dart';
import '../../services/config_service.dart';
import '../../services/gen_api_service.dart';
import '../common/accessibility_wrapper.dart';

class MusicSettingsWidget extends StatefulWidget {
  const MusicSettingsWidget({super.key});

  @override
  State<MusicSettingsWidget> createState() => _MusicSettingsWidgetState();
}

class _MusicSettingsWidgetState extends State<MusicSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _apiKeyFocusNode = FocusNode();

  bool _isEnabled = false;
  bool _isTestingConnection = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  bool _hideApiKey = true;
  bool _useMock = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;

    if (config?.specMusicConfig != null) {
      final musicConfig = config!.specMusicConfig!;
      setState(() {
        _isEnabled = musicConfig.enabled;
        _apiKeyController.text = musicConfig.apiKey ?? '';
        _connectionSuccess = musicConfig.isValid;
        _useMock = musicConfig.useMock;
      });
    }
  }

  Future<void> _testConnection() async {
    if (kDebugMode && _useMock) {
      // Для мока не требуется валидация формы
      setState(() {
        _isTestingConnection = true;
        _errorMessage = null;
      });

      // Симулируем тестирование соединения
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _connectionSuccess = true;
        _errorMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Мок музикации подключен'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _saveConfig();

      setState(() {
        _isTestingConnection = false;
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _errorMessage = null;
    });

    try {
      final genApiService = GenApiService(apiKey: _apiKeyController.text.trim());
      await genApiService.getUserInfo();

      setState(() {
        _connectionSuccess = true;
        _errorMessage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Музикация подключена'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _saveConfig();
      genApiService.dispose();
    } catch (e) {
      setState(() {
        _connectionSuccess = false;
        _errorMessage = e.toString();
      });

      // Сохраняем состояние ошибки
      await _saveConfig();
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final currentConfig = configService.config;

    if (currentConfig != null) {
      final newMusicConfig = SpecMusicConfig(
        enabled: _isEnabled,
        apiKey: _apiKeyController.text.trim().isNotEmpty ? _apiKeyController.text.trim() : null,
        lastValidated: _connectionSuccess ? DateTime.now() : null,
        isValid: _connectionSuccess,
        lastError: _errorMessage,
        useMock: _useMock,
      );

      final updatedConfig = currentConfig.copyWith(
        specMusicConfig: newMusicConfig,
      );

      await configService.saveConfig(updatedConfig);
    }
  }

  Future<void> _openGenApiWebsite() async {
    final uri = Uri.parse('https://gen-api.ru/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Музикация требований',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    if (kDebugMode) ...[
                      Text(
                        'Мок',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _useMock,
                        onChanged: (value) async {
                          setState(() {
                            _useMock = value;
                            if (value) {
                              // При включении мока автоматически включаем музикацию
                              _isEnabled = true;
                              _connectionSuccess = true;
                              _errorMessage = null;
                            }
                          });
                          await _saveConfig();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 16),
                    ],
                    Switch.adaptive(
                      value: _isEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _isEnabled = value;
                        });
                        await _saveConfig();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Превращайте ваши требования в музыкальные шедевры с помощью ИИ!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Для работы требуется API-ключ сервиса ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                InkWell(
                  onTap: _openGenApiWebsite,
                  child: Text(
                    'gen-api.ru',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isEnabled && !(kDebugMode && _useMock) ? null : 0,
              child: _isEnabled && !(kDebugMode && _useMock)
                  ? _buildConfigurationForm()
                  : const SizedBox.shrink(),
            ),

            // Показываем статус мока в debug режиме
            if (kDebugMode && _useMock) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Используется мок музикации (debug режим)',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AccessibilityWrapper(
                  label: 'API ключ для gen-api.ru',
                  child: TextFormField(
                    controller: _apiKeyController,
                    focusNode: _apiKeyFocusNode,
                    decoration: InputDecoration(
                      labelText: 'API ключ',
                      hintText: 'Вставьте ваш API ключ gen-api.ru',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_hideApiKey ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _hideApiKey = !_hideApiKey;
                              });
                            },
                            tooltip: _hideApiKey ? 'Показать ключ' : 'Скрыть ключ',
                          ),
                          IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data != null && data.text != null) {
                                setState(() {
                                  _apiKeyController.text = data.text!.trim();
                                });
                              }
                            },
                            tooltip: 'Вставить из буфера обмена',
                          ),
                        ],
                      ),
                      errorText: _errorMessage,
                    ),
                    obscureText: _hideApiKey,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите API ключ';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isTestingConnection ? null : _testConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _connectionSuccess
                      ? Colors.green
                      : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isTestingConnection
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_connectionSuccess ? 'Проверено' : 'Проверить'),
              ),
            ],
          ),
          if (_connectionSuccess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Музикация успешно подключена',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}