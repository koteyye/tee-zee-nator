import 'package:flutter/material.dart';
import '../../../models/project_file.dart';
import '../../../theme/ide_theme.dart';
import 'tab_item.dart';

/// Панель вкладок для открытых файлов
class TabBarWidget extends StatelessWidget {
  final List<ProjectFile> openFiles;
  final ProjectFile? activeFile;
  final Function(ProjectFile) onTabSelect;
  final Function(ProjectFile) onTabClose;

  const TabBarWidget({
    super.key,
    required this.openFiles,
    this.activeFile,
    required this.onTabSelect,
    required this.onTabClose,
  });

  @override
  Widget build(BuildContext context) {
    // Ограничение на максимальное количество вкладок
    const maxTabs = 10;
    final displayFiles = openFiles.take(maxTabs).toList();

    return Container(
      height: IDETheme.tabBarHeight,
      decoration: BoxDecoration(
        color: IDETheme.tabBarBackground,
        border: Border(
          bottom: BorderSide(color: IDETheme.borderColor),
        ),
      ),
      child: displayFiles.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: displayFiles.length,
              itemBuilder: (context, index) {
                final file = displayFiles[index];
                return TabItem(
                  file: file,
                  isActive: file.id == activeFile?.id,
                  onTap: () => onTabSelect(file),
                  onClose: () => onTabClose(file),
                );
              },
            ),
    );
  }

  /// Пустое состояние когда нет открытых вкладок
  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Нет открытых файлов',
        style: IDETheme.bodyMediumStyle.copyWith(
          color: IDETheme.textSecondary,
        ),
      ),
    );
  }
}
