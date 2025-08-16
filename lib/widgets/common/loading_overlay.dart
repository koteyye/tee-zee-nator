import 'package:flutter/material.dart';

/// A comprehensive loading overlay widget with progress indicators and messages
/// 
/// Provides:
/// - Animated loading indicators
/// - Progress messages
/// - Cancellation support
/// - Accessibility features
class LoadingOverlay extends StatefulWidget {
  final bool isVisible;
  final String message;
  final String? progressMessage;
  final double? progress; // 0.0 to 1.0, null for indeterminate
  final VoidCallback? onCancel;
  final bool canCancel;

  const LoadingOverlay({
    super.key,
    required this.isVisible,
    required this.message,
    this.progressMessage,
    this.progress,
    this.onCancel,
    this.canCancel = false,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isVisible) {
      _fadeController.forward();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _pulseController.repeat(reverse: true);
      } else {
        _fadeController.reverse();
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Semantics(
                label: 'Loading: ${widget.message}',
                liveRegion: true,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(
                      maxWidth: 400,
                      minWidth: 300,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loading indicator
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: widget.progress != null
                                  ? SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        value: widget.progress,
                                        strokeWidth: 4,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    )
                                  : SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 4,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Main message
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Progress message
                        if (widget.progressMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.progressMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        
                        // Progress percentage
                        if (widget.progress != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${(widget.progress! * 100).round()}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                        
                        // Cancel button
                        if (widget.canCancel && widget.onCancel != null) ...[
                          const SizedBox(height: 24),
                          Semantics(
                            label: 'Cancel current operation',
                            child: OutlinedButton(
                              onPressed: widget.onCancel,
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A simpler loading indicator for inline use
class InlineLoadingIndicator extends StatelessWidget {
  final String message;
  final double size;
  final Color? color;

  const InlineLoadingIndicator({
    super.key,
    required this.message,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading: $message',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: size * 0.8,
                color: color ?? Theme.of(context).primaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}