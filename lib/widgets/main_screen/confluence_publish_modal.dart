import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/publish_result.dart';
import '../../models/output_format.dart';
import '../../services/confluence_publisher.dart';
import '../../services/confluence_service.dart';
import '../../services/config_service.dart';
import '../../exceptions/confluence_exceptions.dart';
import '../../theme/app_theme.dart';

/// Modal dialog for publishing content to Confluence
class ConfluencePublishModal extends StatefulWidget {
  final String content;
  final String? suggestedTitle;

  const ConfluencePublishModal({
    super.key,
    required this.content,
    this.suggestedTitle,
  });

  @override
  State<ConfluencePublishModal> createState() => _ConfluencePublishModalState();
}

class _ConfluencePublishModalState extends State<ConfluencePublishModal> {
  final _formKey = GlobalKey<FormState>();
  final _parentPageUrlController = TextEditingController();
  final _pageUrlController = TextEditingController();
  final _titleController = TextEditingController();
  
  PublishOperation _selectedOperation = PublishOperation.create;
  bool _isPublishing = false;
  PublishResult? _publishResult;
  final List<PublishProgress> _progressSteps = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.suggestedTitle != null) {
      _titleController.text = widget.suggestedTitle!;
    } else {
      _titleController.clear();
    }
  }

  @override
  void dispose() {
    _parentPageUrlController.dispose();
    _pageUrlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.publish,
                    color: AppTheme.primaryRed,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Publish to Confluence',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close modal',
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose publishing option:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Radio buttons
                      Column(
                        children: [
                          RadioListTile<PublishOperation>(
                            title: Text(PublishOperation.create.displayName),
                            subtitle: const Text('Create a new page under a parent page'),
                            value: PublishOperation.create,
                            groupValue: _selectedOperation,
                            onChanged: _isPublishing ? null : (value) {
                              setState(() {
                                _selectedOperation = value!;
                              });
                            },
                            activeColor: AppTheme.primaryRed,
                          ),
                          RadioListTile<PublishOperation>(
                            title: Text(PublishOperation.update.displayName),
                            subtitle: const Text('Update an existing page with new content'),
                            value: PublishOperation.update,
                            groupValue: _selectedOperation,
                            onChanged: _isPublishing ? null : (value) {
                              setState(() {
                                _selectedOperation = value!;
                              });
                            },
                            activeColor: AppTheme.primaryRed,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Input fields based on selected operation
                      if (_selectedOperation == PublishOperation.create) ...[
                        TextFormField(
                          key: const Key('parent_page_url_field'),
                          controller: _parentPageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Parent Page URL',
                            hintText: 'https://company.atlassian.net/wiki/spaces/SPACE/pages/123456/Parent+Page',
                            helperText: 'URL of the parent page where the new page will be created',
                            prefixIcon: Icon(Icons.link),
                          ),
                          enabled: !_isPublishing,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('page_title_field'),
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Page Title',
                            hintText: 'Technical Specification',
                            helperText: 'Title for the new Confluence page',
                            prefixIcon: Icon(Icons.title),
                          ),
                          enabled: !_isPublishing,
                          onChanged: (_) => setState(() {}),
                        ),
                      ] else ...[
                        TextFormField(
                          key: const Key('page_url_field'),
                          controller: _pageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Page URL',
                            hintText: 'https://company.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title',
                            helperText: 'URL of the existing page to update',
                            prefixIcon: Icon(Icons.link),
                          ),
                          enabled: !_isPublishing,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      
                      // Progress indicators
                      if (_isPublishing) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Publishing Progress:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._progressSteps.map((progress) => _buildProgressStep(progress)),
                      ],
                      
                      // Result display
                      if (_publishResult != null) ...[
                        const SizedBox(height: 24),
                        _buildResultDisplay(_publishResult!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer with action buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.borderGray),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  if (_publishResult == null) ...[
                    ElevatedButton(
                      onPressed: _canPublish ? _publishContent : null,
                      child: _isPublishing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_selectedOperation == PublishOperation.create ? 'Create Page' : 'Update Page'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canPublish {
    if (_isPublishing) return false;
    if (_selectedOperation == PublishOperation.create) {
      return _parentPageUrlController.text.trim().isNotEmpty &&
             _titleController.text.trim().isNotEmpty;
    } else {
      return _pageUrlController.text.trim().isNotEmpty;
    }
  }

  void _publishContent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isPublishing = true;
      _progressSteps.clear();
      _publishResult = null;
    });
    
    final confluenceService = Provider.of<ConfluenceService>(context, listen: false);
    final publisher = ConfluencePublisher(confluenceService);
    
    // Подписываемся на обновления прогресса
    final subscription = publisher.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          // Добавляем новый шаг или обновляем существующий
          final existingIndex = _progressSteps.indexWhere((p) => p.step == progress.step);
          if (existingIndex >= 0) {
            _progressSteps[existingIndex] = progress;
          } else {
            _progressSteps.add(progress);
          }
        });
      }
    });
    
    try {
      // Определяем, какой контент отправлять в зависимости от формата
      final configService = Provider.of<ConfigService>(context, listen: false);
      final format = configService.config?.outputFormat;
      String contentToPublish = widget.content;
      
      // Если формат Markdown, конвертируем в Confluence Storage Format
      if (format == OutputFormat.markdown) {
        _emitProgress('Конвертация Markdown в Confluence Storage Format...');
        // Конвертация будет выполнена внутри publisher
      }
      
      PublishResult result;
      if (_selectedOperation == PublishOperation.create) {
        result = await publisher.publishToNewPage(
          parentPageUrl: _parentPageUrlController.text.trim(),
          title: _titleController.text.trim(),
          content: contentToPublish,
        );
      } else {
        result = await publisher.publishToExistingPage(
          pageUrl: _pageUrlController.text.trim(),
          content: contentToPublish,
        );
      }
      
      if (mounted) {
        setState(() {
          _publishResult = result;
          _isPublishing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _publishResult = PublishResult.failure(
            operation: _selectedOperation,
            errorMessage: e is ConfluenceException 
                ? '${(e).message} (${e.type})' 
                : e.toString(),
          );
          _isPublishing = false;
        });
      }
    } finally {
      subscription.cancel();
      publisher.dispose();
    }
  }

  void _resetModal() {
    setState(() {
      _publishResult = null;
      _isPublishing = false;
      _progressSteps.clear();
    });
  }
  
  void _emitProgress(String message) {
    if (mounted) {
      setState(() {
        _progressSteps.add(PublishProgress.step(
          step: 'custom_step_${_progressSteps.length}',
          message: message,
          progress: 0.5,
        ));
      });
    }
  }

  Widget _buildProgressStep(PublishProgress progress) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Icon(
            progress.isComplete ? Icons.check_circle : Icons.hourglass_empty,
            color: progress.isComplete ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(progress.message),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDisplay(PublishResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.statusMessage,
                  style: TextStyle(
                    color: result.success ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(result.detailedMessage),
        ],
      ),
    );
  }
}