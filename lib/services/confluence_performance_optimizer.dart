import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/confluence_link.dart';
import '../models/confluence_config.dart';
import 'confluence_service.dart';
import 'confluence_content_processor.dart';

/// Performance optimizer for Confluence operations
/// 
/// This service provides:
/// - Intelligent caching with LRU eviction and TTL
/// - Batch processing for multiple Confluence links
/// - Request deduplication to prevent duplicate API calls
/// - Memory usage monitoring and optimization
/// - Performance metrics and benchmarking
class ConfluencePerformanceOptimizer {
  static const Duration DEFAULT_CACHE_TTL = Duration(minutes: 30);
  static const Duration BATCH_PROCESSING_DELAY = Duration(milliseconds: 100);
  static const int DEFAULT_MAX_CACHE_SIZE = 200;
  static const int DEFAULT_MAX_MEMORY_MB = 50;
  static const int MAX_BATCH_SIZE = 10;
  static const int MAX_CONCURRENT_REQUESTS = 3;
  
  final ConfluenceService _confluenceService;
  final ConfluenceContentProcessor _contentProcessor;
  
  // Intelligent cache with LRU eviction
  final LinkedHashMap<String, _CacheEntry> _intelligentCache = LinkedHashMap();
  
  // Batch processing (removed unused queue for now)
  Timer? _batchTimer;
  
  // Request deduplication
  final Map<String, Future<String>> _pendingRequests = {};
  
  // Performance metrics
  final _PerformanceMetrics _metrics = _PerformanceMetrics();
  
  // Configuration
  int _maxCacheSize;
  int _maxMemoryBytes;
  Duration _cacheTtl;
  
  // Memory tracking
  int _currentMemoryUsage = 0;
  
  ConfluencePerformanceOptimizer(
    this._confluenceService,
    this._contentProcessor, {
    int maxCacheSize = DEFAULT_MAX_CACHE_SIZE,
    int maxMemoryMB = DEFAULT_MAX_MEMORY_MB,
    Duration cacheTtl = DEFAULT_CACHE_TTL,
  }) : _maxCacheSize = maxCacheSize,
       _maxMemoryBytes = maxMemoryMB * 1024 * 1024,
       _cacheTtl = cacheTtl;

  /// Processes text with intelligent caching and batch optimization
  Future<String> processTextOptimized(
    String text,
    ConfluenceConfig config, {
    bool enableBatching = true,
    bool enableCaching = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Extract links from text
      final links = _contentProcessor.extractLinks(text, config.sanitizedBaseUrl);
      
      if (links.isEmpty) {
        _metrics.recordProcessingTime(stopwatch.elapsedMilliseconds, 0);
        return text;
      }
      
      // Process links with optimization
      final linkContentMap = <String, String>{};
      
      if (enableBatching && links.length > 1) {
        // Use batch processing for multiple links
        final batchResults = await _processBatch(links, config, enableCaching);
        linkContentMap.addAll(batchResults);
      } else {
        // Process individual links
        for (final link in links) {
          final content = await _processLinkOptimized(link, config, enableCaching);
          linkContentMap[link] = content;
        }
      }
      
      // Replace links with content
      final result = _contentProcessor.replaceLinksWithContent(text, linkContentMap);
      
      _metrics.recordProcessingTime(stopwatch.elapsedMilliseconds, links.length);
      return result;
      
    } catch (e) {
      _metrics.recordError();
      rethrow;
    }
  }

  /// Processes a single link with caching and deduplication
  Future<String> _processLinkOptimized(
    String linkUrl,
    ConfluenceConfig config,
    bool enableCaching,
  ) async {
    // Check intelligent cache first
    if (enableCaching) {
      final cachedContent = _getFromIntelligentCache(linkUrl);
      if (cachedContent != null) {
        _metrics.recordCacheHit();
        return cachedContent;
      }
    }
    
    // Check for pending request to avoid duplication
    final pendingRequest = _pendingRequests[linkUrl];
    if (pendingRequest != null) {
      _metrics.recordDeduplication();
      return await pendingRequest;
    }
    
    // Create new request
    final requestFuture = _fetchLinkContent(linkUrl, config);
    _pendingRequests[linkUrl] = requestFuture;
    
    try {
      final content = await requestFuture;
      
      // Cache the result
      if (enableCaching) {
        _addToIntelligentCache(linkUrl, content);
      }
      
      _metrics.recordCacheMiss();
      return content;
      
    } finally {
      _pendingRequests.remove(linkUrl);
    }
  }

  /// Processes multiple links in batches for better performance
  Future<Map<String, String>> _processBatch(
    List<String> links,
    ConfluenceConfig config,
    bool enableCaching,
  ) async {
    final results = <String, String>{};
    final uncachedLinks = <String>[];
    
    // Check cache for all links first
    if (enableCaching) {
      for (final link in links) {
        final cachedContent = _getFromIntelligentCache(link);
        if (cachedContent != null) {
          results[link] = cachedContent;
          _metrics.recordCacheHit();
        } else {
          uncachedLinks.add(link);
        }
      }
    } else {
      uncachedLinks.addAll(links);
    }
    
    if (uncachedLinks.isEmpty) {
      return results;
    }
    
    // Process uncached links in batches
    final batches = _createBatches(uncachedLinks, MAX_BATCH_SIZE);
    
    for (final batch in batches) {
      final batchResults = await _processBatchConcurrently(batch, config);
      results.addAll(batchResults);
      
      // Cache batch results
      if (enableCaching) {
        for (final entry in batchResults.entries) {
          _addToIntelligentCache(entry.key, entry.value);
        }
      }
    }
    
    return results;
  }

