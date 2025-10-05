import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/project_file.dart';
import '../../../services/file_modification_service.dart';
import '../../../theme/ide_theme.dart';

/// Виджет отдельной вкладки файла
class TabItem extends StatefulWidget {
  final ProjectFile file;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const TabItem({
    super.key,
    required this.file,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<TabItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FileModificationService>(
      builder: (context, modificationService, child) {
        final isModified = modificationService.hasUnsavedChangesForFile(widget.file);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 100,
                maxWidth: 200,
              ),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                border: widget.isActive
                    ? Border(
                        bottom: BorderSide(
                          color: IDETheme.primaryColor,
                          width: 2,
                        ),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Иконка файла
                  Icon(
                    _getFileIcon(),
                    size: 14,
                    color: _getFileIconColor(),
                  ),
                  const SizedBox(width: 6),
                  // Название файла с индикатором изменений
                  Expanded(
                    child: Tooltip(
                      message: widget.file.path,
                      child: Text(
                        widget.file.name + (isModified ? ' •' : ''),
                        style: IDETheme.bodyMediumStyle.copyWith(
                          fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.w400,
                          color: widget.isActive ? IDETheme.textPrimary : IDETheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Кнопка закрытия
                  if (_isHovered || widget.isActive)
                    InkWell(
                      onTap: widget.onClose,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: IDETheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Получить цвет фона вкладки
  Color _getBackgroundColor() {
    if (widget.isActive) {
      return IDETheme.activeTabColor;
    }
    if (_isHovered) {
      return IDETheme.hoverColor;
    }
    return IDETheme.inactiveTabColor;
  }

  /// Получить иконку файла
  IconData _getFileIcon() {
    switch (widget.file.type) {
      case FileType.markdown:
        return Icons.description;
      case FileType.html:
        return Icons.code;
      case FileType.confluence:
        return Icons.cloud;
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  /// Получить цвет иконки файла
  Color _getFileIconColor() {
    switch (widget.file.type) {
      case FileType.markdown:
        return Colors.blue;
      case FileType.html:
        return Colors.orange;
      case FileType.confluence:
        return Colors.green;
      case FileType.unknown:
        return Colors.grey;
    }
  }
}
