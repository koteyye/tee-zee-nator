import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/confluence_config.dart';
import '../models/confluence_page.dart';
import '../exceptions/confluence_exceptions.dart';
import 'confluence_error_handler.dart';
import 'input_sanitizer.dart';
import 'secure_token_storage.dart';

/// Service for managing Confluence API interactions
/// 
/// This service handles all communication with Confluence REST API including:
/// - Connection testing and health checks
/// - Page content retrieval and metadata
/// - Authentication and error handling
/// - Rate limiting and network resilience
class ConfluenceService extends ChangeNotifier {
  static const String _userAgent = 'TeeZeeNator/1.1.0';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  
  ConfluenceConfig? _config;
  http.Client? _httpClient;
  bool _isLoading = false;
  String? _lastError;
  
  /// Current configuration
  ConfluenceConfig? get config => _config;
  
  /// Whether a request is currently in progress
  bool get isLoading => _isLoading;
  
  /// Last error message, if any
  String? get lastError => _lastError;
  
  /// Whether the service is properly configured
  bool get isConfigured => _config?.isConfigurationComplete ?? false;
  
  /// Whether the last connection test was successful
  bool get isConnected => _config?.isValid ?? false;

  /// Initializes the service with configuration
  void initialize(ConfluenceConfig config) {
    _config = config;
    _httpClient = http.Client();
    _clearError();
    notifyListeners();
  }