  /// Processes a batch of links concurrently with controlled concurrency
  Future<Map<String, String>> _processBatchConcurrently(
    List<String> batch,
    ConfluenceConfig config,
  ) async {
    final results = <String, String>{};
    final semaphore = Semaphore(MAX_CONCURRENT_REQUESTS);
    
    final futures = batch.map((link) async {
      await semaphore.acquire();
      try {
        // Check for pending request
        final pendingRequest = _pendingRequests[link];
        if (pendingRequest != null) {
          _metrics.recordDeduplication();
          return MapEntry(link, await pendingRequest);
        }
        
        // Create new request
        final requestFuture = _fetchLinkContent(link, config);
        _pendingRequests[link] = requestFuture;
        
        try {
          final content = await requestFuture;
          _metrics.recordCacheMiss();
          return MapEntry(link, content);
        } finally {
          _pendingRequests.remove(link);
        }
      } finally {
        semaphore.release();
      }
    });
    
    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }
    
    return results;
  }

  /// Fetches content for a single link
  Future<String> _fetchLinkContent(String linkUrl, ConfluenceConfig config) async {
    try {
      final pageId = ConfluenceLink.extractPageIdFromUrl(linkUrl);
      if (pageId == null) {
        return linkUrl; // Return original URL if invalid
      }
      
      final content = await _confluenceService.getPageContent(pageId);
      final sanitizedContent = _contentProcessor.sanitizeContent(content);
      
      return '${ConfluenceContentProcessor.CONTENT_MARKER_START}$sanitizedContent${ConfluenceContentProcessor.CONTENT_MARKER_END}';
      
    } catch (e) {
      debugPrint('Failed to fetch content for $linkUrl: $e');
      return linkUrl; // Return original URL on error
    }
  }

  /// Gets content from intelligent cache with LRU access tracking
  String? _getFromIntelligentCache(String key) {
    final entry = _intelligentCache[key];
    if (entry == null) return null;
    
    // Check TTL
    if (DateTime.now().difference(entry.timestamp) > _cacheTtl) {
      _removeFromIntelligentCache(key);
      return null;
    }
    
    // Update access time for LRU
    entry.lastAccessed = DateTime.now();
    
    // Move to end (most recently used)
    _intelligentCache.remove(key);
    _intelligentCache[key] = entry;
    
    return entry.content;
  }

  /// Adds content to intelligent cache with memory management
  void _addToIntelligentCache(String key, String content) {
    final contentSize = _calculateContentSize(content);
    
    // Check if content is too large to cache
    if (contentSize > _maxMemoryBytes * 0.1) { // Don't cache items larger than 10% of max memory
      return;
    }
    
    // Ensure we have space
    _ensureCacheSpace(contentSize);
    
    final entry = _CacheEntry(
      content: content,
      timestamp: DateTime.now(),
      lastAccessed: DateTime.now(),
      size: contentSize,
    );
    
    // Remove existing entry if present
    _removeFromIntelligentCache(key);
    
    // Add new entry
    _intelligentCache[key] = entry;
    _currentMemoryUsage += contentSize;
  }

  /// Removes entry from intelligent cache
  void _removeFromIntelligentCache(String key) {
    final entry = _intelligentCache.remove(key);
    if (entry != null) {
      _currentMemoryUsage -= entry.size;
    }
  }

  /// Ensures cache has space for new content
  void _ensureCacheSpace(int requiredSize) {
    // Check size limit
    while (_intelligentCache.length >= _maxCacheSize) {
      _evictLeastRecentlyUsed();
    }
    
    // Check memory limit
    while (_currentMemoryUsage + requiredSize > _maxMemoryBytes) {
      if (_intelligentCache.isEmpty) break;
      _evictLeastRecentlyUsed();
    }
  }

  /// Evicts least recently used entry from cache
  void _evictLeastRecentlyUsed() {
    if (_intelligentCache.isEmpty) return;
    
    // Find LRU entry
    String? lruKey;
    DateTime? oldestAccess;
    
    for (final entry in _intelligentCache.entries) {
      if (oldestAccess == null || entry.value.lastAccessed.isBefore(oldestAccess)) {
        oldestAccess = entry.value.lastAccessed;
        lruKey = entry.key;
      }
    }
    
    if (lruKey != null) {
      _removeFromIntelligentCache(lruKey);
    }
  }

  /// Creates batches from a list of items
  List<List<T>> _createBatches<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  /// Calculates approximate memory size of content
  int _calculateContentSize(String content) {
    return content.length * 2 + 64; // UTF-16 encoding + object overhead
  }

  /// Clears all cached data
  void clearCache() {
    _intelligentCache.clear();
    _currentMemoryUsage = 0;
    _pendingRequests.clear();
    _metrics.reset();
  }

  /// Gets performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'cacheSize': _intelligentCache.length,
      'memoryUsageBytes': _currentMemoryUsage,
      'memoryUsageMB': (_currentMemoryUsage / (1024 * 1024)).toStringAsFixed(2),
      'memoryUtilization': ((_currentMemoryUsage / _maxMemoryBytes) * 100).toStringAsFixed(1),
      'pendingRequests': _pendingRequests.length,
      'maxCacheSize': _maxCacheSize,
      'maxMemoryMB': (_maxMemoryBytes / (1024 * 1024)).round(),
      'cacheTtlMinutes': _cacheTtl.inMinutes,
      ..._metrics.toMap(),
    };
  }

  /// Gets cache statistics for monitoring
  Map<String, dynamic> getCacheStatistics() {
    final now = DateTime.now();
    int freshEntries = 0;
    int staleEntries = 0;
    
    for (final entry in _intelligentCache.values) {
      if (now.difference(entry.timestamp) <= _cacheTtl) {
        freshEntries++;
      } else {
        staleEntries++;
      }
    }
    
    return {
      'totalEntries': _intelligentCache.length,
      'freshEntries': freshEntries,
      'staleEntries': staleEntries,
      'memoryUsageBytes': _currentMemoryUsage,
      'averageEntrySize': _intelligentCache.isEmpty 
          ? 0 
          : (_currentMemoryUsage / _intelligentCache.length).round(),
    };
  }

  /// Performs cache maintenance (removes stale entries)
  void performMaintenance() {
    final now = DateTime.now();
    final staleKeys = <String>[];
    
    for (final entry in _intelligentCache.entries) {
      if (now.difference(entry.value.timestamp) > _cacheTtl) {
        staleKeys.add(entry.key);
      }
    }
    
    for (final key in staleKeys) {
      _removeFromIntelligentCache(key);
    }
    
    debugPrint('ConfluencePerformanceOptimizer: Maintenance completed. '
               'Removed ${staleKeys.length} stale entries. '
               'Cache size: ${_intelligentCache.length}');
  }

  /// Updates configuration
  void updateConfiguration({
    int? maxCacheSize,
    int? maxMemoryMB,
    Duration? cacheTtl,
  }) {
    if (maxCacheSize != null) _maxCacheSize = maxCacheSize;
    if (maxMemoryMB != null) _maxMemoryBytes = maxMemoryMB * 1024 * 1024;
    if (cacheTtl != null) _cacheTtl = cacheTtl;
    
    // Ensure current cache fits new limits
    _ensureCacheSpace(0);
  }

  /// Disposes of resources
  void dispose() {
    _batchTimer?.cancel();
    clearCache();
  }
}

