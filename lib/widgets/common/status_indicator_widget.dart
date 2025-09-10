import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'enhanced_tooltip.dart';
import 'accessibility_wrapper.dart';

/// Comprehensive status indicator widget
/// 
/// Provides:
/// - Connection status indicators
/// - Feature availability status
/// - System health indicators
/// - Interactive status details
class StatusIndicatorWidget extends StatelessWidget {
  final String label;
  final StatusType status;
  final String? message;
  final String? details;
  final VoidCallback? onTap;
  final IconData? customIcon;
  final bool showLabel;
  final double size;

  const StatusIndicatorWidget({
    super.key,
    required this.label,
    required this.status,
    this.message,
    this.details,
    this.onTap,
    this.customIcon,
    this.showLabel = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);
    
    Widget indicator = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: statusInfo.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        customIcon ?? statusInfo.icon,
        color: Colors.white,
        size: size * 0.6,
      ),
    );

    if (onTap != null) {
      indicator = GestureDetector(
        onTap: onTap,
        child: indicator,
      );
    }

    Widget result = AccessibilityWrapper(
      label: '$label: ${statusInfo.description}',
      hint: message ?? details,
      isButton: onTap != null,
      onTap: onTap,
      child: EnhancedTooltip(
        message: message ?? statusInfo.description,
        richMessage: details,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            indicator,
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w500,
                  color: statusInfo.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return result;
  }

  _StatusInfo _getStatusInfo(StatusType status) {
    switch (status) {
      case StatusType.connected:
        return _StatusInfo(
          color: Colors.green,
          icon: Icons.check_circle,
          description: 'Connected',
        );
      case StatusType.disconnected:
        return _StatusInfo(
          color: Colors.red,
          icon: Icons.error,
          description: 'Disconnected',
        );
      case StatusType.connecting:
        return _StatusInfo(
          color: Colors.orange,
          icon: Icons.sync,
          description: 'Connecting',
        );
      case StatusType.warning:
        return _StatusInfo(
          color: Colors.orange,
          icon: Icons.warning,
          description: 'Warning',
        );
      case StatusType.disabled:
        return _StatusInfo(
          color: Colors.grey,
          icon: Icons.block,
          description: 'Disabled',
        );
      case StatusType.unknown:
        return _StatusInfo(
          color: Colors.grey,
          icon: Icons.help,
          description: 'Unknown',
        );
    }
  }
}

class _StatusInfo {
  final Color color;
  final IconData icon;
  final String description;

  _StatusInfo({
    required this.color,
    required this.icon,
    required this.description,
  });
}

enum StatusType {
  connected,
  disconnected,
  connecting,
  warning,
  disabled,
  unknown,
}

/// Specialized status indicator for Confluence connection
class ConfluenceStatusIndicator extends StatelessWidget {
  final bool isEnabled;
  final bool isConnected;
  final bool isConnecting;
  final String? errorMessage;
  final VoidCallback? onTap;

  const ConfluenceStatusIndicator({
    super.key,
    required this.isEnabled,
    required this.isConnected,
    this.isConnecting = false,
    this.errorMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    StatusType status;
    String message;
    String? details;

    if (!isEnabled) {
      status = StatusType.disabled;
      message = 'Confluence integration is disabled';
      details = 'Enable in settings to use Confluence features';
    } else if (isConnecting) {
      status = StatusType.connecting;
      message = 'Connecting to Confluence...';
      details = 'Testing connection with your Confluence workspace';
    } else if (isConnected) {
      status = StatusType.connected;
      message = 'Connected to Confluence';
      details = 'You can reference Confluence pages and publish specifications';
    } else if (errorMessage != null) {
      status = StatusType.disconnected;
      message = 'Confluence connection failed';
      details = errorMessage;
    } else {
      status = StatusType.warning;
      message = 'Confluence not configured';
      details = 'Configure connection in settings to enable features';
    }

    return StatusIndicatorWidget(
      label: 'Confluence',
      status: status,
      message: message,
      details: details,
      onTap: onTap,
      customIcon: Icons.link,
    );
  }
}

/// System status panel showing multiple indicators
class SystemStatusPanel extends StatelessWidget {
  final bool confluenceEnabled;
  final bool confluenceConnected;
  final bool confluenceConnecting;
  final String? confluenceError;
  final bool llmConfigured;
  final String? llmModel;
  final VoidCallback? onConfluenceStatusTap;
  final VoidCallback? onLlmStatusTap;

  const SystemStatusPanel({
    super.key,
    required this.confluenceEnabled,
    required this.confluenceConnected,
    this.confluenceConnecting = false,
    this.confluenceError,
    required this.llmConfigured,
    this.llmModel,
    this.onConfluenceStatusTap,
    this.onLlmStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ConfluenceStatusIndicator(
                    isEnabled: confluenceEnabled,
                    isConnected: confluenceConnected,
                    isConnecting: confluenceConnecting,
                    errorMessage: confluenceError,
                    onTap: onConfluenceStatusTap,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatusIndicatorWidget(
                    label: 'LLM',
                    status: llmConfigured ? StatusType.connected : StatusType.warning,
                    message: llmConfigured 
                        ? 'LLM configured and ready'
                        : 'LLM not configured',
                    details: llmConfigured 
                        ? 'Using model: ${llmModel ?? 'Unknown'}'
                        : 'Configure LLM settings to generate specifications',
                    onTap: onLlmStatusTap,
                    customIcon: Icons.psychology,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated status indicator with pulse effect
class AnimatedStatusIndicator extends StatefulWidget {
  final String label;
  final StatusType status;
  final String? message;
  final bool animate;

  const AnimatedStatusIndicator({
    super.key,
    required this.label,
    required this.status,
    this.message,
    this.animate = true,
  });

  @override
  State<AnimatedStatusIndicator> createState() => _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (widget.animate && 
        (widget.status == StatusType.connecting || widget.status == StatusType.warning)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.animate && 
        (widget.status == StatusType.connecting || widget.status == StatusType.warning)) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: StatusIndicatorWidget(
            label: widget.label,
            status: widget.status,
            message: widget.message,
          ),
        );
      },
    );
  }
}

/// Compact status bar for showing multiple status indicators
class StatusBar extends StatelessWidget {
  final List<Widget> indicators;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const StatusBar({
    super.key,
    required this.indicators,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.lightGray,
        border: Border(
          top: BorderSide(color: AppTheme.borderGray),
        ),
      ),
      child: Row(
        children: indicators
            .expand((indicator) => [indicator, const SizedBox(width: 16)])
            .take(indicators.length * 2 - 1)
            .toList(),
      ),
    );
  }
}