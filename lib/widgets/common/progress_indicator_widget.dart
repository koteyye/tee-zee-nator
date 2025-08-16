import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'accessibility_wrapper.dart';

/// Enhanced progress indicator with multiple states and animations
/// 
/// Provides:
/// - Determinate and indeterminate progress
/// - Step-by-step progress tracking
/// - Animated state transitions
/// - Accessibility support
class ProgressIndicatorWidget extends StatefulWidget {
  final double? progress; // 0.0 to 1.0, null for indeterminate
  final String message;
  final List<ProgressStep>? steps;
  final int? currentStep;
  final bool showPercentage;
  final Color? color;
  final double size;

  const ProgressIndicatorWidget({
    super.key,
    this.progress,
    required this.message,
    this.steps,
    this.currentStep,
    this.showPercentage = true,
    this.color,
    this.size = 60,
  });

  @override
  State<ProgressIndicatorWidget> createState() => _ProgressIndicatorWidgetState();
}

class _ProgressIndicatorWidgetState extends State<ProgressIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.progress == null) {
      _rotationController.repeat();
    }
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ProgressIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.progress == null && oldWidget.progress != null) {
      _rotationController.repeat();
    } else if (widget.progress != null && oldWidget.progress == null) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryRed;
    
    return AccessibilityWrapper(
      label: 'Progress: ${widget.message}',
      value: widget.progress != null 
          ? '${(widget.progress! * 100).round()}% complete'
          : 'In progress',
      isLiveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: widget.progress != null
                      ? CircularProgressIndicator(
                          value: widget.progress,
                          strokeWidth: 4,
                          backgroundColor: color.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        )
                      : AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * 3.14159,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            );
                          },
                        ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Message
          Text(
            widget.message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Percentage
          if (widget.progress != null && widget.showPercentage) ...[
            const SizedBox(height: 8),
            Text(
              '${(widget.progress! * 100).round()}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
          
          // Steps
          if (widget.steps != null && widget.steps!.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...widget.steps!.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = widget.currentStep == index;
              final isCompleted = widget.currentStep != null && index < widget.currentStep!;
              
              return _buildStep(step, isActive, isCompleted);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(ProgressStep step, bool isActive, bool isCompleted) {
    Color stepColor;
    IconData stepIcon;
    
    if (isCompleted) {
      stepColor = Colors.green;
      stepIcon = Icons.check_circle;
    } else if (isActive) {
      stepColor = widget.color ?? AppTheme.primaryRed;
      stepIcon = Icons.radio_button_checked;
    } else {
      stepColor = Colors.grey;
      stepIcon = Icons.radio_button_unchecked;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            stepIcon,
            color: stepColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.title,
              style: TextStyle(
                fontSize: 14,
                color: stepColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isActive) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(stepColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Represents a single step in progress tracking
class ProgressStep {
  final String title;
  final String? description;

  const ProgressStep({
    required this.title,
    this.description,
  });
}

/// Specialized progress indicator for Confluence operations
class ConfluenceProgressIndicator extends StatelessWidget {
  final String operation;
  final double? progress;
  final List<String>? completedSteps;
  final String? currentStep;

  const ConfluenceProgressIndicator({
    super.key,
    required this.operation,
    this.progress,
    this.completedSteps,
    this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _getStepsForOperation(operation);
    final currentStepIndex = currentStep != null 
        ? steps.indexWhere((step) => step.title == currentStep)
        : null;
    
    return ProgressIndicatorWidget(
      progress: progress,
      message: 'Publishing to Confluence...',
      steps: steps,
      currentStep: currentStepIndex,
      color: AppTheme.primaryRed,
    );
  }

  List<ProgressStep> _getStepsForOperation(String operation) {
    switch (operation.toLowerCase()) {
      case 'create':
        return const [
          ProgressStep(title: 'Validating parent page'),
          ProgressStep(title: 'Creating new page'),
          ProgressStep(title: 'Uploading content'),
          ProgressStep(title: 'Finalizing publication'),
        ];
      case 'update':
        return const [
          ProgressStep(title: 'Validating target page'),
          ProgressStep(title: 'Backing up current content'),
          ProgressStep(title: 'Updating page content'),
          ProgressStep(title: 'Finalizing changes'),
        ];
      case 'link_processing':
        return const [
          ProgressStep(title: 'Detecting Confluence links'),
          ProgressStep(title: 'Fetching page content'),
          ProgressStep(title: 'Processing content'),
          ProgressStep(title: 'Replacing links'),
        ];
      default:
        return const [
          ProgressStep(title: 'Initializing'),
          ProgressStep(title: 'Processing'),
          ProgressStep(title: 'Completing'),
        ];
    }
  }
}

/// Inline progress indicator for smaller spaces
class InlineProgressIndicator extends StatelessWidget {
  final String message;
  final double? progress;
  final Color? color;
  final double size;

  const InlineProgressIndicator({
    super.key,
    required this.message,
    this.progress,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final indicatorColor = color ?? AppTheme.primaryRed;
    
    return AccessibilityWrapper(
      label: 'Loading: $message',
      isLiveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: size * 0.8,
                color: indicatorColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(width: 8),
            Text(
              '${(progress! * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.7,
                color: indicatorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress indicator with success/error states
class StatefulProgressIndicator extends StatefulWidget {
  final String message;
  final bool isComplete;
  final bool hasError;
  final String? errorMessage;
  final String? successMessage;
  final VoidCallback? onRetry;

  const StatefulProgressIndicator({
    super.key,
    required this.message,
    this.isComplete = false,
    this.hasError = false,
    this.errorMessage,
    this.successMessage,
    this.onRetry,
  });

  @override
  State<StatefulProgressIndicator> createState() => _StatefulProgressIndicatorState();
}

class _StatefulProgressIndicatorState extends State<StatefulProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    if (widget.isComplete || widget.hasError) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(StatefulProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if ((widget.isComplete || widget.hasError) && 
        !(oldWidget.isComplete || oldWidget.hasError)) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError) {
      return _buildErrorState();
    } else if (widget.isComplete) {
      return _buildSuccessState();
    } else {
      return _buildLoadingState();
    }
  }

  Widget _buildLoadingState() {
    return ProgressIndicatorWidget(
      message: widget.message,
      color: AppTheme.primaryRed,
    );
  }

  Widget _buildSuccessState() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AccessibilityWrapper(
            label: 'Success: ${widget.successMessage ?? widget.message}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.successMessage ?? 'Completed successfully!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AccessibilityWrapper(
            label: 'Error: ${widget.errorMessage ?? widget.message}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.errorMessage ?? 'An error occurred',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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