import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/ide_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/project_file.dart';
import '../services/project_service.dart';
import '../services/file_explorer_service.dart';
import '../services/file_modification_service.dart';
import '../utils/error_handler.dart';
import '../widgets/ide/toolbar/ide_toolbar.dart';
import '../widgets/ide/status_bar/ide_status_bar.dart';
import '../widgets/ide/file_explorer/file_explorer.dart';
import '../widgets/ide/editor/tab_bar_widget.dart';
import '../widgets/ide/editor/content_viewer.dart';
import '../widgets/ide/ai_chat/chat_panel.dart';
import '../widgets/main_screen/confluence_publish_modal.dart';
import 'ide_intents.dart';

/// Главный экран IDE
/// 
/// Трехпанельная компоновка:
/// - Левая панель: проводник файлов
/// - Центральная панель: вкладки + содержимое файла
/// - Плавающая панель: AI чат (справа снизу)
/// - Верхняя панель: toolbar
/// - Нижняя панель: status bar
class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  // Список открытых файлов
  final List<ProjectFile> _openFiles = [];
  
  // Активный файл (отображается в данный момент)
  ProjectFile? _activeFile;

  // Видимость AI чата
  bool _isChatVisible = false;

  // Максимальное количество открытых вкладок
  static const int _maxOpenTabs = 10;

  @override
  void initState() {
    super.initState();
    
    // Слушаем изменения в FileExplorerService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fileExplorerService = context.read<FileExplorerService>();
      fileExplorerService.addListener(_onFileExplorerChanged);
    });
  }

  @override
  void dispose() {
    final fileExplorerService = context.read<FileExplorerService>();
    fileExplorerService.removeListener(_onFileExplorerChanged);
    super.dispose();
  }

  /// Обработчик изменений в FileExplorerService
  void _onFileExplorerChanged() {
    final fileExplorerService = context.read<FileExplorerService>();
    final selectedFile = fileExplorerService.selectedFile;

    if (selectedFile != null && selectedFile != _activeFile) {
      _openFile(selectedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                // Основной контент
                Column(
                  children: [
                    // Toolbar
                    _buildToolbar(),

                    // Основная область (проводник + редактор)
                    Expanded(
                      child: Row(
                        children: [
                          // Проводник файлов
                          const FileExplorer(),

                          // Центральная панель (вкладки + содержимое)
                          Expanded(
                            child: _buildEditorArea(),
                          ),
                        ],
                      ),
                    ),

                    // Status bar
                    _buildStatusBar(),
                  ],
                ),

                // AI Chat Panel (плавающий overlay)
                if (_isChatVisible)
                  Positioned(
                    right: 16,
                    bottom: 80,
                    child: ChatPanel(
                      isVisible: _isChatVisible,
                      onClose: _toggleChat,
                    ),
                  ),
              ],
            ),

            // Плавающая кнопка AI-чата
            floatingActionButton: _buildChatButton(),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Consumer<FileModificationService>(
      builder: (context, modService, child) {
        return IDEToolbar(
          onOpenFolder: _handleOpenFolder,
          onSave: _handleSave,
          onPublishToConfluence: _handlePublishToConfluence,
          currentFileContent: _activeFile?.cachedContent,
          hasModifiedFiles: modService.modifiedFiles.isNotEmpty,
          hasOpenFile: _activeFile != null,
        );
      },
    );
  }

  Widget _buildEditorArea() {
    return Container(
      color: IDETheme.editorBackground,
      child: Column(
        children: [
          // Панель вкладок
          if (_openFiles.isNotEmpty)
            TabBarWidget(
              openFiles: _openFiles,
              activeFile: _activeFile,
              onTabSelect: _switchToFile,
              onTabClose: _closeFile,
            ),

          // Содержимое файла
          Expanded(
            child: ContentViewer(
              file: _activeFile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return IDEStatusBar(
      currentFile: _activeFile,
      lineCount: _calculateLineCount(_activeFile),
    );
  }

  Widget _buildChatButton() {
    final l10n = AppLocalizations.of(context)!;
    return FloatingActionButton(
      onPressed: _toggleChat,
      backgroundColor: IDETheme.primaryColor,
      tooltip: l10n.openAIChat,
      elevation: 4,
      child: const Icon(
        Icons.chat,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  // ============================================================================
  // Keyboard Shortcuts
  // ============================================================================

  /// Построить карту клавиатурных сокращений
  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      // Ctrl+O - Открыть проект
      const SingleActivator(LogicalKeyboardKey.keyO, control: true):
          const OpenProjectIntent(),

      // Ctrl+S - Сохранить файл
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          const SaveFileIntent(),

      // Ctrl+W - Закрыть вкладку
      const SingleActivator(LogicalKeyboardKey.keyW, control: true):
          const CloseTabIntent(),

      // Ctrl+Tab - Следующая вкладка
      const SingleActivator(LogicalKeyboardKey.tab, control: true):
          const NextTabIntent(),

      // Ctrl+Shift+Tab - Предыдущая вкладка
      const SingleActivator(
        LogicalKeyboardKey.tab,
        control: true,
        shift: true,
      ): const PreviousTabIntent(),

      // Ctrl+Shift+A - Открыть/закрыть AI чат
      const SingleActivator(
        LogicalKeyboardKey.keyA,
        control: true,
        shift: true,
      ): const ToggleAIChatIntent(),

      // Ctrl+Z - Отменить изменения (revert)
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
          const RevertChangesIntent(),

      // F5 - Обновить проект
      const SingleActivator(LogicalKeyboardKey.f5):
          const RefreshProjectIntent(),

      // Ctrl+P - Быстрый поиск файлов
      const SingleActivator(LogicalKeyboardKey.keyP, control: true):
          const QuickSearchIntent(),

      // Ctrl+F - Поиск в файле
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          const FindInFileIntent(),
    };
  }

  /// Построить карту действий для интентов
  Map<Type, Action<Intent>> _buildActions() {
    return {
      OpenProjectIntent: CallbackAction<OpenProjectIntent>(
        onInvoke: (_) {
          _handleOpenFolder();
          return null;
        },
      ),
      SaveFileIntent: CallbackAction<SaveFileIntent>(
        onInvoke: (_) {
          if (_activeFile != null) {
            _handleSave();
          }
          return null;
        },
      ),
      CloseTabIntent: CallbackAction<CloseTabIntent>(
        onInvoke: (_) {
          if (_activeFile != null) {
            _closeFile(_activeFile!);
          }
          return null;
        },
      ),
      NextTabIntent: CallbackAction<NextTabIntent>(
        onInvoke: (_) {
          _switchToNextTab();
          return null;
        },
      ),
      PreviousTabIntent: CallbackAction<PreviousTabIntent>(
        onInvoke: (_) {
          _switchToPreviousTab();
          return null;
        },
      ),
      ToggleAIChatIntent: CallbackAction<ToggleAIChatIntent>(
        onInvoke: (_) {
          _toggleChat();
          return null;
        },
      ),
      RevertChangesIntent: CallbackAction<RevertChangesIntent>(
        onInvoke: (_) {
          if (_activeFile != null && _activeFile!.isModified) {
            _handleRevertChanges();
          }
          return null;
        },
      ),
      RefreshProjectIntent: CallbackAction<RefreshProjectIntent>(
        onInvoke: (_) {
          _handleRefreshProject();
          return null;
        },
      ),
      QuickSearchIntent: CallbackAction<QuickSearchIntent>(
        onInvoke: (_) {
          _handleQuickSearch();
          return null;
        },
      ),
      FindInFileIntent: CallbackAction<FindInFileIntent>(
        onInvoke: (_) {
          _handleFindInFile();
          return null;
        },
      ),
    };
  }

  // ============================================================================
  // Обработчики действий
  // ============================================================================

  /// Открыть папку проекта
  Future<void> _handleOpenFolder() async {
    try {
      // Читаем все сервисы ДО async операций
      final projectService = context.read<ProjectService>();
      final fileExplorerService = context.read<FileExplorerService>();

      final project = await projectService.openProjectDialog();

      if (project != null) {
        // Построить дерево файлов
        await fileExplorerService.buildFileTree(project);

        if (mounted) {
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
      if (mounted) {
        ErrorHandler.showError(
          context,
          e,
          onRetry: _handleOpenFolder,
        );
      }
    }
  }

  /// Сохранить текущий файл
  Future<void> _handleSave() async {
    if (_activeFile == null) return;

    try {
      // Читаем все сервисы ДО async операций
      final projectService = context.read<ProjectService>();
      final modService = context.read<FileModificationService>();

      await modService.saveToFile(_activeFile!);
      await projectService.saveFile(_activeFile!);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.fileSavedSuccess),
            backgroundColor: IDETheme.savedColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      setState(() {
        // Обновить UI
      });
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(
          context,
          e,
          onRetry: _handleSave,
        );
      }
    }
  }

  /// Опубликовать в Confluence
  Future<void> _handlePublishToConfluence() async {
    if (_activeFile == null) return;

    // Загрузить содержимое файла
    String? content = _activeFile!.cachedContent;
    
    if (content == null || content.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fileEmptyOrNotLoaded),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Показать модальное окно публикации
    await showDialog(
      context: context,
      builder: (context) => ConfluencePublishModal(
        content: content,
        suggestedTitle: _activeFile!.name.replaceAll(RegExp(r'\.(md|html|confluence)$'), ''),
      ),
    );
  }

  /// Открыть/закрыть AI чат
  void _toggleChat() {
    setState(() {
      _isChatVisible = !_isChatVisible;
    });
  }

  // ============================================================================
  // Управление вкладками
  // ============================================================================

  /// Открыть файл
  void _openFile(ProjectFile file) {
    // Проверить, не открыт ли уже
    final existingIndex = _openFiles.indexWhere((f) => f.path == file.path);

    if (existingIndex != -1) {
      // Файл уже открыт, просто переключиться
      _switchToFile(_openFiles[existingIndex]);
      return;
    }

    // Проверить лимит вкладок
    if (_openFiles.length >= _maxOpenTabs) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.maxOpenTabsReached(_maxOpenTabs)),
          backgroundColor: IDETheme.errorColor,
        ),
      );
      return;
    }

    // Добавить в список открытых
    setState(() {
      _openFiles.add(file);
      _activeFile = file;
    });
  }

  /// Переключиться на файл
  void _switchToFile(ProjectFile file) {
    setState(() {
      _activeFile = file;
    });

    // Обновить выбранный файл в FileExplorerService
    final fileExplorerService = context.read<FileExplorerService>();
    if (fileExplorerService.selectedFile?.path != file.path) {
      fileExplorerService.selectFile(file);
    }
  }

  /// Закрыть файл
  Future<void> _closeFile(ProjectFile file) async {
    // Проверить на несохраненные изменения
    if (file.isModified) {
      final shouldClose = await _showUnsavedChangesDialog(file);
      if (shouldClose != true) return;
    }

    setState(() {
      _openFiles.removeWhere((f) => f.path == file.path);

      // Если закрыли активный файл, переключиться на другой
      if (_activeFile?.path == file.path) {
        _activeFile = _openFiles.isNotEmpty ? _openFiles.last : null;
      }
    });
  }

  /// Показать диалог несохраненных изменений
  Future<bool?> _showUnsavedChangesDialog(ProjectFile file) async {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<bool>(
      context: context,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: Text(l10n.unsavedChangesTitle),
          content: Text(
            l10n.unsavedChangesMessage(file.name),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                // Сохранить и закрыть
                await _handleSave();
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(l10n.save),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.dontSave,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Обработчики клавиатурных сокращений
  // ============================================================================

  /// Переключиться на следующую вкладку
  void _switchToNextTab() {
    if (_openFiles.isEmpty || _activeFile == null) return;

    final currentIndex = _openFiles.indexOf(_activeFile!);
    final nextIndex = (currentIndex + 1) % _openFiles.length;

    _switchToFile(_openFiles[nextIndex]);
  }

  /// Переключиться на предыдущую вкладку
  void _switchToPreviousTab() {
    if (_openFiles.isEmpty || _activeFile == null) return;

    final currentIndex = _openFiles.indexOf(_activeFile!);
    final previousIndex = 
        currentIndex == 0 ? _openFiles.length - 1 : currentIndex - 1;

    _switchToFile(_openFiles[previousIndex]);
  }

  /// Отменить изменения в текущем файле
  Future<void> _handleRevertChanges() async {
    if (_activeFile == null || !_activeFile!.isModified) return;

    try {
      final modService = context.read<FileModificationService>();
      modService.revertChanges(_activeFile!);

      setState(() {
        // Обновить UI
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.changesCancelled),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRevertingChanges(e.toString())),
            backgroundColor: IDETheme.errorColor,
          ),
        );
      }
    }
  }

  /// Обновить проект
  Future<void> _handleRefreshProject() async {
    try {
      final projectService = context.read<ProjectService>();
      final currentProject = projectService.currentProject;

      if (currentProject == null) return;

      // Обновить проект (перечитать файлы)
      await projectService.refreshProject();

      // Перестроить дерево файлов
      final fileExplorerService = context.read<FileExplorerService>();
      await fileExplorerService.buildFileTree(currentProject);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.projectRefreshed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRefreshingProject(e.toString())),
            backgroundColor: IDETheme.errorColor,
          ),
        );
      }
    }
  }

  /// Быстрый поиск файлов
  void _handleQuickSearch() {
    // TODO: Реализовать быстрый поиск (Ctrl+P)
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.quickSearchInDevelopment),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Поиск в текущем файле
  void _handleFindInFile() {
    // TODO: Реализовать поиск в файле (Ctrl+F)
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.findInFileInDevelopment),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================================
  // Вспомогательные методы
  // ============================================================================

  /// Создать адаптивный SnackBar для малых экранов
  SnackBar _createAdaptiveSnackBar(
    String message, {
    Color? backgroundColor,
    int maxLines = 2,
  }) {
    return SnackBar(
      content: Text(
        message,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  /// Подсчитать количество строк в файле
  int? _calculateLineCount(ProjectFile? file) {
    if (file?.cachedContent == null) return null;
    return file!.cachedContent!.split('\n').length;
  }
}
