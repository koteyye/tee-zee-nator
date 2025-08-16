import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'confluence_content_processor.dart';

/// Service for managing Confluence session lifecycle and cleanup
/// 
/// This service handles:
/// - Application lifecycle monitoring
/// - Automatic cleanup on application shutdown
/// - Session-based memory management
/// - Coordination between multiple content processors
class ConfluenceSessionManager {
  static final ConfluenceSessionManager _instance = ConfluenceSessionManager._internal();
  factory ConfluenceSessionManager() => _instance;
  ConfluenceSessionManager._internal();

  final List<ConfluenceContentProcessor> _processors = [];
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  bool _isInitialized = false;

  /// Initializes the session manager and starts monitoring app lifecycle
  void initialize() {
    if (_isInitialized) return;
    
    _isInitialized = true;
    _startLifecycleMonitoring();
    debugPrint('ConfluenceSessionManager: Initialized');
  }

  /// Registers a content processor for session management
  void registerProcessor(ConfluenceContentProcessor processor) {
    if (!_processors.contains(processor)) {
      _processors.add(processor);
      debugPrint('ConfluenceSessionManager: Registered processor (${_processors.length} total)');
    }
  }

  /// Unregisters a content processor
  void unregisterProcessor(ConfluenceContentProcessor processor) {
    if (_processors.remove(processor)) {
      debugPrint('ConfluenceSessionManager: Unregistered processor (${_processors.length} remaining)');
    }
  }

  /// Starts monitoring application lifecycle events
  void _startLifecycleMonitoring() {
    // Note: In Flutter, we need to use WidgetsBindingObserver for lifecycle events
    // This is a simplified version - in a real app, this would be integrated
    // with the main app widget that implements WidgetsBindingObserver
    debugPrint('ConfluenceSessionManager: Lifecycle monitoring started');
  }

  /// Handles application lifecycle state changes
  void handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        // No specific action needed
        break;
      case AppLifecycleState.hidden:
        // No specific action needed
        break;
    }
  }

  /// Called when app is paused (backgrounded)
  void _onAppPaused() {
    debugPrint('ConfluenceSessionManager: App paused - performing cleanup');
    _performSessionCleanup();
  }

  /// Called when app is detached (shutting down)
  void _onAppDetached() {
    debugPrint('ConfluenceSessionManager: App detached - performing full cleanup');
    _performFullCleanup();
  }

  /// Called when app is resumed (foregrounded)
  void _onAppResumed() {
    debugPrint('ConfluenceSessionManager: App resumed');
    // Could implement cache warming or validation here if needed
  }

  /// Performs session cleanup (clears session data but keeps cache)
  void _performSessionCleanup() {
    for (final processor in _processors) {
      processor.clearSessionContent();
    }
    debugPrint('ConfluenceSessionManager: Session cleanup completed for ${_processors.length} processors');
  }

  /// Performs full cleanup (clears all data)
  void _performFullCleanup() {
    for (final processor in _processors) {
      processor.clearAllData();
    }
    debugPrint('ConfluenceSessionManager: Full cleanup completed for ${_processors.length} processors');
  }

  /// Manually triggers cleanup (useful for testing or explicit cleanup)
  void triggerCleanup({bool fullCleanup = false}) {
    if (fullCleanup) {
      _performFullCleanup();
    } else {
      _performSessionCleanup();
    }
  }

  /// Gets memory usage statistics across all processors
  Map<String, dynamic> getMemoryStats() {
    int totalCached = 0;
    int totalMemoryUsage = 0;
    int totalSessionContent = 0;
    
    for (final processor in _processors) {
      final stats = processor.getCacheStats();
      totalCached += stats['totalCached'] as int;
      totalMemoryUsage += stats['memoryUsageBytes'] as int;
      totalSessionContent += stats['sessionContentCount'] as int;
    }
    
    return {
      'processorsCount': _processors.length,
      'totalCachedLinks': totalCached,
      'totalMemoryUsageBytes': totalMemoryUsage,
      'totalMemoryUsageKB': (totalMemoryUsage / 1024).round(),
      'totalSessionContent': totalSessionContent,
      'isInitialized': _isInitialized,
    };
  }

  /// Checks if any processor has high memory usage
  bool hasHighMemoryUsage() {
    return _processors.any((processor) => processor.isMemoryUsageHigh());
  }

  /// Disposes of the session manager
  void dispose() {
    _lifecycleSubscription?.cancel();
    _performFullCleanup();
    _processors.clear();
    _isInitialized = false;
    debugPrint('ConfluenceSessionManager: Disposed');
  }
}