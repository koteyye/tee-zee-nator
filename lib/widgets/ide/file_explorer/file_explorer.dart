import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/project_service.dart';
import '../../../services/file_explorer_service.dart';
import '../../../theme/ide_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/error_handler.dart';
import 'file_tree_view.dart';

/// Главный контейнер проводника файлов
/// Включает header с названием проекта и кнопкой открытия папки
class FileExplorer extends StatelessWidget {
  const FileExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final adaptiveWidth = _getAdaptiveWidth(screenWidth);
    
    return Container(
      width: adaptiveWidth,
      color: IDETheme.explorerBackground,
      child: Column(
        children: [
          _buildHeader(context),
          Divider(
            height: 1,
            thickness: 1,
            color: IDETheme.borderColor,
          ),
          const Expanded(child: FileTreeView()),
        ],
      ),
    );
  }

  /// Получить адаптивную ширину в зависимости от размера экрана
  double _getAdaptiveWidth(double screenWidth) {
    if (screenWidth < 1280) {
      return 240; // Уменьшенная ширина на малых экранах
    } else if (screenWidth < 1600) {
      return IDETheme.fileExplorerWidth; // 280px на средних
    } else {
      return 320; // 320px на больших экранах
    }
  }

  /// Построить header проводника
  Widget _buildHeader(BuildContext context) {
    return Consumer<ProjectService>(
      builder: (context, projectService, child) {
        final project = projectService.currentProject;
        final hasProject = project != null;

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: IDETheme.surfaceColor,
            border: Border(
              bottom: BorderSide(color: IDETheme.borderColor),
            ),
          ),
          child: Row(
            children: [
              // Иконка проекта
              Icon(
                hasProject ? Icons.folder : Icons.folder_outlined,
                size: 20,
                color: hasProject ? Colors.amber[700] : IDETheme.textSecondary,
              ),
              const SizedBox(width: 8),
              // Название проекта
              Expanded(
                child: Text(
                  project?.name ?? 'Проводник',
                  style: IDETheme.subtitleStyle.copyWith(
                    color: IDETheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Кнопка открытия папки
              IconButton(
                icon: const Icon(Icons.folder_open, size: 18),
                tooltip: 'Открыть папку',
                onPressed: () => _handleOpenFolder(context, projectService),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 18,
              ),
              // Кнопка обновления (если проект открыт)
              if (hasProject) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Обновить',
                  onPressed: () => _handleRefresh(context, projectService),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Обработчик открытия папки
  Future<void> _handleOpenFolder(
    BuildContext context,
    ProjectService projectService,
  ) async {
    try {
      final project = await projectService.openProjectDialog();
      if (project != null && context.mounted) {
        // Строим дерево файлов
        final explorerService = context.read<FileExplorerService>();
        await explorerService.buildFileTree(project);

        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.projectOpened(project.name)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e, onRetry: () => _handleOpenFolder(context, projectService));
      }
    }
  }

  /// Обработчик обновления проекта
  Future<void> _handleRefresh(
    BuildContext context,
    ProjectService projectService,
  ) async {
    try {
      await projectService.refreshProject();

      // Перестраиваем дерево
      final project = projectService.currentProject;
      if (project != null && context.mounted) {
        final explorerService = context.read<FileExplorerService>();
        await explorerService.buildFileTree(project);
      }

      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.projectRefreshed),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showError(context, e, onRetry: () => _handleRefresh(context, projectService));
      }
    }
  }
}
