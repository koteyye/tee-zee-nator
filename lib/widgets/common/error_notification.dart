import 'package:flutter/material.dart';

/// Виджет уведомления об ошибке/информации
class ErrorNotification extends StatefulWidget {
  final String message;
  final String? technicalDetails;
  final Duration autoCloseDuration;
  final VoidCallback? onClose;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const ErrorNotification({
    super.key,
    required this.message,
    this.technicalDetails,
    this.autoCloseDuration = const Duration(seconds: 10),
    this.onClose,
    this.backgroundColor = const Color(0xFFF44336),
    this.textColor = Colors.white,
    this.icon = Icons.error,
  });

  @override
  State<ErrorNotification> createState() => _ErrorNotificationState();
}

class _ErrorNotificationState extends State<ErrorNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: widget.backgroundColor,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.textColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              widget.message,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (widget.technicalDetails != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isExpanded = !_isExpanded);
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      _isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: widget.textColor.withOpacity(0.8),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Технические детали',
                                      style: TextStyle(
                                        color: widget.textColor.withOpacity(0.8),
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: SelectableText(
                                    widget.technicalDetails!,
                                    style: TextStyle(
                                      color: widget.textColor.withOpacity(0.9),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.close,
                            color: widget.textColor,
                            size: 18,
                          ),
                          onPressed: _close,
                          tooltip: 'Закрыть',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}