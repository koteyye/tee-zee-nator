import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/file_node_model.dart';
import '../../../models/project_file.dart';
import '../../../services/file_explorer_service.dart';
import '../../../services/file_modification_service.dart';
import '../../../services/project_service.dart';
import '../../../theme/ide_theme.dart';

/// Виджет элемента в дереве файлов
/// Автоматически выбирает отображение для файла или папки
class FileNodeItem extends StatefulWidget {
  final FileNode node;
  final VoidCallback? onTap;

  const FileNodeItem({
    super.key,
    required this.node,
    this.onTap,
  });

  @override
  State<FileNodeItem> createState() => _FileNodeItemState();
}

class _FileNodeItemState extends State<FileNodeItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.node.isDirectory) {
      return _buildFolderNode(context);
    } else {
      return _buildFileNode(context);
    }
  }

  /// Построить узел папки
  Widget _buildFolderNode(BuildContext context) {
    final indent = widget.node.level * IDETheme.fileNodeIndent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: IDETheme.fileNodeHeight,
          padding: EdgeInsets.only(left: indent),
          color: _isHovered ? IDETheme.hoverColor : Colors.transparent,
          child: Row(
            children: [
              // Иконка раскрытия
              Icon(
                widget.node.isExpanded
                    ? Icons.arrow_drop_down
                    : Icons.arrow_right,
                size: 20,
                color: IDETheme.textSecondary,
              ),
              const SizedBox(width: 4),
              // Иконка папки
              Icon(
                widget.node.isExpanded ? Icons.folder_open : Icons.folder,
                size: IDETheme.folderIconSize,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 6),
              // Название папки
              Expanded(
                child: Text(
                  widget.node.name,
                  style: IDETheme.bodyMediumStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Построить узел файла
  Widget _buildFileNode(BuildContext context) {
    final indent = widget.node.level * IDETheme.fileNodeIndent;

    return Consumer3<FileExplorerService, ProjectService, FileModificationService>(
      builder: (context, explorerService, projectService, modificationService, child) {
        // Получаем файл из проекта
        final file = projectService.getFileByPath(widget.node.path);
        final isSelected = file != null && explorerService.selectedFile?.id == file.id;
        final isModified = file != null && modificationService.hasUnsavedChangesForFile(file);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              height: IDETheme.fileNodeHeight,
              padding: EdgeInsets.only(left: indent + 24), // Отступ как будто есть иконка раскрытия
              color: isSelected
                  ? IDETheme.selectedColor
                  : (_isHovered ? IDETheme.hoverColor : Colors.transparent),
              child: Row(
                children: [
                  // Иконка файла
                  Icon(
                    _getFileIcon(file?.type),
                    size: IDETheme.fileIconSize,
                    color: _getFileColor(file?.type),
                  ),
                  const SizedBox(width: 6),
                  // Название файла
                  Expanded(
                    child: Text(
                      widget.node.name,
                      style: IDETheme.bodyMediumStyle.copyWith(
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Индикатор изменений
                  if (isModified) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: IDETheme.modifiedColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Получить иконку для типа файла
  IconData _getFileIcon(FileType? type) {
    if (type == null) return Icons.insert_drive_file;

    switch (type) {
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

  /// Получить цвет для типа файла
  Color _getFileColor(FileType? type) {
    if (type == null) return Colors.grey;

    switch (type) {
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
