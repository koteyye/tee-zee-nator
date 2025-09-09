import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/config_service.dart';
import '../../services/confluence_service.dart';
import '../../services/confluence_content_processor.dart';
import '../../services/confluence_session_manager.dart';
import '../../services/confluence_debouncer.dart';
import '../../services/confluence_error_handler.dart';
import '../../models/generation_history.dart';
import '../../models/output_format.dart';
import '../../theme/app_theme.dart';
import '../common/enhanced_tooltip.dart';
import '../common/accessibility_wrapper.dart';
import 'confluence_hint_widget.dart';

class InputPanel extends StatefulWidget {
  final TextEditingController rawRequirementsController;
  final TextEditingController changesController;
  final String generatedTz;
  final List<GenerationHistory> history;
  final bool isGenerating;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final VoidCallback onClear;
  final ValueChanged<GenerationHistory> onHistoryItemTap;

  const InputPanel({
    super.key,
    required this.rawRequirementsController,
    required this.changesController,
    required this.generatedTz,
    required this.history,
    required this.isGenerating,
    required this.errorMessage,
    required this.onGenerate,
    required this.onClear,
    required this.onHistoryItemTap,
  });

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> {
  ConfluenceContentProcessor? _contentProcessor;
  ConfluenceService? _confluenceService;
  ConfluenceDebouncer? _debouncer;

  // Config change handling
  bool _didAttachConfigListener = false;
  bool _autoTriggeredOnce = false;
  
  // Processing state
  bool _isProcessingRawRequirements = false;
  bool _isProcessingChanges = false;
  
  // Processed content storage (internal use only)
  String _processedRawRequirements = '';
  String _processedChanges = '';
  
  // Keys for debouncing operations
  static const String _rawRequirementsKey = 'raw_requirements';
  static const String _changesKey = 'changes';
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupTextFieldListeners();
    _attachConfigListener();

    // One-shot auto-processing if text already present and services ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contentProcessor != null) {
        ConfluenceErrorHandler.logInfo(
          'Post-frame: auto trigger processing for existing text',
          context: 'InputPanel.initState',
        );
        _triggerOneShotProcessing();
      }
    });
  }
  
  @override
  void dispose() {
    _debouncer?.dispose();
    
    // Unregister from session manager before disposing
    if (_contentProcessor != null) {
      final sessionManager = ConfluenceSessionManager();
      sessionManager.unregisterProcessor(_contentProcessor!);
      _contentProcessor!.dispose();
    }

    _detachConfigListener();
    
    super.dispose();
  }
  
  void _initializeServices() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final confluenceConfig = configService.getConfluenceConfig();
    
    ConfluenceErrorHandler.logInfo(
      'Initializing services; config present=${confluenceConfig != null}, complete=${confluenceConfig?.isConfigurationComplete == true}',
      context: 'InputPanel._initializeServices',
    );

    // Debouncer must be available regardless of Confluence readiness
    _debouncer ??= ConfluenceDebouncer();
    
    if (confluenceConfig != null && confluenceConfig.isConfigurationComplete) {
      _confluenceService = ConfluenceService();
      _confluenceService!.initialize(confluenceConfig);
      _contentProcessor = ConfluenceContentProcessor(_confluenceService!);
      
      // Register with session manager for automatic cleanup
      final sessionManager = ConfluenceSessionManager();
      sessionManager.initialize();
      sessionManager.registerProcessor(_contentProcessor!);

      final host = Uri.tryParse(confluenceConfig.sanitizedBaseUrl)?.host ?? 'unknown';
      ConfluenceErrorHandler.logInfo(
        'Confluence services initialized for host $host',
        context: 'InputPanel._initializeServices',
      );
    } else {
      ConfluenceErrorHandler.logInfo(
        'Confluence config missing or incomplete; skipping Confluence initialization',
        context: 'InputPanel._initializeServices',
      );
    }
  }
  
  void _setupTextFieldListeners() {
    widget.rawRequirementsController.addListener(_onRawRequirementsChanged);
    widget.changesController.addListener(_onChangesChanged);
    ConfluenceErrorHandler.logInfo(
      'Text field listeners attached',
      context: 'InputPanel._setupTextFieldListeners',
    );
  }

  void _attachConfigListener() {
    if (_didAttachConfigListener) return;
    final configService = Provider.of<ConfigService>(context, listen: false);
    configService.addListener(_onConfigChanged);
    _didAttachConfigListener = true;
    ConfluenceErrorHandler.logInfo(
      'Config listener attached',
      context: 'InputPanel._attachConfigListener',
    );
  }

  void _detachConfigListener() {
    if (!_didAttachConfigListener) return;
    final configService = Provider.of<ConfigService>(context, listen: false);
    configService.removeListener(_onConfigChanged);
    _didAttachConfigListener = false;
    ConfluenceErrorHandler.logInfo(
      'Config listener detached',
      context: 'InputPanel._detachConfigListener',
    );
  }

  void _onConfigChanged() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final conf = configService.getConfluenceConfig();

    if (conf != null && conf.isConfigurationComplete) {
      if (_contentProcessor == null) {
        ConfluenceErrorHandler.logInfo(
          'Config completed detected; initializing Confluence services',
          context: 'InputPanel._onConfigChanged',
        );
        _confluenceService = ConfluenceService();
        _confluenceService!.initialize(conf);
        _contentProcessor = ConfluenceContentProcessor(_confluenceService!);
        _debouncer ??= ConfluenceDebouncer();

        final sessionManager = ConfluenceSessionManager();
        sessionManager.initialize();
        sessionManager.registerProcessor(_contentProcessor!);

        // Trigger once for existing text
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _triggerOneShotProcessing();
        });
      }
    } else {
      // Config became incomplete; teardown
      if (_contentProcessor != null) {
        ConfluenceErrorHandler.logInfo(
          'Config became incomplete; tearing down Confluence services',
          context: 'InputPanel._onConfigChanged',
        );
        final sessionManager = ConfluenceSessionManager();
        sessionManager.unregisterProcessor(_contentProcessor!);
        _contentProcessor!.dispose();
        _contentProcessor = null;
        _confluenceService = null;
        // keep debouncer alive
      }
    }
  }

  void _triggerOneShotProcessing() {
    if (_autoTriggeredOnce) {
      return;
    }
    final configService = Provider.of<ConfigService>(context, listen: false);
    final conf = configService.getConfluenceConfig();
    if (conf == null || !conf.isConfigurationComplete || _contentProcessor == null) {
      ConfluenceErrorHandler.logInfo(
        'One-shot processing skipped (services not ready)',
        context: 'InputPanel._triggerOneShotProcessing',
      );
      return;
    }
    _autoTriggeredOnce = true;

    final raw = widget.rawRequirementsController.text;
    final ch = widget.changesController.text;

    ConfluenceErrorHandler.logInfo(
      'One-shot processing start: rawLen=${raw.length}, changesLen=${ch.length}',
      context: 'InputPanel._triggerOneShotProcessing',
    );

    if (raw.isNotEmpty) {
      _processConfluenceLinks(raw, isRawRequirements: true);
    }
    if (ch.isNotEmpty) {
      _processConfluenceLinks(ch, isRawRequirements: false);
    }
  }
  
  void _onRawRequirementsChanged() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final conf = configService.getConfluenceConfig();
    if (conf == null || !conf.isConfigurationComplete || _debouncer == null) {
      ConfluenceErrorHandler.logInfo(
        'Skip raw requirements change: confComplete=${conf?.isConfigurationComplete == true}, debouncerReady=${_debouncer != null}',
        context: 'InputPanel._onRawRequirementsChanged',
      );
      return;
    }
    
    final text = widget.rawRequirementsController.text;
    ConfluenceErrorHandler.logInfo(
      'Raw requirements changed, length=${text.length}. Scheduling processing.',
      context: 'InputPanel._onRawRequirementsChanged',
    );
    
    _debouncer!.adaptiveDebounce(
      _rawRequirementsKey,
      text,
      () => _processConfluenceLinks(text, isRawRequirements: true),
    );
  }
  
  void _onChangesChanged() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final conf = configService.getConfluenceConfig();
    if (conf == null || !conf.isConfigurationComplete || _debouncer == null) {
      ConfluenceErrorHandler.logInfo(
        'Skip changes change: confComplete=${conf?.isConfigurationComplete == true}, debouncerReady=${_debouncer != null}',
        context: 'InputPanel._onChangesChanged',
      );
      return;
    }
    
    final text = widget.changesController.text;
    ConfluenceErrorHandler.logInfo(
      'Changes text changed, length=${text.length}. Scheduling processing.',
      context: 'InputPanel._onChangesChanged',
    );
    
    _debouncer!.adaptiveDebounce(
      _changesKey,
      text,
      () => _processConfluenceLinks(text, isRawRequirements: false),
    );
  }
  
  Future<void> _processConfluenceLinks(String text, {required bool isRawRequirements}) async {
    if (_contentProcessor == null) {
      ConfluenceErrorHandler.logInfo(
        'Skip processing: contentProcessor is null',
        context: 'InputPanel._processConfluenceLinks',
      );
      return;
    }
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final confluenceConfig = configService.getConfluenceConfig();
    
    if (confluenceConfig == null || !confluenceConfig.isConfigurationComplete) {
      ConfluenceErrorHandler.logInfo(
        'Skip processing: config missing or incomplete',
        context: 'InputPanel._processConfluenceLinks',
      );
      return;
    }

    ConfluenceErrorHandler.logInfo(
      'Start processing ${isRawRequirements ? 'requirements' : 'changes'}; length=${text.length}',
      context: 'InputPanel._processConfluenceLinks',
    );
    
    setState(() {
      if (isRawRequirements) {
        _isProcessingRawRequirements = true;
      } else {
        _isProcessingChanges = true;
      }
    });
    
    try {
      final processedText = await _contentProcessor!.processText(
        text,
        confluenceConfig,
        debounce: false, // We handle debouncing at the widget level
        enableOptimizations: true, // Enable performance optimizations
      );
      
      final changed = processedText != text;
      ConfluenceErrorHandler.logInfo(
        'Finished processing ${isRawRequirements ? 'requirements' : 'changes'}; changed=$changed, resultLen=${processedText.length}',
        context: 'InputPanel._processConfluenceLinks',
      );

      setState(() {
        if (isRawRequirements) {
          _processedRawRequirements = processedText;
          _isProcessingRawRequirements = false;
        } else {
          _processedChanges = processedText;
          _isProcessingChanges = false;
        }
      });
    } catch (e) {
      setState(() {
        if (isRawRequirements) {
          _processedRawRequirements = text; // Fallback to original text
          _isProcessingRawRequirements = false;
        } else {
          _processedChanges = text; // Fallback to original text
          _isProcessingChanges = false;
        }
      });
      
      // Log error but don't show to user to avoid disrupting workflow
      if (e is Exception) {
        ConfluenceErrorHandler.logError(
          e,
          context: 'Processing Confluence links in ${isRawRequirements ? "requirements" : "changes"} field',
        );
      } else {
        ConfluenceErrorHandler.logWarning(
          'Error processing Confluence links: $e',
          context: 'InputPanel',
        );
      }
    }
  }
  
  void _onClear() {
    ConfluenceErrorHandler.logInfo(
      'Clear triggered: resetting processed state and caches',
      context: 'InputPanel._onClear',
    );
    // Clear processed content when clearing fields
    setState(() {
      _processedRawRequirements = '';
      _processedChanges = '';
      _isProcessingRawRequirements = false;
      _isProcessingChanges = false;
    });
    
    // Cancel any pending processing
    _debouncer?.cancel(_rawRequirementsKey);
    _debouncer?.cancel(_changesKey);
    
    // Clear all cached and session data (requirement 3.7)
    _contentProcessor?.clearAllData();
    
    // Call the original clear callback
    widget.onClear();
  }
  
  void _onGenerate() {
    // Use processed content for generation if available
    final configService = Provider.of<ConfigService>(context, listen: false);
    final conf = configService.getConfluenceConfig();
    
    if (conf != null && conf.isConfigurationComplete) {
      final useProcessedRaw = _processedRawRequirements.isNotEmpty;
      final useProcessedChanges = _processedChanges.isNotEmpty;
      ConfluenceErrorHandler.logInfo(
        'Generate pressed with Confluence: useProcessedRaw=$useProcessedRaw, useProcessedChanges=$useProcessedChanges',
        context: 'InputPanel._onGenerate',
      );

      // Temporarily replace controller text with processed content for generation
      final originalRawText = widget.rawRequirementsController.text;
      final originalChangesText = widget.changesController.text;
      
      if (_processedRawRequirements.isNotEmpty) {
        widget.rawRequirementsController.text = _processedRawRequirements;
      }
      
      if (_processedChanges.isNotEmpty) {
        widget.changesController.text = _processedChanges;
      }
      
      // Call the original generate callback
      widget.onGenerate();
      
      // Restore original text to show links to user
      Future.microtask(() {
        widget.rawRequirementsController.text = originalRawText;
        widget.changesController.text = originalChangesText;
      });
    } else {
      ConfluenceErrorHandler.logInfo(
        'Generate pressed without Confluence configuration; proceeding with original text',
        context: 'InputPanel._onGenerate',
      );
      // No Confluence processing, use original callback
      widget.onGenerate();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Сырые требования
                AccessibilityWrapper(
                  label: 'Raw requirements section',
                  child: Row(
                    children: [
                      const Text(
                        'Сырые требования:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (_isProcessingRawRequirements) ...[
                        const SizedBox(width: 8),
                        EnhancedTooltip(
                          message: 'Processing Confluence links in your requirements',
                          icon: Icons.link,
                          child: const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Обработка ссылок...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryRed,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AccessibleFormField(
                  label: 'Raw requirements text input',
                  hint: 'Enter your raw requirements here. You can include Confluence links if integration is enabled.',
                  required: true,
                  child: EnhancedTooltip(
                    message: 'Enter your raw requirements here',
                    richMessage: 'You can include Confluence links if integration is enabled. Use Ctrl+Enter to generate specification.',
                    keyboardShortcut: 'Ctrl+Enter to generate',
                    child: Container(
                      height: widget.generatedTz.isEmpty ? 200 : 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _isProcessingRawRequirements 
                              ? AppTheme.primaryRed.withOpacity(0.5)
                              : AppTheme.borderGray,
                          width: _isProcessingRawRequirements ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isProcessingRawRequirements ? [
                          BoxShadow(
                            color: AppTheme.primaryRed.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: widget.rawRequirementsController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Введите сырые требования...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            suffixIcon: widget.rawRequirementsController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      widget.rawRequirementsController.clear();
                                      _onClear();
                                    },
                                    tooltip: 'Clear requirements',
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Confluence hint widget
                const ConfluenceHintWidget(),
                
                const SizedBox(height: 16),
                
                // Поле изменений (показывается после первой генерации)
                if (widget.generatedTz.isNotEmpty) ...[
                  AccessibilityWrapper(
                    label: 'Changes and additions section',
                    child: Row(
                      children: [
                        const Text(
                          'Изменения и дополнения:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (_isProcessingChanges) ...[
                          const SizedBox(width: 8),
                          EnhancedTooltip(
                            message: 'Processing Confluence links in your changes',
                            icon: Icons.link,
                            child: const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Обработка ссылок...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryRed,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AccessibleFormField(
                    label: 'Changes and additions text input',
                    hint: 'Enter changes or additions to your requirements. You can include Confluence links if integration is enabled.',
                    child: EnhancedTooltip(
                      message: 'Enter changes or additions to your requirements',
                      richMessage: 'You can include Confluence links if integration is enabled. Use Ctrl+Enter to update specification.',
                      keyboardShortcut: 'Ctrl+Enter to update',
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: _isProcessingChanges 
                                ? AppTheme.primaryRed.withOpacity(0.5)
                                : AppTheme.borderGray,
                            width: _isProcessingChanges ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _isProcessingChanges ? [
                            BoxShadow(
                              color: AppTheme.primaryRed.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: widget.changesController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Введите изменения или дополнения...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              suffixIcon: widget.changesController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        widget.changesController.clear();
                                      },
                                      tooltip: 'Clear changes',
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Кнопки
                Row(
                  children: [
                    Consumer<ConfigService>(
                      builder: (context, configService, child) {
                        final canGenerate = configService.config != null && 
                                          widget.rawRequirementsController.text.trim().isNotEmpty &&
                                          !widget.isGenerating;
                        
                        return AccessibleButton(
                          label: widget.isGenerating 
                              ? 'Generating technical specification, please wait'
                              : canGenerate
                                  ? (widget.generatedTz.isEmpty ? 'Generate technical specification' : 'Update technical specification')
                                  : 'Generate button disabled - enter requirements first',
                          hint: widget.isGenerating 
                              ? 'Please wait while we generate your specification'
                              : canGenerate
                                  ? 'Click to generate technical specification using your requirements'
                                  : 'Enter requirements to enable generation',
                          enabled: canGenerate,
                          onPressed: canGenerate ? _onGenerate : null,
                          child: ButtonTooltip(
                            action: widget.isGenerating 
                                ? 'Generating...'
                                : canGenerate
                                    ? 'Generate technical specification'
                                    : 'Enter requirements to enable generation',
                            shortcut: 'Ctrl+Enter',
                            enabled: canGenerate,
                            child: ElevatedButton(
                              onPressed: canGenerate ? _onGenerate : null,
                              child: widget.isGenerating 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(widget.generatedTz.isEmpty ? 'Сгенерировать ТЗ' : 'Обновить ТЗ'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    AccessibleButton(
                      label: 'Clear all input fields and processed data',
                      hint: 'Clear all fields and reset the form to start over',
                      onPressed: _onClear,
                      child: ButtonTooltip(
                        action: 'Clear all fields and reset the form',
                        shortcut: 'Ctrl+R',
                        child: ElevatedButton.icon(
                          onPressed: _onClear,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Очистить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade50,
                            foregroundColor: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // История запросов
                if (widget.history.isNotEmpty) ...[
                  const Text(
                    'История запросов:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: widget.history.length,
                      itemBuilder: (context, index) {
                        final item = widget.history[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${item.timestamp.day}.${item.timestamp.month}.${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Модель: ${item.model}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.format == OutputFormat.markdown 
                                          ? Colors.blue.shade100 
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: item.format == OutputFormat.markdown 
                                            ? Colors.blue.shade300 
                                            : Colors.orange.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      item.format.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: item.format == OutputFormat.markdown 
                                            ? Colors.blue.shade700 
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.rawRequirements.length > 50
                                    ? '${item.rawRequirements.substring(0, 50)}...'
                                    : item.rawRequirements,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          onTap: () => widget.onHistoryItemTap(item),
                        );
                      },
                    ),
                  ),
                ],
                
                // Ошибка
                if (widget.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