/// Cache entry with metadata
class _CacheEntry {
  final String content;
  final DateTime timestamp;
  DateTime lastAccessed;
  final int size;
  
  _CacheEntry({
    required this.content,
    required this.timestamp,
    required this.lastAccessed,
    required this.size,
  });
}

/// Performance metrics tracking
class _PerformanceMetrics {
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _deduplications = 0;
  int _errors = 0;
  int _totalProcessingTimeMs = 0;
  int _totalLinksProcessed = 0;
  
  void recordCacheHit() => _cacheHits++;
  void recordCacheMiss() => _cacheMisses++;
  void recordDeduplication() => _deduplications++;
  void recordError() => _errors++;
  
  void recordProcessingTime(int timeMs, int linkCount) {
    _totalRequests++;
    _totalProcessingTimeMs += timeMs;
    _totalLinksProcessed += linkCount;
  }
  
  double get cacheHitRate => _totalRequests == 0 ? 0.0 : _cacheHits / _totalRequests;
  double get averageProcessingTimeMs => _totalRequests == 0 ? 0.0 : _totalProcessingTimeMs / _totalRequests;
  double get averageLinksPerRequest => _totalRequests == 0 ? 0.0 : _totalLinksProcessed / _totalRequests;
  
  Map<String, dynamic> toMap() {
    return {
      'totalRequests': _totalRequests,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'deduplications': _deduplications,
      'errors': _errors,
      'cacheHitRate': (cacheHitRate * 100).toStringAsFixed(1),
      'averageProcessingTimeMs': averageProcessingTimeMs.toStringAsFixed(1),
      'averageLinksPerRequest': averageLinksPerRequest.toStringAsFixed(1),
      'totalProcessingTimeMs': _totalProcessingTimeMs,
      'totalLinksProcessed': _totalLinksProcessed,
    };
  }
  
  void reset() {
    _totalRequests = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _deduplications = 0;
    _errors = 0;
    _totalProcessingTimeMs = 0;
    _totalLinksProcessed = 0;
  }
}

/// Semaphore for controlling concurrent operations
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  Semaphore(this.maxCount) : _currentCount = maxCount;
  
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }
  
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}