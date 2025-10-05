import 'package:flutter/material.dart';

import '../../../theme/ide_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/project_file.dart';

/// Строка состояния IDE
/// 
/// Отображает информацию о текущем файле:
/// - Иконка типа файла
/// - Название файла
/// - Тип файла
/// - Количество строк (опционально)
/// - Индикатор изменений
class IDEStatusBar extends StatelessWidget {
  final ProjectFile? currentFile;
  final int? lineCount;

  const IDEStatusBar({
    super.key,
    this.currentFile,
    this.lineCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: IDETheme.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border(
          top: BorderSide(color: IDETheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          if (currentFile != null) ...[
            // Иконка файла
            Icon(
              _getFileIcon(currentFile!.type),
              size: 12,
              color: _getFileIconColor(currentFile!.type),
            ),
            const SizedBox(width: 4),

            // Название файла
            Text(
              currentFile!.name,
              style: IDETheme.bodySmallStyle,
            ),
            const SizedBox(width: 12),

            Text(
              '|',
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.dividerColor,
              ),
            ),
            const SizedBox(width: 12),

            // Тип файла
            Text(
              _getFileTypeLabel(currentFile!.type),
              style: IDETheme.bodySmallStyle,
            ),

            if (lineCount != null) ...[
              const SizedBox(width: 12),
              Text(
                '|',
                style: IDETheme.bodySmallStyle.copyWith(
                  color: IDETheme.dividerColor,
                ),
              ),
              const SizedBox(width: 12),

              // Количество строк
              Text(
                '$lineCount ${_getLinesLabel(context, lineCount!)}',
                style: IDETheme.bodySmallStyle,
              ),
            ],
          ] else ...[
            Text(
              '-',
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.textDisabled,
              ),
            ),
          ],

          const Spacer(),

          // Индикатор изменений
          if (currentFile?.isModified ?? false)
            _buildModifiedIndicator(l10n),
        ],
      ),
    );
  }

  Widget _buildModifiedIndicator(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: IDETheme.modifiedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        l10n.fileModified,
        style: IDETheme.bodySmallStyle.copyWith(
          color: IDETheme.modifiedColor,
        ),
      ),
    );
  }

  IconData _getFileIcon(FileType type) {
    switch (type) {
      case FileType.markdown:
        return Icons.description;
      case FileType.html:
      case FileType.confluence:
        return Icons.code;
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(FileType type) {
    switch (type) {
      case FileType.markdown:
        return IDETheme.primaryColor;
      case FileType.html:
      case FileType.confluence:
        return const Color(0xFFE65100); // Оранжевый для HTML
      case FileType.unknown:
        return IDETheme.textSecondary;
    }
  }

  String _getFileTypeLabel(FileType type) {
    switch (type) {
      case FileType.markdown:
        return 'Markdown';
      case FileType.html:
        return 'HTML';
      case FileType.confluence:
        return 'Confluence';
      case FileType.unknown:
        return 'Unknown';
    }
  }

  String _getLinesLabel(BuildContext context, int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'строка';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'строки';
    } else {
      return 'строк';
    }
  }
}
