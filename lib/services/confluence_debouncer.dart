import 'dart:async';
import 'package:flutter/foundation.dart';

/// Advanced debouncer for Confluence text processing
/// 
/// This service provides:
/// - Configurable debounce delays for different scenarios
/// - Adaptive debouncing based on text length and complexity
/// - Priority-based processing for different text fields
/// - Cancellation and cleanup capabilities
/// - Performance monitoring
class ConfluenceDebouncer {
  static const Duration DEFAULT_DEBOUNCE_DELAY = Duration(milliseconds: 500);
  static const Duration FAST_DEBOUNCE_DELAY = Duration(milliseconds: 200);
  static const Duration SLOW_DEBOUNCE_DELAY = Duration(milliseconds: 1000);
  
  // Thresholds for adaptive debouncing
  static const int SHORT_TEXT_THRESHOLD = 100;
  static const int LONG_TEXT_THRESHOLD = 1000;
  static const int LINK_COUNT_THRESHOLD = 3;
  
  final Map<String, Timer> _timers = {};
  final Map<String, _DebounceConfig> _configs = {};
  final Map<String, _DebounceMetrics> _metrics = {};
  
  /// Creates a debounced function for text processing
  /// 
  /// [key] - Unique identifier for this debounced operation
  /// [callback] - Function to call after debounce delay
  /// [config] - Optional configuration for debouncing behavior
  void debounce(
    String key,
    Future<void> Function() callback, {
    _DebounceConfig? config,
  }) {
    // Cancel existing timer
    _timers[key]?.cancel();
    
    // Use provided config or default
    final debounceConfig = config ?? _configs[key] ?? _DebounceConfig();
    _configs[key] = debounceConfig;
    
    // Initialize metrics if not exists
    _metrics[key] ??= _DebounceMetrics();
    
    // Record debounce attempt
    _metrics[key]!.recordDebounceAttempt();
    
    // Create new timer
    _timers[key] = Timer(debounceConfig.delay, () async {
      final stopwatch = Stopwatch()..start();
      
      try {
        await callback();
        _metrics[key]!.recordSuccess(stopwatch.elapsedMilliseconds);
      } catch (e) {
        _metrics[key]!.recordError();
        debugPrint('Debounced callback failed for key $key: $e');
        rethrow;
      } finally {
        _timers.remove(key);
      }
    });
  }

  /// Creates an adaptive debounced function that adjusts delay based on content
  void adaptiveDebounce(
    String key,
    String text,
    Future<void> Function() callback, {
    Duration? minDelay,
    Duration? maxDelay,
  }) {
    final adaptiveConfig = _createAdaptiveConfig(
      text,
      minDelay: minDelay ?? FAST_DEBOUNCE_DELAY,
      maxDelay: maxDelay ?? SLOW_DEBOUNCE_DELAY,
    );
    
    debounce(key, callback, config: adaptiveConfig);
  }

  /// Creates a priority-based debounced function
  void priorityDebounce(
    String key,
    Future<void> Function() callback,
    DebouncePriority priority,
  ) {
    final config = _createPriorityConfig(priority);
    debounce(key, callback, config: config);
  }

