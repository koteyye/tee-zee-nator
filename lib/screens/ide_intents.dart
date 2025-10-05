import 'package:flutter/widgets.dart';

/// Intent для открытия проекта
class OpenProjectIntent extends Intent {
  const OpenProjectIntent();
}

/// Intent для сохранения файла
class SaveFileIntent extends Intent {
  const SaveFileIntent();
}

/// Intent для закрытия вкладки
class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

/// Intent для переключения на следующую вкладку
class NextTabIntent extends Intent {
  const NextTabIntent();
}

/// Intent для переключения на предыдущую вкладку
class PreviousTabIntent extends Intent {
  const PreviousTabIntent();
}

/// Intent для открытия/закрытия AI чата
class ToggleAIChatIntent extends Intent {
  const ToggleAIChatIntent();
}

/// Intent для отмены изменений в файле
class RevertChangesIntent extends Intent {
  const RevertChangesIntent();
}

/// Intent для обновления проекта
class RefreshProjectIntent extends Intent {
  const RefreshProjectIntent();
}

/// Intent для быстрого поиска файлов
class QuickSearchIntent extends Intent {
  const QuickSearchIntent();
}

/// Intent для поиска в текущем файле
class FindInFileIntent extends Intent {
  const FindInFileIntent();
}
