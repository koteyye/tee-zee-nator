import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Service for sanitizing user inputs to prevent security vulnerabilities
/// 
/// This service provides comprehensive input sanitization for:
/// - XSS prevention
/// - SQL injection prevention  
/// - Command injection prevention
/// - Path traversal prevention
/// - Content sanitization
class InputSanitizer {
  // Common dangerous patterns
  static final RegExp _scriptPattern = RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true);
  static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>');
  static final RegExp _sqlInjectionPattern = RegExp(r'(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)', caseSensitive: false);
  static final RegExp _pathTraversalPattern = RegExp(r'\.\.[\\/]');
  static final RegExp _commandInjectionPattern = RegExp(r'[;&|`$(){}[\]\\]');
  static final RegExp _controlCharPattern = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _unicodeControlPattern = RegExp(r'[\u0000-\u001F\u007F-\u009F\u2000-\u200F\u2028-\u202F]');

  /// Sanitizes a Confluence base URL input
  /// 
  /// [url] - The URL to sanitize
  /// Returns sanitized URL or empty string if invalid
  static String sanitizeBaseUrl(String url) {
    if (url.isEmpty) return '';

    try {
      // Remove control characters and normalize whitespace
      String sanitized = _removeControlCharacters(url).trim();
      
      // Basic URL validation
      if (!_isValidUrl(sanitized)) {
        debugPrint('InputSanitizer: Invalid URL format: $url');
        return '';
      }
      
      // Remove dangerous patterns
      sanitized = _removeDangerousPatterns(sanitized);
      
      // Ensure HTTPS for security
      if (sanitized.startsWith('http://')) {
        sanitized = sanitized.replaceFirst('http://', 'https://');
        debugPrint('InputSanitizer: Upgraded HTTP to HTTPS');
      }
      
      // Remove trailing slashes
      while (sanitized.endsWith('/')) {
        sanitized = sanitized.substring(0, sanitized.length - 1);
      }
      
      // Validate Confluence URL pattern
      if (!_isValidConfluenceUrl(sanitized)) {
        debugPrint('InputSanitizer: Invalid Confluence URL pattern: $sanitized');
        return '';
      }
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: URL sanitization failed: $e');
      return '';
    }
  }

  /// Sanitizes a Confluence API token
  /// 
  /// [token] - The token to sanitize
  /// Returns sanitized token or empty string if invalid
  static String sanitizeApiToken(String token) {
    if (token.isEmpty) return '';

    try {
      // Remove control characters and trim
      String sanitized = _removeControlCharacters(token).trim();
      
      // Remove potentially dangerous characters
      sanitized = sanitized
          .replaceAll(RegExp(r'[<>"\s]'), '')
          .replaceAll("'", '');
      
      // Validate token format
      if (!_isValidTokenFormat(sanitized)) {
        debugPrint('InputSanitizer: Invalid token format');
        return '';
      }
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: Token sanitization failed: $e');
      return '';
    }
  }

  /// Sanitizes text content that may contain Confluence links
  /// 
  /// [content] - The content to sanitize
  /// [allowHtml] - Whether to allow safe HTML tags
  /// Returns sanitized content
  static String sanitizeTextContent(String content, {bool allowHtml = false}) {
    if (content.isEmpty) return '';

    try {
      String sanitized = content;
      
      // Remove control characters
      sanitized = _removeControlCharacters(sanitized);
      
      // Remove script tags and dangerous content
      sanitized = _removeScriptTags(sanitized);
      
      // Handle HTML based on allowHtml flag
      if (!allowHtml) {
        sanitized = _removeAllHtmlTags(sanitized);
      } else {
        sanitized = _sanitizeHtmlContent(sanitized);
      }
      
      // Remove SQL injection patterns
      sanitized = _removeSqlInjectionPatterns(sanitized);
      
      // Remove command injection patterns
      sanitized = _removeCommandInjectionPatterns(sanitized);
      
      // Normalize whitespace
      sanitized = _normalizeWhitespace(sanitized);
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: Content sanitization failed: $e');
      return content; // Return original if sanitization fails
    }
  }

  /// Sanitizes Confluence page URLs for processing
  /// 
  /// [pageUrl] - The page URL to sanitize
  /// Returns sanitized URL or empty string if invalid
  static String sanitizePageUrl(String pageUrl) {
    if (pageUrl.isEmpty) return '';

    try {
      // Remove control characters and trim
      String sanitized = _removeControlCharacters(pageUrl).trim();
      
      // Basic URL validation
      if (!_isValidUrl(sanitized)) {
        debugPrint('InputSanitizer: Invalid page URL format: $pageUrl');
        return '';
      }
      
      // Remove dangerous patterns
      sanitized = _removeDangerousPatterns(sanitized);
      
      // Validate Confluence page URL pattern
      if (!_isValidConfluencePageUrl(sanitized)) {
        debugPrint('InputSanitizer: Invalid Confluence page URL pattern: $sanitized');
        return '';
      }
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: Page URL sanitization failed: $e');
      return '';
    }
  }

  /// Sanitizes HTML content from Confluence API responses
  /// 
  /// [htmlContent] - The HTML content to sanitize
  /// Returns sanitized plain text content
  static String sanitizeConfluenceHtml(String htmlContent) {
    if (htmlContent.isEmpty) return '';

    try {
      String sanitized = htmlContent;
      
      // Remove script tags and dangerous content
      sanitized = _removeScriptTags(sanitized);
      
      // Remove all HTML tags to get plain text
      sanitized = _removeAllHtmlTags(sanitized);
      
      // Decode HTML entities
      sanitized = _decodeHtmlEntities(sanitized);
      
      // Remove control characters
      sanitized = _removeControlCharacters(sanitized);
      
      // Normalize whitespace
      sanitized = _normalizeWhitespace(sanitized);
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: HTML sanitization failed: $e');
      return htmlContent; // Return original if sanitization fails
    }
  }

  /// Validates and sanitizes file paths to prevent path traversal
  /// 
  /// [path] - The file path to sanitize
  /// Returns sanitized path or empty string if invalid
  static String sanitizeFilePath(String path) {
    if (path.isEmpty) return '';

    try {
      String sanitized = _removeControlCharacters(path).trim();
      
      // Remove path traversal patterns
      if (_pathTraversalPattern.hasMatch(sanitized)) {
        debugPrint('InputSanitizer: Path traversal attempt detected: $path');
        return '';
      }
      
      // Remove dangerous characters
      sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*]'), '');
      
      return sanitized;
      
    } catch (e) {
      debugPrint('InputSanitizer: File path sanitization failed: $e');
      return '';
    }
  }

  // Private helper methods

  /// Removes control characters from input
  static String _removeControlCharacters(String input) {
    return input
        .replaceAll(_controlCharPattern, '')
        .replaceAll(_unicodeControlPattern, '');
  }

  /// Removes script tags and dangerous JavaScript
  static String _removeScriptTags(String input) {
    return input
        .replaceAll(_scriptPattern, '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');
  }

  /// Removes all HTML tags
  static String _removeAllHtmlTags(String input) {
    return input.replaceAll(_htmlTagPattern, ' ');
  }

  /// Sanitizes HTML content by removing dangerous tags but keeping safe ones
  static String _sanitizeHtmlContent(String input) {
    // Remove dangerous tags
    String sanitized = input
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<iframe[^>]*>.*?</iframe>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<object[^>]*>.*?</object>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<embed[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<form[^>]*>.*?</form>', caseSensitive: false, dotAll: true), '');
    
    // Remove dangerous attributes
    sanitized = sanitized
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    
    return sanitized;
  }

  /// Removes SQL injection patterns
  static String _removeSqlInjectionPatterns(String input) {
    // This is a basic check - in practice, parameterized queries are the real solution
    if (_sqlInjectionPattern.hasMatch(input)) {
      debugPrint('InputSanitizer: Potential SQL injection pattern detected');
      return input.replaceAll(_sqlInjectionPattern, '');
    }
    return input;
  }

  /// Removes command injection patterns
  static String _removeCommandInjectionPatterns(String input) {
    return input.replaceAll(_commandInjectionPattern, '');
  }

  /// Normalizes whitespace
  static String _normalizeWhitespace(String input) {
    return input
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
  }

  /// Decodes HTML entities
  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/')
        .replaceAll('&#x60;', '`')
        .replaceAll('&#x3D;', '=');
  }

  /// Removes dangerous patterns from URLs
  static String _removeDangerousPatterns(String input) {
    return input
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'[<>"]'), '')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:', caseSensitive: false), '');
  }

  /// Validates basic URL format
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Validates Confluence URL pattern
  static bool _isValidConfluenceUrl(String url) {
    // Basic Confluence URL validation
    final confluencePattern = RegExp(r'^https://[a-zA-Z0-9.-]+\.atlassian\.net/?$');
    return confluencePattern.hasMatch(url) || 
           url.contains('.atlassian.net') ||
           url.contains('/wiki/');
  }

  /// Validates Confluence page URL pattern
  static bool _isValidConfluencePageUrl(String url) {
    // Confluence page URL patterns
    final pagePatterns = [
      RegExp(r'^https://[^/]+/wiki/spaces/[^/]+/pages/\d+/'),
      RegExp(r'^https://[^/]+/wiki/display/[^/]+/'),
      RegExp(r'^https://[^/]+/pages/viewpage\.action\?pageId=\d+'),
    ];
    
    return pagePatterns.any((pattern) => pattern.hasMatch(url));
  }

  /// Validates API token format
  static bool _isValidTokenFormat(String token) {
    // Basic token validation
    if (token.length < 10 || token.length > 500) {
      return false;
    }
    
    // Check for valid characters (alphanumeric, +, /, =, -, _)
    final validTokenPattern = RegExp(r'^[A-Za-z0-9+/=_-]+$');
    return validTokenPattern.hasMatch(token);
  }

  /// Validates input length to prevent DoS attacks
  static bool isValidInputLength(String input, {int maxLength = 10000}) {
    return input.length <= maxLength;
  }

  /// Checks if input contains only safe characters
  static bool containsOnlySafeCharacters(String input) {
    // Allow alphanumeric, common punctuation, and safe symbols
    final safePattern = RegExp(r'^[A-Za-z0-9\s.,!?;:()\[\]{}\-_+=@#$%^&*~`|\\/"\<\>]+$');
    return safePattern.hasMatch(input);
  }

  /// Escapes special characters for safe display
  static String escapeForDisplay(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Validates and sanitizes JSON input
  static String? sanitizeJsonInput(String jsonString) {
    try {
      // Parse to validate JSON structure
      final decoded = json.decode(jsonString);
      
      // Re-encode to ensure clean JSON
      return json.encode(decoded);
    } catch (e) {
      debugPrint('InputSanitizer: Invalid JSON input: $e');
      return null;
    }
  }
}