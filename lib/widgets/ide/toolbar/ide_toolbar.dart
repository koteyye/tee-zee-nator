import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/ide_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/config_service.dart';
import '../../../services/app_info_service.dart';
import '../../../screens/setup_screen.dart';
import '../../../screens/template_management_screen.dart';
import '../../main_screen/integration_indicators.dart';
import '../../main_screen/music_control_buttons.dart';

/// Панель инструментов IDE
/// 
/// Содержит основные действия:
/// - Открыть папку
/// - Сохранить файл
/// - Опубликовать в Confluence (если активно)
/// - Музицировать (если активно и файл открыт)
/// - Индикаторы интеграций
class IDEToolbar extends StatelessWidget {
  final VoidCallback? onOpenFolder;
  final VoidCallback? onSave;
  final VoidCallback? onPublishToConfluence;
  final String? currentFileContent;
  final bool hasModifiedFiles;
  final bool hasOpenFile;

  const IDEToolbar({
    super.key,
    this.onOpenFolder,
    this.onSave,
    this.onPublishToConfluence,
    this.currentFileContent,
    this.hasModifiedFiles = false,
    this.hasOpenFile = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: IDETheme.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: IDETheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: IDETheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          // Меню
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: l10n.menu,
            onSelected: (value) => _handleMenuSelection(context, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.settings),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'templates',
                child: Row(
                  children: [
                    const Icon(Icons.description, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.templates),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.about),
                  ],
                ),
              ),
            ],
          ),
          const VerticalDivider(),
          const SizedBox(width: 8),

          // Открыть папку
          _buildOpenFolderButton(context, l10n),
          const SizedBox(width: 8),

          // Сохранить
          _buildSaveButton(context, l10n),
          const SizedBox(width: 8),

          // Опубликовать в Confluence
          _buildPublishButton(context, l10n),
          const SizedBox(width: 8),

          // Кнопка Музицировать
          _buildMusicButton(context),

          const Spacer(),

          // Индикаторы интеграций
          const IntegrationIndicators(),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildOpenFolderButton(BuildContext context, AppLocalizations l10n) {
    return TextButton.icon(
      icon: const Icon(Icons.folder_open, size: 18),
      label: Text(l10n.openFolder),
      onPressed: onOpenFolder,
      style: TextButton.styleFrom(
        foregroundColor: IDETheme.textPrimary,
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, AppLocalizations l10n) {
    return TextButton.icon(
      icon: const Icon(Icons.save, size: 18),
      label: Text(l10n.save),
      onPressed: hasModifiedFiles ? onSave : null,
      style: TextButton.styleFrom(
        foregroundColor: IDETheme.textPrimary,
      ),
    );
  }

  Widget _buildPublishButton(BuildContext context, AppLocalizations l10n) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final confluenceConfig = configService.getConfluenceConfig();
        final isConfluenceActive =
            (confluenceConfig?.enabled ?? false) &&
            (confluenceConfig?.isValid ?? false);

        if (!isConfluenceActive || !hasOpenFile) {
          return const SizedBox.shrink();
        }

        return TextButton.icon(
          icon: const Icon(Icons.publish, size: 18),
          label: Text(l10n.publishToConfluence),
          onPressed: onPublishToConfluence,
          style: TextButton.styleFrom(
            foregroundColor: IDETheme.textPrimary,
          ),
        );
      },
    );
  }

  Widget _buildMusicButton(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final musicConfig = configService.config?.specMusicConfig;
        final isMusicActive =
            (musicConfig?.enabled ?? false) &&
            (musicConfig?.isValid ?? false);

        if (!isMusicActive || !hasOpenFile || currentFileContent == null) {
          return const SizedBox.shrink();
        }

        return MusicControlButtons(
          requirements: currentFileContent!,
          isGenerationActive: false,
        );
      },
    );
  }

  /// Обработка выбора пункта меню
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'settings':
        _openSettings(context);
        break;
      case 'templates':
        _openTemplates(context);
        break;
      case 'about':
        _showAboutDialog(context);
        break;
    }
  }

  /// Открыть экран настроек
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SetupScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Открыть экран шаблонов
  void _openTemplates(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TemplateManagementScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Показать диалог "О программе"
  void _showAboutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appInfoService = context.read<AppInfoService>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l10n.aboutDialogTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aboutDialogCreator,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appVersion(appInfoService.version),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
