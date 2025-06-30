import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/openai_service.dart';
import '../models/app_config.dart';
import '../models/openai_model.dart';
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
  
  bool _isTestingConnection = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  OpenAIModel? _selectedModel;
  
  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }
  
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isTestingConnection = true;
      _connectionSuccess = false;
      _errorMessage = null;
    });
    
    final openAIService = Provider.of<OpenAIService>(context, listen: false);
    final success = await openAIService.testConnection(
      _urlController.text.trim(),
      _tokenController.text.trim(),
    );
    
    setState(() {
      _isTestingConnection = false;
      _connectionSuccess = success;
      if (!success) {
        _errorMessage = openAIService.error ?? 'Не удалось подключиться к OpenAI API';
      } else if (openAIService.availableModels.isNotEmpty) {
        _selectedModel = openAIService.availableModels.first;
      }
    });
  }
  
  Future<void> _saveAndProceed() async {
    if (_selectedModel == null) return;
    
    final config = AppConfig(
      apiUrl: _urlController.text.trim(),
      apiToken: _tokenController.text.trim(),
      selectedModel: _selectedModel!.id,
    );
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    await configService.saveConfig(config);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MainScreen()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка подключения'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Настройте подключение к OpenAI API',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // URL поле
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'OpenAI API URL',
                  hintText: 'https://api.openai.com/v1',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите URL API';
                  }
                  if (!Uri.tryParse(value)!.isAbsolute) {
                    return 'Введите корректный URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Token поле
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  hintText: 'sk-...',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите API токен';
                  }
                  return null;
                },
              ),
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
                      onPressed: () async {
                        final openAIService = Provider.of<OpenAIService>(context, listen: false);
                        await openAIService.testConnection(
                          _urlController.text.trim(),
                          _tokenController.text.trim(),
                        );
                        if (openAIService.availableModels.isNotEmpty && _selectedModel == null) {
                          setState(() {
                            _selectedModel = openAIService.availableModels.first;
                          });
                        }
                      },
                      child: const Text('Обновить'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Consumer<OpenAIService>(
                  builder: (context, openAIService, child) {
                    if (openAIService.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    
                    if (openAIService.availableModels.isEmpty) {
                      return Column(
                        children: [
                          const Text('Модели не найдены'),
                          const SizedBox(height: 8),
                          if (openAIService.error != null)
                            Text(
                              'Ошибка: ${openAIService.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      );
                    }
                    
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: openAIService.availableModels.length,
                        itemBuilder: (context, index) {
                          final model = openAIService.availableModels[index];
                          return RadioListTile<OpenAIModel>(
                            title: Text(model.id),
                            subtitle: Text('Owner: ${model.ownedBy}'),
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
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Кнопка продолжения
                ElevatedButton(
                  onPressed: _selectedModel != null ? _saveAndProceed : null,
                  child: const Text('Приступить к работе'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
