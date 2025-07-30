import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/template_service.dart';
import '../services/config_service.dart';
import '../services/llm_service.dart';
import '../models/app_config.dart';
import '../models/openai_model.dart';
import '../models/output_format.dart';
import 'main_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(text: 'https://api.openai.com/v1');
  final _tokenController = TextEditingController();
  final _llmopsUrlController = TextEditingController(text: 'http://localhost:11434');
  final _llmopsAuthController = TextEditingController();
  
  // Добавляем FocusNode'ы для управления фокусом
  final _urlFocusNode = FocusNode();
  final _tokenFocusNode = FocusNode();
  final _llmopsUrlFocusNode = FocusNode();
  final _llmopsAuthFocusNode = FocusNode();
  
  String _selectedProvider = 'openai';
  OutputFormat _selectedFormat = OutputFormat.defaultFormat;
  bool _isTestingConnection = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  OpenAIModel? _selectedModel;
  List<OpenAIModel> _availableModels = [];
  
  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _llmopsUrlController.dispose();
    _llmopsAuthController.dispose();
    
    _urlFocusNode.dispose();
    _tokenFocusNode.dispose();
    _llmopsUrlFocusNode.dispose();
    _llmopsAuthFocusNode.dispose();
    
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;
    if (config != null) {
      setState(() {
        _selectedProvider = config.provider;
        _selectedFormat = config.preferredFormat;
        if (_selectedProvider == 'openai') {
          _urlController.text = config.apiUrl;
          _tokenController.text = config.apiToken;
        } else {
          _llmopsUrlController.text = config.llmopsBaseUrl ?? 'http://localhost:11434';
          _llmopsAuthController.text = config.llmopsAuthHeader ?? '';
        }
      });
    }
  }
  
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Снимаем фокус с активного поля
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isTestingConnection = true;
      _connectionSuccess = false;
      _errorMessage = null;
      _availableModels = [];
    });
    
    try {
      final llmService = Provider.of<LLMService>(context, listen: false);
      
      if (_selectedProvider == 'openai') {
        final testConfig = AppConfig(
          apiUrl: _urlController.text.trim(),
          apiToken: _tokenController.text.trim(),
          provider: 'openai',
          defaultModel: 'gpt-3.5-turbo',
          reviewModel: 'gpt-3.5-turbo',
        );
        
        llmService.initializeProvider(testConfig);
        final success = await llmService.testConnection();
        
        if (success) {
          final models = await llmService.getModels();
          final openAIModels = models.map((id) => OpenAIModel(
            id: id, 
            object: 'model',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ownedBy: 'openai'
          )).toList();
          
          setState(() {
            _isTestingConnection = false;
            _connectionSuccess = true;
            _availableModels = openAIModels;
            if (openAIModels.isNotEmpty) {
              _selectedModel = openAIModels.first;
            }
          });
        } else {
          throw Exception(llmService.error ?? 'Не удалось подключиться к OpenAI API');
        }
      } else {
        // Для LLMOps используем такой же подход с получением моделей
        final testConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1', // Заглушка для обязательных полей
          apiToken: 'test-token', // Заглушка для обязательных полей
          provider: 'llmops',
          llmopsBaseUrl: _llmopsUrlController.text.trim(),
          llmopsModel: 'default', // Временная заглушка, будет заменена на выбранную модель
          llmopsAuthHeader: _llmopsAuthController.text.trim().isEmpty 
              ? null 
              : _llmopsAuthController.text.trim(),
          defaultModel: 'default',
          reviewModel: 'default',
        );
        
        llmService.initializeProvider(testConfig);
        final success = await llmService.testConnection();
        
        if (success) {
          final models = await llmService.getModels();
          final llmopsModels = models.map((id) => OpenAIModel(
            id: id, 
            object: 'model',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ownedBy: 'llmops'
          )).toList();
          
          setState(() {
            _isTestingConnection = false;
            _connectionSuccess = true;
            _availableModels = llmopsModels;
            // Для LLMOps выбираем первую доступную модель по умолчанию
            if (llmopsModels.isNotEmpty) {
              _selectedModel = llmopsModels.first;
            }
          });
        } else {
          throw Exception(llmService.error ?? 'Не удалось подключиться к LLMOps серверу');
        }
      }
    } catch (e) {
      setState(() {
        _isTestingConnection = false;
        _connectionSuccess = false;
        _errorMessage = 'Ошибка подключения: $e';
      });
    }
  }
  
  Future<void> _saveAndProceed() async {
    AppConfig config;
    
    if (_selectedProvider == 'openai') {
      if (_selectedModel == null) return;
      
      config = AppConfig(
        apiUrl: _urlController.text.trim(),
        apiToken: _tokenController.text.trim(),
        provider: 'openai',
        defaultModel: _selectedModel!.id,
        reviewModel: _selectedModel!.id,
        selectedTemplateId: null,
        preferredFormat: _selectedFormat,
      );
    } else {
      if (_selectedModel == null) return;
      config = AppConfig(
        apiUrl: 'https://api.openai.com/v1', // Заглушка для обязательных полей
        apiToken: 'test-token', // Заглушка для обязательных полей
        provider: 'llmops',
        llmopsBaseUrl: _llmopsUrlController.text.trim(),
        llmopsModel: _selectedModel!.id, // Используем выбранную модель
        llmopsAuthHeader: _llmopsAuthController.text.trim().isEmpty
            ? null
            : _llmopsAuthController.text.trim(),
        defaultModel: _selectedModel!.id,
        reviewModel: _selectedModel!.id,
        selectedTemplateId: null,
        preferredFormat: _selectedFormat,
      );
    }
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final llmService = Provider.of<LLMService>(context, listen: false);
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    // Сохраняем конфигурацию
    await configService.saveConfig(config);
    
    // Инициализируем провайдера с новой конфигурацией
    llmService.initializeProvider(config);
    
    // Предварительно загружаем модели
    try {
      await llmService.getModels();
    } catch (e) {
      print('Ошибка при загрузке моделей: $e');
    }
    
    // Инициализируем шаблоны
    try {
      if (!templateService.isInitialized) {
        await templateService.init();
      }
    } catch (e) {
      print('Ошибка при инициализации шаблонов: $e');
    }
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка подключения'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Настройте подключение к LLM провайдеру',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Выбор провайдера
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Провайдер LLM',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                  DropdownMenuItem(value: 'llmops', child: Text('LLMOps')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    // Снимаем фокус с текущих полей перед переключением
                    FocusScope.of(context).unfocus();
                    
                    setState(() {
                      _selectedProvider = newValue;
                      _connectionSuccess = false;
                      _errorMessage = null;
                      _availableModels = [];
                      _selectedModel = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Выбор формата вывода
              const Text(
                'Предпочитаемый формат вывода',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: OutputFormat.values.map((format) {
                    return RadioListTile<OutputFormat>(
                      title: Text(format.displayName),
                      subtitle: Text('Файлы: .${format.fileExtension}'),
                      value: format,
                      groupValue: _selectedFormat,
                      onChanged: (OutputFormat? value) {
                        if (value != null) {
                          setState(() {
                            _selectedFormat = value;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Настройки OpenAI
              if (_selectedProvider == 'openai') ...[
                const Text(
                  'Настройки OpenAI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                
                // URL поле
                TextFormField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI API URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                  validator: (value) {
                    if (_selectedProvider == 'openai' && (value == null || value.isEmpty)) {
                      return 'Введите URL API';
                    }
                    if (value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                      return 'Введите корректный URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Token поле
                TextFormField(
                  controller: _tokenController,
                  focusNode: _tokenFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'API Token',
                    hintText: 'sk-...',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_selectedProvider == 'openai' && (value == null || value.isEmpty)) {
                      return 'Введите API токен';
                    }
                    return null;
                  },
                ),
              ],
              
              // Настройки LLMOps
              if (_selectedProvider == 'llmops') ...[
                const Text(
                  'Настройки LLMOps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                
                // Base URL поле
                TextFormField(
                  controller: _llmopsUrlController,
                  focusNode: _llmopsUrlFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'http://localhost:11434',
                  ),
                  validator: (value) {
                    if (_selectedProvider == 'llmops' && (value == null || value.isEmpty)) {
                      return 'Введите Base URL';
                    }
                    if (value != null && value.isNotEmpty && !Uri.tryParse(value)!.isAbsolute) {
                      return 'Введите корректный URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Authorization Header (необязательно)
                TextFormField(
                  controller: _llmopsAuthController,
                  focusNode: _llmopsAuthFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Authorization Header (необязательно)',
                    hintText: 'Bearer your-token',
                  ),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 24),
              
              // Кнопка проверки соединения
              ElevatedButton(
                onPressed: _isTestingConnection ? null : _testConnection,
                child: _isTestingConnection
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Проверка...'),
                        ],
                      )
                    : const Text('Проверить соединение'),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              
              if (_connectionSuccess) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Соединение установлено успешно!',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Список моделей
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Доступные модели:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    TextButton(
                      onPressed: _testConnection,
                      child: const Text('Обновить'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Список моделей (для OpenAI и LLMOps)
                if (_connectionSuccess && _availableModels.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableModels.length,
                      itemBuilder: (context, index) {
                        final model = _availableModels[index];
                        return RadioListTile<OpenAIModel>(
                          title: Text(model.id),
                          subtitle: Text('Provider: ${model.ownedBy}'),
                          value: model,
                          groupValue: _selectedModel,
                          onChanged: (OpenAIModel? value) {
                            setState(() {
                              _selectedModel = value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Кнопки
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Основная кнопка продолжения
                    ElevatedButton(
                      onPressed: _connectionSuccess && _selectedModel != null 
                          ? _saveAndProceed 
                          : null,
                      child: const Text('Приступить к работе'),
                    ),
                    const SizedBox(height: 8),
                    
                    // Кнопка для сброса конфигурации (в случае проблем)
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          final configService = Provider.of<ConfigService>(context, listen: false);
                          await configService.forceReset();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Конфигурация сброшена. Попробуйте заново.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Ошибка при сбросе: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Сбросить конфигурацию'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
