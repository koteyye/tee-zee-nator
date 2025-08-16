import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Comprehensive accessibility wrapper for UI components
/// 
/// Provides:
/// - Semantic labels and hints
/// - Live region announcements
/// - Focus management
/// - Screen reader support
class AccessibilityWrapper extends StatelessWidget {
  final Widget child;
  final String? label;
  final String? hint;
  final String? value;
  final bool isButton;
  final bool isTextField;
  final bool isLiveRegion;
  final bool excludeSemantics;
  final VoidCallback? onTap;
  final bool enabled;

  const AccessibilityWrapper({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.value,
    this.isButton = false,
    this.isTextField = false,
    this.isLiveRegion = false,
    this.excludeSemantics = false,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (excludeSemantics) {
      return ExcludeSemantics(child: child);
    }

    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      textField: isTextField,
      liveRegion: isLiveRegion,
      enabled: enabled,
      onTap: onTap,
      child: child,
    );
  }
}

/// Wrapper for interactive elements with focus management
class FocusableWrapper extends StatefulWidget {
  final Widget child;
  final String? label;
  final String? hint;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onFocusLost;
  final bool autofocus;
  final bool enabled;

  const FocusableWrapper({
    super.key,
    required this.child,
    this.label,
    this.hint,
    this.onTap,
    this.onFocus,
    this.onFocusLost,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  State<FocusableWrapper> createState() => _FocusableWrapperState();
}

class _FocusableWrapperState extends State<FocusableWrapper> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
      
      if (_isFocused) {
        widget.onFocus?.call();
      } else {
        widget.onFocusLost?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      child: GestureDetector(
        onTap: widget.enabled ? () {
          _focusNode.requestFocus();
          widget.onTap?.call();
        } : null,
        child: Container(
          decoration: _isFocused ? BoxDecoration(
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ) : null,
          child: AccessibilityWrapper(
            label: widget.label,
            hint: widget.hint,
            enabled: widget.enabled,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Wrapper for loading states with accessibility announcements
class LoadingAccessibilityWrapper extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final String loadingMessage;
  final String? completedMessage;

  const LoadingAccessibilityWrapper({
    super.key,
    required this.child,
    required this.isLoading,
    required this.loadingMessage,
    this.completedMessage,
  });

  @override
  State<LoadingAccessibilityWrapper> createState() => _LoadingAccessibilityWrapperState();
}

class _LoadingAccessibilityWrapperState extends State<LoadingAccessibilityWrapper> {
  bool _wasLoading = false;

  @override
  void didUpdateWidget(LoadingAccessibilityWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Announce loading state changes
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _announceToScreenReader(widget.loadingMessage);
      } else if (_wasLoading && widget.completedMessage != null) {
        _announceToScreenReader(widget.completedMessage!);
      }
    }
    
    _wasLoading = widget.isLoading;
  }

  void _announceToScreenReader(String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityWrapper(
      isLiveRegion: widget.isLoading,
      label: widget.isLoading ? widget.loadingMessage : null,
      child: widget.child,
    );
  }
}

/// Helper for creating accessible form fields
class AccessibleFormField extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final String? errorText;
  final bool required;
  final bool enabled;

  const AccessibleFormField({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.errorText,
    this.required = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    String fullLabel = label;
    if (required) {
      fullLabel += ' (required)';
    }

    String? fullHint = hint;
    if (errorText != null) {
      fullHint = errorText;
    }

    return AccessibilityWrapper(
      label: fullLabel,
      hint: fullHint,
      isTextField: true,
      enabled: enabled,
      child: child,
    );
  }
}

/// Helper for creating accessible buttons
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool enabled;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibilityWrapper(
      label: label,
      hint: hint,
      isButton: true,
      enabled: enabled,
      onTap: onPressed,
      child: child,
    );
  }
}