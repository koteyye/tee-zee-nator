import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/confluence_config.dart';
import '../models/publish_result.dart';
import '../exceptions/confluence_exceptions.dart';
import 'confluence_service.dart';
import 'confluence_error_handler.dart';

/// Service for managing Confluence publishing workflows
/// 
/// This service handles publishing generated content to Confluence including:
/// - Creating new pages with parent page validation
/// - Updating existing pages with version management
/// - Progress tracking with real-time updates
/// - Comprehensive error handling and recovery
class ConfluencePublisher {
  static const String _userAgent = 'TeeZeeNator/1.1.0';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  
  final ConfluenceService _confluenceService;
  final StreamController<PublishProgress> _progressController;
  
  ConfluenceConfig? get _config => _confluenceService.config;
  
  /// Stream of publishing progress updates
  Stream<PublishProgress> get progressStream => _progressController.stream;
  
  /// Creates a new ConfluencePublisher instance
  ConfluencePublisher(this._confluenceService) 
      : _progressController = StreamController<PublishProgress>.broadcast();
  
  /// Disposes of resources
  void dispose() {
    _progressController.close();
  }
  
  /// Publishes content to a new Confluence page
  /// 
  /// [parentPageUrl] - URL of the parent page where the new page will be created
  /// [title] - Title for the new page
  /// [content] - Markdown content to publish
  /// 
  /// Returns PublishResult with success status and page information
  Future<PublishResult> publishToNewPage({
    required String parentPageUrl,
    required String title,
    required String content,
  }) async {
    if (!_confluenceService.isConfigured) {
      throw const ConfluenceValidationException(
        'Confluence service is not configured',
        fieldName: 'configuration',
        recoveryAction: 'Configure Confluence connection in settings',
      );
    }

    if (parentPageUrl.isEmpty) {
      throw const ConfluenceValidationException(
        'Parent page URL cannot be empty',
        fieldName: 'parentPageUrl',
        recoveryAction: 'Provide a valid parent page URL',
      );
    }

    if (title.isEmpty) {
      throw const ConfluenceValidationException(
        'Page title cannot be empty',
        fieldName: 'title',
        recoveryAction: 'Provide a title for the new page',
      );
    }

    if (content.isEmpty) {
      throw const ConfluenceValidationException(
        'Content cannot be empty',
        fieldName: 'content',
        recoveryAction: 'Provide content to publish',
      );
    }

    try {
      // Step 1: Validate parent page
      _emitProgress(PublishProgress.step(
        step: 'validate_parent',
        message: 'Checking parent page...',
        progress: 0.1,
      ));

      ConfluenceErrorHandler.logInfo('Starting page creation', context: 'publishToNewPage');
      final parentPage = await _confluenceService.getPageInfo(parentPageUrl);
      
      // Step 2: Convert content to Confluence format
      _emitProgress(PublishProgress.step(
        step: 'convert_content',
        message: 'Converting content to Confluence format...',
        progress: 0.3,
      ));

      final confluenceContent = _convertMarkdownToConfluence(content);
      
      // Step 3: Create new page
      _emitProgress(PublishProgress.step(
        step: 'create_page',
        message: 'Creating new page...',
        progress: 0.6,
      ));

      final pageId = await _createPage(
        parentId: parentPage.id,
        spaceKey: parentPage.spaceKey,
        title: title,
        content: confluenceContent,
      );
      
      // Step 4: Generate page URL
      final pageUrl = _generatePageUrl(parentPage.url, pageId, title);
      
      // Step 5: Complete
      _emitProgress(PublishProgress.complete(
        step: 'complete',
        message: 'Page successfully created',
      ));

      ConfluenceErrorHandler.logInfo('Page created successfully: $pageUrl', context: 'publishToNewPage');

      return PublishResult.success(
        operation: PublishOperation.create,
        pageUrl: pageUrl,
        pageId: pageId,
        title: title,
      );

    } catch (e) {
      final errorMessage = e is ConfluenceException ? e.message : e.toString();
      
      ConfluenceErrorHandler.logError(e is Exception ? e : Exception(e.toString()), context: 'publishToNewPage');
      
      _emitProgress(PublishProgress.error(
        step: 'error',
        message: 'Failed to create page',
        errorMessage: errorMessage,
      ));

      return PublishResult.failure(
        operation: PublishOperation.create,
        errorMessage: errorMessage,
      );
    }
  }
  