  /// Cancels a specific debounced operation
  void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _metrics[key]?.recordCancellation();
  }

  /// Cancels all debounced operations
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    
    for (final metrics in _metrics.values) {
      metrics.recordCancellation();
    }
  }

  /// Checks if a debounced operation is pending
  bool isPending(String key) {
    return _timers.containsKey(key);
  }

  /// Gets the remaining time for a debounced operation
  Duration? getRemainingTime(String key) {
    final timer = _timers[key];
    if (timer == null || !timer.isActive) return null;
    
    // Note: Timer doesn't expose remaining time directly
    // This is an approximation based on when it was created
    final config = _configs[key];
    if (config == null) return null;
    
    return config.delay;
  }

  /// Gets metrics for a specific debounced operation
  Map<String, dynamic> getMetrics(String key) {
    final metrics = _metrics[key];
    if (metrics == null) return {};
    
    return metrics.toMap();
  }

  /// Gets overall debouncing statistics
  Map<String, dynamic> getOverallMetrics() {
    int totalAttempts = 0;
    int totalSuccesses = 0;
    int totalErrors = 0;
    int totalCancellations = 0;
    int totalExecutionTime = 0;
    
    for (final metrics in _metrics.values) {
      totalAttempts += metrics.attempts;
      totalSuccesses += metrics.successes;
      totalErrors += metrics.errors;
      totalCancellations += metrics.cancellations;
      totalExecutionTime += metrics.totalExecutionTimeMs;
    }
    
    return {
      'activeOperations': _timers.length,
      'totalOperations': _metrics.length,
      'totalAttempts': totalAttempts,
      'totalSuccesses': totalSuccesses,
      'totalErrors': totalErrors,
      'totalCancellations': totalCancellations,
      'successRate': totalAttempts == 0 ? 0.0 : (totalSuccesses / totalAttempts * 100).toStringAsFixed(1),
      'averageExecutionTimeMs': totalSuccesses == 0 ? 0.0 : (totalExecutionTime / totalSuccesses).toStringAsFixed(1),
    };
  }

  /// Creates adaptive configuration based on text content
  _DebounceConfig _createAdaptiveConfig(
    String text, {
    required Duration minDelay,
    required Duration maxDelay,
  }) {
    // Analyze text characteristics
    final textLength = text.length;
    final linkCount = _countPotentialLinks(text);
    final complexity = _calculateTextComplexity(text);
    
    // Calculate adaptive delay
    Duration delay = DEFAULT_DEBOUNCE_DELAY;
    
    // Adjust based on text length
    if (textLength < SHORT_TEXT_THRESHOLD) {
      delay = minDelay;
    } else if (textLength > LONG_TEXT_THRESHOLD) {
      delay = maxDelay;
    } else {
      // Linear interpolation between min and max
      final ratio = (textLength - SHORT_TEXT_THRESHOLD) / 
                   (LONG_TEXT_THRESHOLD - SHORT_TEXT_THRESHOLD);
      final delayMs = minDelay.inMilliseconds + 
                     (ratio * (maxDelay.inMilliseconds - minDelay.inMilliseconds));
      delay = Duration(milliseconds: delayMs.round());
    }
    
    // Adjust based on link count
    if (linkCount > LINK_COUNT_THRESHOLD) {
      delay = Duration(milliseconds: (delay.inMilliseconds * 1.5).round());
    }
    
    // Adjust based on complexity
    if (complexity > 0.7) {
      delay = Duration(milliseconds: (delay.inMilliseconds * 1.3).round());
    }
    
    // Ensure within bounds
    if (delay < minDelay) delay = minDelay;
    if (delay > maxDelay) delay = maxDelay;
    
    return _DebounceConfig(
      delay: delay,
      adaptive: true,
      textLength: textLength,
      linkCount: linkCount,
      complexity: complexity,
    );
  }

  /// Creates priority-based configuration
  _DebounceConfig _createPriorityConfig(DebouncePriority priority) {
    switch (priority) {
      case DebouncePriority.high:
        return _DebounceConfig(delay: FAST_DEBOUNCE_DELAY);
      case DebouncePriority.normal:
        return _DebounceConfig(delay: DEFAULT_DEBOUNCE_DELAY);
      case DebouncePriority.low:
        return _DebounceConfig(delay: SLOW_DEBOUNCE_DELAY);
    }
  }

  /// Counts potential Confluence links in text
  int _countPotentialLinks(String text) {
    final confluenceUrlPattern = RegExp(
      r'https?://[^\s/]+\.atlassian\.net/wiki/[^\s]*',
      caseSensitive: false,
    );
    return confluenceUrlPattern.allMatches(text).length;
  }

  /// Calculates text complexity score (0.0 to 1.0)
  double _calculateTextComplexity(String text) {
    if (text.isEmpty) return 0.0;
    
    // Factors that increase complexity:
    // - Number of lines
    // - Number of URLs
    // - Number of special characters
    // - Variety of characters
    
    final lines = text.split('\n').length;
    final urls = RegExp(r'https?://[^\s]+').allMatches(text).length;
    final specialChars = RegExp(r'[^\w\s]').allMatches(text).length;
    final uniqueChars = text.toLowerCase().split('').toSet().length;
    
    // Normalize factors
    final lineComplexity = (lines / 20).clamp(0.0, 1.0);
    final urlComplexity = (urls / 10).clamp(0.0, 1.0);
    final specialCharComplexity = (specialChars / text.length).clamp(0.0, 1.0);
    final charVarietyComplexity = (uniqueChars / 50).clamp(0.0, 1.0);
    
    // Weighted average
    return (lineComplexity * 0.3 + 
            urlComplexity * 0.4 + 
            specialCharComplexity * 0.2 + 
            charVarietyComplexity * 0.1);
  }

  /// Disposes of all resources
  void dispose() {
    cancelAll();
    _configs.clear();
    _metrics.clear();
  }
}

/// Configuration for debouncing behavior
class _DebounceConfig {
  final Duration delay;
  final bool adaptive;
  final int textLength;
  final int linkCount;
  final double complexity;
  
  _DebounceConfig({
    this.delay = ConfluenceDebouncer.DEFAULT_DEBOUNCE_DELAY,
    this.adaptive = false,
    this.textLength = 0,
    this.linkCount = 0,
    this.complexity = 0.0,
  });
}

/// Metrics for debouncing operations
class _DebounceMetrics {
  int attempts = 0;
  int successes = 0;
  int errors = 0;
  int cancellations = 0;
  int totalExecutionTimeMs = 0;
  DateTime? lastAttempt;
  DateTime? lastSuccess;
  
  void recordDebounceAttempt() {
    attempts++;
    lastAttempt = DateTime.now();
  }
  
  void recordSuccess(int executionTimeMs) {
    successes++;
    totalExecutionTimeMs += executionTimeMs;
    lastSuccess = DateTime.now();
  }
  
  void recordError() {
    errors++;
  }
  
  void recordCancellation() {
    cancellations++;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'attempts': attempts,
      'successes': successes,
      'errors': errors,
      'cancellations': cancellations,
      'successRate': attempts == 0 ? 0.0 : (successes / attempts * 100).toStringAsFixed(1),
      'averageExecutionTimeMs': successes == 0 ? 0.0 : (totalExecutionTimeMs / successes).toStringAsFixed(1),
      'lastAttempt': lastAttempt?.toIso8601String(),
      'lastSuccess': lastSuccess?.toIso8601String(),
    };
  }
}

/// Priority levels for debouncing
enum DebouncePriority {
  high,   // Fast response for critical operations
  normal, // Standard debouncing
  low,    // Slower response for less critical operations
}