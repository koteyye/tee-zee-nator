import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/file_explorer_service.dart';
import '../../../services/project_service.dart';
import 'file_node_item.dart';

/// Виджет дерева файлов
/// Отображает иерархическую структуру файлов проекта
class FileTreeView extends StatelessWidget {
  const FileTreeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FileExplorerService, ProjectService>(
      builder: (context, explorerService, projectService, child) {
        final flattenedTree = explorerService.getFlattenedTree();

        // Если дерево пустое, показываем placeholder
        if (flattenedTree.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          itemCount: flattenedTree.length,
          itemBuilder: (context, index) {
            final node = flattenedTree[index];
            return FileNodeItem(
              node: node,
              onTap: () => _handleNodeTap(
                context,
                node,
                explorerService,
                projectService,
              ),
            );
          },
        );
      },
    );
  }

  /// Обработчик клика по узлу
  void _handleNodeTap(
    BuildContext context,
    dynamic node,
    FileExplorerService explorerService,
    ProjectService projectService,
  ) {
    if (node.isDirectory) {
      // Раскрываем/сворачиваем папку
      explorerService.toggleNode(node);
    } else {
      // Выбираем файл
      final file = projectService.getFileByPath(node.path);
      if (file != null) {
        explorerService.selectFile(file);
      }
    }
  }

  /// Placeholder для пустого состояния
  Widget _buildEmptyState(BuildContext context) {
    return Consumer<ProjectService>(
      builder: (context, projectService, child) {
        final hasProject = projectService.currentProject != null;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasProject ? Icons.description_outlined : Icons.folder_open,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  hasProject
                    ? 'Проект пуст'
                    : 'Нет открытого проекта',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasProject
                    ? 'Создайте новые файлы требований\nчерез AI или добавьте существующие'
                    : 'Откройте папку для начала работы',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
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
}
