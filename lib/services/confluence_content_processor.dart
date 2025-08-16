import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/confluence_link.dart';
import '../models/confluence_config.dart';
import 'confluence_service.dart';
import 'confluence_performance_optimizer.dart';
import 'confluence_debouncer.dart';
import 'input_sanitizer.dart';
import 'confluence_error_handler.dart';

/// Service for processing Confluence links in text content
/// 
/// This service handles:
/// - Detection and extraction of Confluence URLs from text
/// - Content retrieval and replacement with @conf-cnt format
/// - HTML sanitization and plain text extraction
/// - Debounced processing to prevent excessive API calls
/// - Caching of processed content for performance
/// - Session-based storage and memory management
class ConfluenceContentProcessor {
  static const String CONTENT_MARKER_START = '@conf-cnt ';
  static const String CONTENT_MARKER_END = '@';
  static const Duration DEBOUNCE_DURATION = Duration(milliseconds: 500);
  static const Duration CACHE_TTL = Duration(minutes: 30);
  static const int MAX_CACHE_SIZE = 100; // Maximum number of cached links
  static const int MAX_CONTENT_SIZE = 50000; // Maximum content size per link (50KB)
  
  final ConfluenceService _confluenceService;
  final Map<String, ConfluenceLink> _linkCache = {};
  final Map<String, String> _sessionProcessedContent = {}; // Session-based storage
  Timer? _debounceTimer;
  Timer? _cleanupTimer;
  
  // Performance optimization components
  late final ConfluencePerformanceOptimizer _performanceOptimizer;
  late final ConfluenceDebouncer _debouncer;
  
  // Memory usage tracking
  int _totalCacheMemoryUsage = 0;
  
  ConfluenceContentProcessor(this._confluenceService) {
    // Initialize performance optimizer
    _performanceOptimizer = ConfluencePerformanceOptimizer(_confluenceService, this);
    _debouncer = ConfluenceDebouncer();
    
    // Start periodic cleanup timer
    _startPeriodicCleanup();
  }

