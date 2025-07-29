import 'package:flutter/material.dart';
import '../../models/output_format.dart';

/// Widget for selecting the output format (Markdown or Confluence)
/// with radio button interface and proper state management
class FormatSelector extends StatefulWidget {
  /// Currently selected format
  final OutputFormat selectedFormat;
  
  /// Callback when format selection changes
  final ValueChanged<OutputFormat> onFormatChanged;
  
  const FormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  @override
  State<FormatSelector> createState() => _FormatSelectorState();
}

class _FormatSelectorState extends State<FormatSelector> {
  late OutputFormat _currentFormat;
  
  @override
  void initState() {
    super.initState();
    // Initialize with the provided format, defaulting to Markdown if none provided
    _currentFormat = widget.selectedFormat;
  }
  
  @override
  void didUpdateWidget(FormatSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal state if the parent changes the selected format
    if (oldWidget.selectedFormat != widget.selectedFormat) {
      _currentFormat = widget.selectedFormat;
    }
  }
  
  void _handleFormatChange(OutputFormat? format) {
    if (format != null && format != _currentFormat) {
      setState(() {
        _currentFormat = format;
      });
      widget.onFormatChanged(format);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Формат вывода:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: OutputFormat.values.map((format) {
            return Expanded(
              child: _buildRadioOption(format),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildRadioOption(OutputFormat format) {
    final isSelected = _currentFormat == format;
    
    return InkWell(
      onTap: () => _handleFormatChange(format),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<OutputFormat>(
              value: format,
              groupValue: _currentFormat,
              onChanged: _handleFormatChange,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    format.displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : null,
                    ),
                  ),
                  if (format.isDefault)
                    Text(
                      'По умолчанию',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}