  /// Publishes content to an existing Confluence page
  /// 
  /// [pageUrl] - URL of the existing page to update
  /// [content] - Markdown content to publish
  /// 
  /// Returns PublishResult with success status and page information
  Future<PublishResult> publishToExistingPage({
    required String pageUrl,
    required String content,
  }) async {
    if (!_confluenceService.isConfigured) {
      throw const ConfluenceValidationException(
        'Confluence service is not configured',
        fieldName: 'configuration',
        recoveryAction: 'Configure Confluence connection in settings',
      );
    }

    if (pageUrl.isEmpty) {
      throw const ConfluenceValidationException(
        'Page URL cannot be empty',
        fieldName: 'pageUrl',
        recoveryAction: 'Provide a valid page URL',
      );
    }

    if (content.isEmpty) {
      throw const ConfluenceValidationException(
        'Content cannot be empty',
        fieldName: 'content',
        recoveryAction: 'Provide content to publish',
      );
    }

    try {
      // Step 1: Validate existing page
      _emitProgress(PublishProgress.step(
        step: 'validate_page',
        message: 'Checking existing page...',
        progress: 0.1,
      ));

      final existingPage = await _confluenceService.getPageInfo(pageUrl);
      
      // Step 2: Convert content to Confluence format
      _emitProgress(PublishProgress.step(
        step: 'convert_content',
        message: 'Converting content to Confluence format...',
        progress: 0.3,
      ));

      final confluenceContent = _convertMarkdownToConfluence(content);
      
      // Step 3: Update existing page
      _emitProgress(PublishProgress.step(
        step: 'update_page',
        message: 'Updating existing page...',
        progress: 0.6,
      ));

      await _updatePage(
        pageId: existingPage.id,
        title: existingPage.title,
        content: confluenceContent,
        version: existingPage.version + 1,
      );
      
      // Step 4: Complete
      _emitProgress(PublishProgress.complete(
        step: 'complete',
        message: 'Page successfully updated',
      ));

      return PublishResult.success(
        operation: PublishOperation.update,
        pageUrl: pageUrl,
        pageId: existingPage.id,
        title: existingPage.title,
      );

    } catch (e) {
      final errorMessage = e is ConfluenceException ? e.message : e.toString();
      
      _emitProgress(PublishProgress.error(
        step: 'error',
        message: 'Failed to update page',
        errorMessage: errorMessage,
      ));

      return PublishResult.failure(
        operation: PublishOperation.update,
        errorMessage: errorMessage,
      );
    }
  }
  
  /// Creates a new page in Confluence
  Future<String> _createPage({
    required String parentId,
    required String spaceKey,
    required String title,
    required String content,
  }) async {
    final url = '${_config!.apiBaseUrl}/content';
    
    final requestBody = {
      'type': 'page',
      'title': title,
      'space': {'key': spaceKey},
      'ancestors': [{'id': parentId}],
      'body': {
        'storage': {
          'value': content,
          'representation': 'storage',
        }
      }
    };

    debugPrint('Creating Confluence page: $title in space $spaceKey');
    
    final response = await _sendRequest(
      method: 'POST',
      url: url,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final pageId = responseData['id'] as String;
      debugPrint('Successfully created page with ID: $pageId');
      return pageId;
    } else {
      await _handleCreatePageError(response, title);
      throw StateError('This should not be reached'); // For type safety
    }
  }
  
  /// Updates an existing page in Confluence
  Future<void> _updatePage({
    required String pageId,
    required String title,
    required String content,
    required int version,
  }) async {
    final url = '${_config!.apiBaseUrl}/content/$pageId';
    
    final requestBody = {
      'id': pageId,
      'type': 'page',
      'title': title,
      'version': {'number': version},
      'body': {
        'storage': {
          'value': content,
          'representation': 'storage',
        }
      }
    };

    debugPrint('Updating Confluence page: $pageId (version $version)');
    
    final response = await _sendRequest(
      method: 'PUT',
      url: url,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      debugPrint('Successfully updated page: $pageId');
    } else {
      await _handleUpdatePageError(response, pageId, version);
    }
  }
  