  /// Processes text by replacing Confluence links with content markers
  /// 
  /// [text] - The input text containing potential Confluence links
  /// [config] - Confluence configuration for URL validation
  /// [debounce] - Whether to apply debounce delay (default: true)
  /// [enableOptimizations] - Whether to use performance optimizations (default: true)
  /// 
  /// Returns processed text with links replaced by @conf-cnt markers
  Future<String> processText(
    String text, 
    ConfluenceConfig config, {
    bool debounce = true,
    bool enableOptimizations = true,
  }) async {
    if (text.isEmpty || !config.isConfigurationComplete) {
      return text;
    }

    // Use performance optimizer if enabled
    if (enableOptimizations) {
      if (debounce) {
        final completer = Completer<String>();
        
        _debouncer.adaptiveDebounce(
          'processText_${text.hashCode}',
          text,
          () async {
            try {
              final result = await _performanceOptimizer.processTextOptimized(
                text,
                config,
                enableBatching: true,
                enableCaching: true,
              );
              if (!completer.isCompleted) {
                completer.complete(result);
              }
            } catch (e) {
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
          },
        );
        
        return completer.future;
      } else {
        return _performanceOptimizer.processTextOptimized(
          text,
          config,
          enableBatching: true,
          enableCaching: true,
        );
      }
    }

    // Fallback to original implementation
    if (debounce) {
      final completer = Completer<String>();
      
      // Cancel previous timer
      _debounceTimer?.cancel();
      
      _debounceTimer = Timer(DEBOUNCE_DURATION, () async {
        try {
          final result = await _processTextInternal(text, config);
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      });
      
      return completer.future;
    } else {
      return _processTextInternal(text, config);
    }
  }

  /// Internal method for processing text without debounce
  Future<String> _processTextInternal(String text, ConfluenceConfig config) async {
    // Sanitize input text first
    final sanitizedText = InputSanitizer.sanitizeTextContent(text, allowHtml: false);
    
    // Extract Confluence links from sanitized text
    final links = extractLinks(sanitizedText, config.sanitizedBaseUrl);
    
    if (links.isEmpty) {
      return sanitizedText;
    }

    // Process each link and build replacement map
    final linkContentMap = <String, String>{};
    
    for (final linkUrl in links) {
      try {
        final processedLink = await _processLink(linkUrl, config);
        if (processedLink.isValid) {
          linkContentMap[linkUrl] = processedLink.contentMarker;
        } else {
          // Keep original URL if processing failed
          linkContentMap[linkUrl] = linkUrl;
        }
      } catch (e) {
        // Log error with appropriate context
        if (e is Exception) {
          ConfluenceErrorHandler.logError(
            e,
            context: 'Processing Confluence link in text: $linkUrl',
          );
        } else {
          ConfluenceErrorHandler.logWarning(
            'Failed to process Confluence link: $e',
            context: 'ConfluenceContentProcessor._processTextInternal',
          );
        }
        // Keep original URL on error
        linkContentMap[linkUrl] = linkUrl;
      }
    }

    // Replace links with processed content
    return replaceLinksWithContent(sanitizedText, linkContentMap);
  }

  /// Extracts Confluence URLs from text that match the base URL pattern
  /// 
  /// [text] - The input text to search for links
  /// [baseUrl] - The configured Confluence base URL for validation
  /// 
  /// Returns list of valid Confluence URLs found in the text
  List<String> extractLinks(String text, String baseUrl) {
    if (text.isEmpty || baseUrl.isEmpty) {
      return [];
    }

    final links = <String>[];
    
    // Pattern to match Confluence URLs
    // Matches: https://domain.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title
    final confluenceUrlPattern = RegExp(
      r'https?://[^\s/]+\.atlassian\.net/wiki/[^\s]*',
      caseSensitive: false,
    );
    
    final matches = confluenceUrlPattern.allMatches(text);
    
    for (final match in matches) {
      final url = match.group(0);
      if (url != null && ConfluenceLink.isValidConfluenceUrl(url, baseUrl)) {
        // Remove any trailing punctuation that might be part of sentence
        final cleanUrl = _cleanUrl(url);
        if (!links.contains(cleanUrl)) {
          links.add(cleanUrl);
        }
      }
    }
    
    return links;
  }

  /// Replaces links in text with their corresponding content
  /// 
  /// [text] - The original text containing links
  /// [linkContentMap] - Map of original URLs to replacement content
  /// 
  /// Returns text with links replaced by content markers
  String replaceLinksWithContent(String text, Map<String, String> linkContentMap) {
    String processedText = text;
    
    // Sort links by length (longest first) to avoid partial replacements
    final sortedLinks = linkContentMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (final originalUrl in sortedLinks) {
      final replacement = linkContentMap[originalUrl];
      if (replacement != null) {
        processedText = processedText.replaceAll(originalUrl, replacement);
      }
    }
    
    return processedText;
  }

  /// Sanitizes HTML content by removing tags and extracting plain text
  /// 
  /// [htmlContent] - The HTML content to sanitize
  /// 
  /// Returns clean plain text with HTML tags removed
  String sanitizeContent(String htmlContent) {
    if (htmlContent.isEmpty) return '';
    
    // Use secure sanitization from InputSanitizer
    return InputSanitizer.sanitizeConfluenceHtml(htmlContent);
  }

  /// Processes a single Confluence link and retrieves its content
  Future<ConfluenceLink> _processLink(String linkUrl, ConfluenceConfig config) async {
    // Check cache first
    final cachedLink = _linkCache[linkUrl];
    if (cachedLink != null && cachedLink.isFresh(ttl: CACHE_TTL)) {
      return cachedLink;
    }

    // Extract page ID from URL
    final pageId = ConfluenceLink.extractPageIdFromUrl(linkUrl);
    if (pageId == null) {
      final failedLink = ConfluenceLink.failed(
        originalUrl: linkUrl,
        pageId: '',
        errorMessage: 'Invalid Confluence URL format',
      );
      _linkCache[linkUrl] = failedLink;
      return failedLink;
    }

    try {
      // Retrieve page content from Confluence
      final content = await _confluenceService.getPageContent(pageId);
      final sanitizedContent = sanitizeContent(content);
      
      final successLink = ConfluenceLink.success(
        originalUrl: linkUrl,
        pageId: pageId,
        extractedContent: sanitizedContent,
      );
      
      // Check content size limit before caching
      if (sanitizedContent.length > MAX_CONTENT_SIZE) {
        ConfluenceErrorHandler.logWarning(
          'Content too large for caching: ${sanitizedContent.length} bytes',
          context: 'ConfluenceContentProcessor',
        );
        // Return without caching if content is too large
        return successLink;
      }
      
      // Cache the result and update memory usage
      _linkCache[linkUrl] = successLink;
      _totalCacheMemoryUsage += _calculateLinkMemoryUsage(successLink);
      
      // Store in session for this processing session
      _sessionProcessedContent[linkUrl] = successLink.contentMarker;
      
      return successLink;
      
    } catch (e) {
      // Log error with appropriate context
      if (e is Exception) {
        ConfluenceErrorHandler.logError(
          e,
          context: 'Processing Confluence link: $linkUrl (Page ID: $pageId)',
        );
      } else {
        ConfluenceErrorHandler.logWarning(
          'Error processing Confluence link: $e',
          context: 'ConfluenceContentProcessor',
        );
      }
      
      final failedLink = ConfluenceLink.failed(
        originalUrl: linkUrl,
        pageId: pageId,
        errorMessage: e.toString(),
      );
      
      // Cache failed results for a shorter time to allow retry
      _linkCache[linkUrl] = failedLink;
      _totalCacheMemoryUsage += _calculateLinkMemoryUsage(failedLink);
      
      // Store failed result in session (original URL)
      _sessionProcessedContent[linkUrl] = linkUrl;
      
      return failedLink;
    }
  }

  /// Cleans URL by removing trailing punctuation
  String _cleanUrl(String url) {
    // Remove common trailing punctuation that might be part of sentence structure
    final trailingPunctuation = RegExp(r'[.,;:!?)\]}>]+$');
    return url.replaceAll(trailingPunctuation, '');
  }

  /// Decodes common HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™');
  }

  /// Starts periodic cleanup timer to manage memory usage
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _performPeriodicCleanup();
    });
  }

  /// Performs periodic cleanup of stale cache entries
  void _performPeriodicCleanup() {
    final now = DateTime.now();
    final staleEntries = <String>[];
    
    // Find stale entries
    for (final entry in _linkCache.entries) {
      if (!entry.value.isFresh(ttl: CACHE_TTL)) {
        staleEntries.add(entry.key);
      }
    }
    
    // Remove stale entries and update memory usage
    for (final key in staleEntries) {
      final link = _linkCache.remove(key);
      if (link != null) {
        _totalCacheMemoryUsage -= _calculateLinkMemoryUsage(link);
      }
    }
    
    // If cache is still too large, remove oldest entries
    if (_linkCache.length > MAX_CACHE_SIZE) {
      final sortedEntries = _linkCache.entries.toList()
        ..sort((a, b) => a.value.processedAt.compareTo(b.value.processedAt));
      
      final entriesToRemove = sortedEntries.take(_linkCache.length - MAX_CACHE_SIZE);
      for (final entry in entriesToRemove) {
        _linkCache.remove(entry.key);
        _totalCacheMemoryUsage -= _calculateLinkMemoryUsage(entry.value);
      }
    }
    
    ConfluenceErrorHandler.logInfo(
      'Periodic cleanup completed. Cache size: ${_linkCache.length}, Memory usage: $_totalCacheMemoryUsage bytes',
      context: 'ConfluenceContentProcessor',
    );
  }

  /// Calculates approximate memory usage of a ConfluenceLink
  int _calculateLinkMemoryUsage(ConfluenceLink link) {
    return link.originalUrl.length * 2 + // UTF-16 encoding
           link.pageId.length * 2 +
           link.extractedContent.length * 2 +
           (link.errorMessage?.length ?? 0) * 2 +
           64; // Approximate overhead for object structure
  }

  /// Clears all processed content from session storage
  void clearSessionContent() {
    _sessionProcessedContent.clear();
    debugPrint('ConfluenceContentProcessor: Session content cleared');
  }

  /// Clears the link cache and updates memory tracking
  void clearCache() {
    _linkCache.clear();
    _totalCacheMemoryUsage = 0;
    debugPrint('ConfluenceContentProcessor: Cache cleared');
  }

  /// Clears all cached and session data (called when "Clear" is clicked)
  void clearAllData() {
    clearCache();
    clearSessionContent();
    debugPrint('ConfluenceContentProcessor: All data cleared');
  }

  /// Cancels any pending debounce timer
  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debouncer.cancelAll();
  }

  /// Disposes of resources and performs cleanup
  void dispose() {
    cancelDebounce();
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _performanceOptimizer.dispose();
    _debouncer.dispose();
    clearAllData();
    debugPrint('ConfluenceContentProcessor: Disposed');
  }

  /// Gets cache statistics for debugging and monitoring
  Map<String, dynamic> getCacheStats() {
    final validLinks = _linkCache.values.where((link) => link.isValid).length;
    final invalidLinks = _linkCache.values.where((link) => !link.isValid).length;
    final freshLinks = _linkCache.values.where((link) => link.isFresh(ttl: CACHE_TTL)).length;
    
    final legacyStats = {
      'legacy': {
        'totalCached': _linkCache.length,
        'validLinks': validLinks,
        'invalidLinks': invalidLinks,
        'freshLinks': freshLinks,
        'staleLinks': _linkCache.length - freshLinks,
        'memoryUsageBytes': _totalCacheMemoryUsage,
        'memoryUsageKB': (_totalCacheMemoryUsage / 1024).round(),
        'sessionContentCount': _sessionProcessedContent.length,
        'maxCacheSize': MAX_CACHE_SIZE,
        'maxContentSize': MAX_CONTENT_SIZE,
      }
    };
    
    // Combine with performance optimizer stats
    final optimizerStats = _performanceOptimizer.getPerformanceMetrics();
    final debounceStats = _debouncer.getOverallMetrics();
    
    return {
      ...legacyStats,
      'performanceOptimizer': optimizerStats,
      'debouncer': debounceStats,
    };
  }

  /// Gets session-based processed content for a URL
  String? getSessionContent(String url) {
    return _sessionProcessedContent[url];
  }

  /// Checks if memory usage is approaching limits
  bool isMemoryUsageHigh() {
    const maxMemoryUsage = MAX_CACHE_SIZE * MAX_CONTENT_SIZE * 0.1; // 10% of theoretical max
    return _totalCacheMemoryUsage > maxMemoryUsage;
  }
}