  /// Disposes of resources
  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }

  /// Tests connection to Confluence by performing a health check
  /// 
  /// Uses the /wiki/rest/api/space endpoint to verify:
  /// - Network connectivity
  /// - Authentication credentials
  /// - API accessibility
  /// 
  /// Returns true if connection is successful, false otherwise
  Future<bool> testConnection(String baseUrl, String token) async {
    // Sanitize inputs first
    final sanitizedUrl = InputSanitizer.sanitizeBaseUrl(baseUrl);
    final sanitizedToken = InputSanitizer.sanitizeApiToken(token);
    
    if (sanitizedUrl.isEmpty || sanitizedToken.isEmpty) {
      _setError('Base URL and token are required for connection test');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Use sanitized URL
      final healthCheckUrl = '$sanitizedUrl/wiki/rest/api/space';
      
      // Log connection attempt (without exposing token)
      ConfluenceErrorHandler.logConnectionAttempt(sanitizedUrl, token: '[REDACTED]');
      
      // Create HTTP client if not exists
      _httpClient ??= http.Client();
      
      // Prepare request with authentication using sanitized token
      final request = http.Request('GET', Uri.parse(healthCheckUrl));
      request.headers.addAll(_buildHeaders(sanitizedToken));
      
      // Log API request
      ConfluenceErrorHandler.logApiRequest('GET', healthCheckUrl, headers: request.headers);
      
      // Send request with timeout and retry logic
      final response = await _sendRequestWithRetry(request);
      
      final responseBody = await response.stream.bytesToString();
      
      // Log API response
      ConfluenceErrorHandler.logApiResponse('GET', healthCheckUrl, response.statusCode, body: responseBody);
      
      if (response.statusCode == 200) {
        ConfluenceErrorHandler.logConnectionSuccess(sanitizedUrl);
        return true;
      } else {
        final errorMessage = _extractErrorMessage(response, responseBody);
        _setError('Connection failed: $errorMessage');
        ConfluenceErrorHandler.logConnectionFailure(sanitizedUrl, Exception(errorMessage));
        return false;
      }
      
    } catch (e) {
      debugPrint('Confluence connection test failed: $e');
      final errorMessage = _formatConnectionError(e);
      _setError(errorMessage);
      ConfluenceErrorHandler.logConnectionFailure(baseUrl, e is Exception ? e : Exception(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Retrieves content from a Confluence page
  /// 
  /// [pageId] - The Confluence page ID
  /// Returns the page content as plain text with HTML tags removed
  Future<String> getPageContent(String pageId) async {
    if (!isConfigured) {
      throw const ConfluenceValidationException(
        'Confluence service is not configured',
        fieldName: 'configuration',
        recoveryAction: 'Configure Confluence connection in settings',
      );
    }

    // Sanitize page ID input
    final sanitizedPageId = InputSanitizer.sanitizeFilePath(pageId);
    if (sanitizedPageId.isEmpty) {
      throw const ConfluenceValidationException(
        'Page ID cannot be empty or contains invalid characters',
        fieldName: 'pageId',
        recoveryAction: 'Provide a valid Confluence page ID',
      );
    }

    _setLoading(true);
    _clearError();

    try {
      final url = '${_config!.apiBaseUrl}/content/$sanitizedPageId?expand=body.storage';
      
      // Log API request
      ConfluenceErrorHandler.logApiRequest('GET', url);
      
      // Get secure token
      final secureToken = await _config!.getSecureToken();
      if (secureToken == null || secureToken.isEmpty) {
        throw const ConfluenceValidationException(
          'Authentication token is not available',
          fieldName: 'token',
          recoveryAction: 'Reconfigure Confluence connection in settings',
        );
      }
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_buildHeaders(secureToken));
      
      final response = await _sendRequestWithRetry(request);
      
      final responseBody = await response.stream.bytesToString();
      
      // Log API response
      ConfluenceErrorHandler.logApiResponse('GET', url, response.statusCode, body: responseBody);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(responseBody);
        final page = ConfluencePage.fromJson(jsonData);
        
        if (page.content?.value != null) {
          // Extract and sanitize content using secure sanitization
          final sanitizedContent = InputSanitizer.sanitizeConfluenceHtml(page.content!.value);
          ConfluenceErrorHandler.logInfo('Successfully retrieved page content (${sanitizedContent.length} characters)', context: 'getPageContent');
          return sanitizedContent;
        } else {
          throw ConfluenceExceptionFactory.contentProcessingFailed(
            url: url,
            pageId: sanitizedPageId,
            details: 'Page content is empty or not accessible',
          );
        }
      } else {
        await _handleApiError(response, 'retrieve page content');
        return ''; // This line won't be reached due to exception above
      }
      
    } catch (e) {
      if (e is ConfluenceException) {
        rethrow;
      }
      
      debugPrint('Failed to get page content: $e');
      throw ConfluenceExceptionFactory.contentProcessingFailed(
        url: sanitizedPageId,
        pageId: sanitizedPageId,
        details: e.toString(),
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Retrieves metadata information about a Confluence page
  /// 
  /// [pageUrl] - The full Confluence page URL
  /// Returns ConfluencePage object with metadata
  Future<ConfluencePage> getPageInfo(String pageUrl) async {
    if (!isConfigured) {
      throw const ConfluenceValidationException(
        'Confluence service is not configured',
        fieldName: 'configuration',
        recoveryAction: 'Configure Confluence connection in settings',
      );
    }

    // Sanitize page URL input
    final sanitizedPageUrl = InputSanitizer.sanitizePageUrl(pageUrl);
    if (sanitizedPageUrl.isEmpty) {
      throw const ConfluenceValidationException(
        'Page URL cannot be empty or contains invalid characters',
        fieldName: 'pageUrl',
        recoveryAction: 'Provide a valid Confluence page URL',
      );
    }

    // Extract page ID from sanitized URL
    final pageId = ConfluencePage.extractPageIdFromUrl(sanitizedPageUrl);
    if (pageId == null) {
      throw ConfluenceExceptionFactory.invalidUrl(
        url: sanitizedPageUrl,
        expectedFormat: 'https://domain.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title',
      );
    }

    _setLoading(true);
    _clearError();

    try {
      final url = '${_config!.apiBaseUrl}/content/$pageId?expand=space,version,ancestors';
      debugPrint('Fetching Confluence page info from: $url');
      
      // Get secure token
      final secureToken = await _config!.getSecureToken();
      if (secureToken == null || secureToken.isEmpty) {
        throw const ConfluenceValidationException(
          'Authentication token is not available',
          fieldName: 'token',
          recoveryAction: 'Reconfigure Confluence connection in settings',
        );
      }
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_buildHeaders(secureToken));
      
      final response = await _sendRequestWithRetry(request);
      
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonData = json.decode(responseBody);
        final page = ConfluencePage.fromJson(jsonData);
        debugPrint('Successfully retrieved page info: ${page.title}');
        return page;
      } else {
        await _handleApiError(response, 'retrieve page information');
        throw StateError('This should not be reached'); // For type safety
      }
      
    } catch (e) {
      if (e is ConfluenceException) {
        rethrow;
      }
      
      debugPrint('Failed to get page info: $e');
      throw ConfluenceExceptionFactory.contentProcessingFailed(
        url: sanitizedPageUrl,
        pageId: pageId,
        details: e.toString(),
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Builds HTTP headers for Confluence API requests
  Map<String, String> _buildHeaders(String token) {
    // Sanitize token before encoding
    final sanitizedToken = InputSanitizer.sanitizeApiToken(token);
    if (sanitizedToken.isEmpty) {
      throw const ConfluenceValidationException(
        'Invalid authentication token',
        fieldName: 'token',
        recoveryAction: 'Reconfigure Confluence connection with a valid token',
      );
    }
    
    final credentials = base64Encode(utf8.encode(sanitizedToken));
    
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    };
  }

  /// Sends HTTP request with retry logic and error handling
  Future<http.StreamedResponse> _sendRequestWithRetry(http.Request request) async {
    int attempts = 0;
    Duration delay = const Duration(milliseconds: 500);
    
    while (attempts < _maxRetries) {
      attempts++;
      
      try {
        final response = await _httpClient!
            .send(request)
            .timeout(_defaultTimeout);
        
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
        
      } on SocketException catch (e) {
        if (attempts >= _maxRetries) {
          throw ConfluenceExceptionFactory.connectionFailed(
            baseUrl: _config?.baseUrl ?? 'unknown',
            details: 'Network error: ${e.message}',
          );
        }
        debugPrint('Network error on attempt $attempts, retrying...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
        
      } on HttpException catch (e) {
        throw ConfluenceNetworkException(
          'HTTP error: ${e.message}',
          url: request.url.toString(),
          method: request.method,
          technicalDetails: e.toString(),
          recoveryAction: 'Check your network connection and try again',
        );
        
      } on FormatException catch (e) {
        throw ConfluenceParsingException(
          'Invalid response format from Confluence API',
          technicalDetails: e.toString(),
          recoveryAction: 'The Confluence API returned an unexpected response format',
        );
      }
    }
    
    throw ConfluenceExceptionFactory.connectionFailed(
      baseUrl: _config?.baseUrl ?? 'unknown',
      details: 'Maximum retry attempts exceeded',
    );
  }

  /// Handles API error responses and throws appropriate exceptions
  Future<void> _handleApiError(http.StreamedResponse response, String operation) async {
    final responseBody = await response.stream.bytesToString();
    final errorMessage = _extractErrorMessage(response, responseBody);
    
    switch (response.statusCode) {
      case 401:
        throw ConfluenceExceptionFactory.authenticationFailed(
          details: 'HTTP 401: $errorMessage',
        );
      case 403:
        throw ConfluenceExceptionFactory.authorizationFailed(
          operation: operation,
          details: 'HTTP 403: $errorMessage',
        );
      case 404:
        throw ConfluenceContentProcessingException(
          'Confluence page not found or not accessible',
          technicalDetails: 'HTTP 404: $errorMessage',
          recoveryAction: 'Verify the page URL is correct and you have access to it',
        );
      case 429:
        final retryAfter = _parseRetryAfter(response.headers);
        throw ConfluenceExceptionFactory.rateLimitExceeded(
          retryAfterSeconds: retryAfter.inSeconds,
          details: 'HTTP 429: $errorMessage',
        );
      case 500:
      case 502:
      case 503:
      case 504:
        throw ConfluenceNetworkException(
          'Confluence server error',
          url: 'API endpoint',
          method: 'GET',
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: $errorMessage',
          recoveryAction: 'Confluence server is experiencing issues. Try again later',
        );
      default:
        throw ConfluenceNetworkException(
          'Unexpected API response',
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: $errorMessage',
          recoveryAction: 'An unexpected error occurred. Check your configuration and try again',
        );
    }
  }

  /// Extracts error message from HTTP response
  String _extractErrorMessage(http.StreamedResponse response, [String? body]) {
    if (body != null && body.isNotEmpty) {
      try {
        final jsonData = json.decode(body);
        if (jsonData is Map<String, dynamic>) {
          return jsonData['message'] ?? 
                 jsonData['error'] ?? 
                 jsonData['errorMessage'] ?? 
                 'HTTP ${response.statusCode}';
        }
      } catch (e) {
        // If JSON parsing fails, return the raw body if it's short enough
        if (body.length <= 200) {
          return body;
        }
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



  /// Formats connection errors for user display
  String _formatConnectionError(dynamic error) {
    if (error is SocketException) {
      return 'Network connection failed: ${error.message}';
    } else if (error is HttpException) {
      return 'HTTP error: ${error.message}';
    } else if (error is FormatException) {
      return 'Invalid response format from server';
    } else {
      return 'Connection failed: ${error.toString()}';
    }
  }

  /// Sets loading state and notifies listeners
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Sets error message and notifies listeners
  void _setError(String error) {
    _lastError = error;
    debugPrint('ConfluenceService error: $error');
    notifyListeners();
  }

  /// Clears error state
  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Creates appropriate ConfluenceException from HTTP response
  ConfluenceException _createErrorFromResponse(http.StreamedResponse response, String responseBody, String url) {
    switch (response.statusCode) {
      case 401:
        return ConfluenceExceptionFactory.authenticationFailed(
          details: 'HTTP 401: ${_extractErrorMessage(response, responseBody)}',
        );
      case 403:
        return ConfluenceExceptionFactory.authorizationFailed(
          operation: 'access resource',
          details: 'HTTP 403: ${_extractErrorMessage(response, responseBody)}',
        );
      case 404:
        return ConfluenceConnectionException(
          'Resource not found',
          baseUrl: _config?.baseUrl,
          statusCode: 404,
          technicalDetails: 'HTTP 404: ${_extractErrorMessage(response, responseBody)}',
          recoveryAction: 'Verify the URL is correct and the resource exists',
        );
      case 429:
        final retryAfter = _parseRetryAfter(response.headers);
        return ConfluenceExceptionFactory.rateLimitExceeded(
          retryAfterSeconds: retryAfter.inSeconds,
          details: 'HTTP 429: ${_extractErrorMessage(response, responseBody)}',
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ConfluenceConnectionException(
          'Server error',
          baseUrl: _config?.baseUrl,
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: ${_extractErrorMessage(response, responseBody)}',
          recoveryAction: 'The Confluence server is experiencing issues. Try again later.',
        );
      default:
        return ConfluenceNetworkException(
          'HTTP request failed',
          url: url,
          method: 'GET',
          statusCode: response.statusCode,
          technicalDetails: 'HTTP ${response.statusCode}: ${_extractErrorMessage(response, responseBody)}',
          recoveryAction: 'Check your network connection and try again',
        );
    }
  }

  /// Creates appropriate ConfluenceException from general exception
  ConfluenceException _createErrorFromException(dynamic exception, String baseUrl) {
    if (exception is SocketException) {
      return ConfluenceExceptionFactory.connectionFailed(
        baseUrl: baseUrl,
        details: 'Network error: ${exception.message}',
      );
    } else if (exception is TimeoutException) {
      return ConfluenceConnectionException(
        'Connection timeout',
        baseUrl: baseUrl,
        technicalDetails: 'Request timed out after $_defaultTimeout',
        recoveryAction: 'Check your internet connection and try again',
      );
    } else if (exception is FormatException) {
      return ConfluenceParsingException(
        'Invalid response format',
        technicalDetails: 'Failed to parse response: ${exception.message}',
        recoveryAction: 'The server returned an unexpected response format',
      );
    } else {
      return ConfluenceConnectionException(
        'Unexpected error',
        baseUrl: baseUrl,
        technicalDetails: exception.toString(),
        recoveryAction: 'An unexpected error occurred. Please try again.',
      );
    }
  }
}