  /// Sends HTTP request with authentication and error handling
  Future<http.Response> _sendRequest({
    required String method,
    required String url,
    required Map<String, dynamic> body,
  }) async {
    final headers = _buildHeaders();
    final jsonBody = json.encode(body);
    
    int attempts = 0;
    Duration delay = const Duration(milliseconds: 500);
    
    while (attempts < _maxRetries) {
      attempts++;
      
      try {
        late http.Response response;
        
        switch (method.toUpperCase()) {
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: jsonBody,
            ).timeout(_defaultTimeout);
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse(url),
              headers: headers,
              body: jsonBody,
            ).timeout(_defaultTimeout);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $method');
        }
        
        // Check for rate limiting
        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfter(response.headers);
          if (attempts < _maxRetries) {
            debugPrint('Rate limited, retrying after ${retryAfter.inSeconds} seconds');
            await Future.delayed(retryAfter);
            continue;
          } else {
            throw ConfluenceExceptionFactory.rateLimitExceeded(
              retryAfterSeconds: retryAfter.inSeconds,
              details: 'Maximum retry attempts exceeded',
            );
          }
        }
        
        return response;
        
      } catch (e) {
        if (e is ConfluenceException) {
          rethrow;
        }
        
        if (attempts >= _maxRetries) {
          throw ConfluenceExceptionFactory.connectionFailed(
            baseUrl: _config?.baseUrl ?? 'unknown',
            details: 'Network error after $attempts attempts: ${e.toString()}',
          );
        }
        
        debugPrint('Network error on attempt $attempts, retrying...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
    
    throw ConfluenceExceptionFactory.connectionFailed(
      baseUrl: _config?.baseUrl ?? 'unknown',
      details: 'Maximum retry attempts exceeded',
    );
  }
  
  /// Handles errors when creating a new page
  Future<void> _handleCreatePageError(http.Response response, String title) async {
    final errorMessage = _extractErrorMessage(response);
    
    switch (response.statusCode) {
      case 400:
        throw ConfluenceValidationException(
          'Invalid page data provided',
          fieldName: 'page_data',
          technicalDetails: 'HTTP 400: $errorMessage',
          recoveryAction: 'Check the page title and parent page are valid',
        );
      case 401:
        throw ConfluenceExceptionFactory.authenticationFailed(
          details: 'HTTP 401: $errorMessage',
        );
      case 403:
        throw ConfluenceExceptionFactory.authorizationFailed(
          operation: 'create page',
          details: 'HTTP 403: $errorMessage',
        );
      case 409:
        throw ConfluenceValidationException(
          'A page with this title already exists in the space',
          fieldName: 'title',
          technicalDetails: 'HTTP 409: $errorMessage',
          recoveryAction: 'Choose a different title or update the existing page',
        );
      default:
        throw ConfluenceNetworkException(
          'Failed to create page: $title',
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: $errorMessage',
          recoveryAction: 'Check your permissions and try again',
        );
    }
  }
  
  /// Handles errors when updating an existing page
  Future<void> _handleUpdatePageError(http.Response response, String pageId, int version) async {
    final errorMessage = _extractErrorMessage(response);
    
    switch (response.statusCode) {
      case 400:
        throw ConfluenceValidationException(
          'Invalid page update data provided',
          fieldName: 'page_data',
          technicalDetails: 'HTTP 400: $errorMessage',
          recoveryAction: 'Check the page content and version number are valid',
        );
      case 401:
        throw ConfluenceExceptionFactory.authenticationFailed(
          details: 'HTTP 401: $errorMessage',
        );
      case 403:
        throw ConfluenceExceptionFactory.authorizationFailed(
          operation: 'update page',
          details: 'HTTP 403: $errorMessage',
        );
      case 404:
        throw ConfluenceContentProcessingException(
          'Page not found or no longer accessible',
          technicalDetails: 'HTTP 404: $errorMessage',
          recoveryAction: 'Verify the page still exists and you have access to it',
        );
      case 409:
        throw ConfluenceValidationException(
          'Page version conflict - the page has been modified by another user',
          fieldName: 'version',
          technicalDetails: 'HTTP 409: $errorMessage',
          recoveryAction: 'Refresh the page and try again',
        );
      default:
        throw ConfluenceNetworkException(
          'Failed to update page: $pageId',
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: $errorMessage',
          recoveryAction: 'Check your permissions and try again',
        );
    }
  }
  
  /// Converts Markdown content to Confluence storage format
  String _convertMarkdownToConfluence(String markdownContent) {
    // Расширенная конвертация Markdown в Confluence Storage Format
    String confluenceContent = markdownContent;
    
    // Конвертация заголовков
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true),
      (match) {
        final level = match.group(1)!.length;
        final text = match.group(2)!;
        return '<h$level>$text</h$level>';
      },
    );
    
    // Конвертация жирного текста
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );
    
    // Конвертация курсива
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (match) => '<em>${match.group(1)}</em>',
    );
    
    // Конвертация зачеркнутого текста
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (match) => '<s>${match.group(1)}</s>',
    );
    
    // Конвертация горизонтальной линии
    confluenceContent = confluenceContent.replaceAll(
      RegExp(r'^---+$', multiLine: true),
      '<hr/>',
    );
    
    // Конвертация ссылок
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'),
      (match) {
        final text = match.group(1)!;
        final url = match.group(2)!;
        return '<a href="$url">$text</a>';
      },
    );
    
    // Конвертация изображений
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'!\[(.*)\]\((.+?)\)'),
      (match) {
        final alt = match.group(1) ?? '';
        final src = match.group(2)!;
        return '<ac:image><ri:url ri:value="$src"/><ac:alt>$alt</ac:alt></ac:image>';
      },
    );
    
    // Конвертация цитат
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'^>\s+(.+)$', multiLine: true),
      (match) => '<blockquote>${match.group(1)}</blockquote>',
    );
    
    // Конвертация неупорядоченных списков
    confluenceContent = _convertUnorderedLists(confluenceContent);
    
    // Конвертация упорядоченных списков
    confluenceContent = _convertOrderedLists(confluenceContent);
    
    // Конвертация блоков кода
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'```(\w+)?\n(.*?)\n```', dotAll: true),
      (match) {
        final language = match.group(1) ?? '';
        final code = match.group(2)!;
        return '<ac:structured-macro ac:name="code">'
               '<ac:parameter ac:name="language">$language</ac:parameter>'
               '<ac:parameter ac:name="theme">Confluence</ac:parameter>'
               '<ac:parameter ac:name="linenumbers">true</ac:parameter>'
               '<ac:plain-text-body><![CDATA[$code]]></ac:plain-text-body>'
               '</ac:structured-macro>';
      },
    );
    
    // Конвертация встроенного кода
    confluenceContent = confluenceContent.replaceAllMapped(
      RegExp(r'`(.+?)`'),
      (match) => '<code>${match.group(1)}</code>',
    );
    
    // Конвертация таблиц
    confluenceContent = _convertTables(confluenceContent);
    
    // Конвертация разрывов строк в параграфы
    final paragraphs = confluenceContent.split('\n\n');
    confluenceContent = paragraphs
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim().startsWith('<') ? p : '<p>$p</p>')
        .join('\n');
    
    return confluenceContent;
  }
  
  /// Конвертирует неупорядоченные списки из Markdown в Confluence Storage Format
  String _convertUnorderedLists(String content) {
    // Находим группы неупорядоченных списков
    final listPattern = RegExp(r'(^[*\-+]\s+.+$(\n^[*\-+]\s+.+$)*)', multiLine: true);
    
    return content.replaceAllMapped(listPattern, (match) {
      final listContent = match.group(0)!;
      final items = listContent.split('\n');
      
      final convertedItems = items.map((item) {
        final itemMatch = RegExp(r'^[*\-+]\s+(.+)$').firstMatch(item);
        if (itemMatch != null) {
          return '<li>${itemMatch.group(1)}</li>';
        }
        return item;
      }).join('\n');
      
      return '<ul>\n$convertedItems\n</ul>';
    });
  }
  
  /// Конвертирует упорядоченные списки из Markdown в Confluence Storage Format
  String _convertOrderedLists(String content) {
    // Находим группы упорядоченных списков
    final listPattern = RegExp(r'(^\d+\.\s+.+$(\n^\d+\.\s+.+$)*)', multiLine: true);
    
    return content.replaceAllMapped(listPattern, (match) {
      final listContent = match.group(0)!;
      final items = listContent.split('\n');
      
      final convertedItems = items.map((item) {
        final itemMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(item);
        if (itemMatch != null) {
          return '<li>${itemMatch.group(1)}</li>';
        }
        return item;
      }).join('\n');
      
      return '<ol>\n$convertedItems\n</ol>';
    });
  }
  
  /// Конвертирует таблицы из Markdown в Confluence Storage Format
  String _convertTables(String content) {
    // Находим таблицы в Markdown формате
    final tablePattern = RegExp(
      r'(\|.+\|\n\|[-:\|\s]+\|\n(\|.+\|\n)+)',
      multiLine: true,
    );
    
    return content.replaceAllMapped(tablePattern, (match) {
      final tableContent = match.group(0)!;
      final rows = tableContent.trim().split('\n');
      
      // Пропускаем строку разделителя (вторая строка)
      final headerRow = rows[0];
      final dataRows = rows.sublist(2);
      
      // Обрабатываем заголовок
      final headerCells = _extractTableCells(headerRow);
      final headerHtml = headerCells.map((cell) => '<th>$cell</th>').join('');
      
      // Обрабатываем строки данных
      final dataRowsHtml = dataRows.map((row) {
        final cells = _extractTableCells(row);
        return '<tr>${cells.map((cell) => '<td>$cell</td>').join('')}</tr>';
      }).join('\n');
      
      return '<table><thead><tr>$headerHtml</tr></thead><tbody>$dataRowsHtml</tbody></table>';
    });
  }
  
  /// Извлекает ячейки из строки таблицы Markdown
  List<String> _extractTableCells(String row) {
    // Удаляем начальный и конечный символы | и разделяем по |
    final cells = row.trim().substring(1, row.trim().length - 1).split('|');
    return cells.map((cell) => cell.trim()).toList();
  }
  
  /// Generates a Confluence page URL from parent URL, page ID, and title
  String _generatePageUrl(String parentUrl, String pageId, String title) {
    // Extract base URL from parent URL
    final uri = Uri.parse(parentUrl);
    final baseUrl = '${uri.scheme}://${uri.host}';
    
    // URL-encode the title
    final encodedTitle = Uri.encodeComponent(title.replaceAll(' ', '+'));
    
    // Generate the page URL
    return '$baseUrl/wiki/spaces/${_extractSpaceFromUrl(parentUrl)}/pages/$pageId/$encodedTitle';
  }
  
  /// Extracts space key from a Confluence URL
  String _extractSpaceFromUrl(String url) {
    final spaceRegex = RegExp(r'/wiki/spaces/([^/]+)');
    final match = spaceRegex.firstMatch(url);
    return match?.group(1) ?? 'UNKNOWN';
  }
  
  /// Builds HTTP headers for API requests
  Map<String, String> _buildHeaders() {
    final credentials = base64Encode(utf8.encode(_config!.token));
    
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    };
  }
  
  /// Extracts error message from HTTP response
  String _extractErrorMessage(http.Response response) {
    try {
      final jsonData = json.decode(response.body);
      if (jsonData is Map<String, dynamic>) {
        return jsonData['message'] ?? 
               jsonData['error'] ?? 
               jsonData['errorMessage'] ?? 
               'HTTP ${response.statusCode}';
      }
    } catch (e) {
      // If JSON parsing fails, return the raw body if it's short enough
      if (response.body.length <= 200) {
        return response.body;
      }
    }
    
    return 'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}';
  }
  
  /// Parses Retry-After header for rate limiting
  Duration _parseRetryAfter(Map<String, String> headers) {
    final retryAfterHeader = headers['retry-after'] ?? headers['Retry-After'];
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }
    return const Duration(seconds: 60); // Default retry delay
  }
  
  /// Emits progress update to the stream
  void _emitProgress(PublishProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
}