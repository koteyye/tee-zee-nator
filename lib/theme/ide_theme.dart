import 'package:flutter/material.dart';

/// Константы дизайн-системы для IDE-подобного интерфейса
/// Базируется на спецификации из design-system.md
class IDETheme {
  // ============================================================================
  // ЦВЕТА
  // ============================================================================

  // ---------- Нейтральные оттенки (серая шкала) ----------

  /// Основной фон
  static const backgroundColor = Color(0xFFFFFFFF);

  /// Фон поверхностей
  static const surfaceColor = Color(0xFFF5F5F5);

  /// Фон проводника файлов
  static const explorerBackground = Color(0xFFF8F8F8);

  /// Фон панели вкладок
  static const tabBarBackground = Color(0xFFEEEEEE);

  /// Фон редактора/просмотрщика
  static const editorBackground = Color(0xFFFFFFFF);

  /// Цвет границ
  static const borderColor = Color(0xFFE0E0E0);

  /// Цвет разделителей
  static const dividerColor = Color(0xFFBDBDBD);

  /// Основной текст
  static const textPrimary = Color(0xFF212121);

  /// Вторичный текст
  static const textSecondary = Color(0xFF757575);

  /// Неактивный текст
  static const textDisabled = Color(0xFFBDBDBD);

  // ---------- Акцентные цвета ----------

  /// Основной акцентный цвет
  static const primaryColor = Color(0xFF1976D2);

  /// Светлый вариант основного цвета
  static const primaryColorLight = Color(0xFF42A5F5);

  /// Темный вариант основного цвета
  static const primaryColorDark = Color(0xFF1565C0);

  /// Вторичный акцентный цвет
  static const secondaryColor = Color(0xFF424242);

  // ---------- Семантические цвета ----------

  /// Файл изменен (оранжевый)
  static const modifiedColor = Color(0xFFFF9800);

  /// Файл сохранен (зеленый)
  static const savedColor = Color(0xFF4CAF50);

  /// Ожидает подтверждения (желтый)
  static const pendingColor = Color(0xFFFFC107);

  /// Ошибка (красный)
  static const errorColor = Color(0xFFF44336);

  // ---------- Diff colors ----------

  /// Добавлено (светло-зеленый фон)
  static const diffAddition = Color(0xFFE8F5E9);

  /// Граница добавления
  static const diffAdditionBorder = Color(0xFF66BB6A);

  /// Удалено (светло-красный фон)
  static const diffDeletion = Color(0xFFFFEBEE);

  /// Граница удаления
  static const diffDeletionBorder = Color(0xFFEF5350);

  /// Фон добавленной строки в diff
  static const diffAddedBackground = Color(0xFFE8F5E9);

  /// Граница добавленной строки в diff
  static const diffAddedBorder = Color(0xFF66BB6A);

  /// Фон удаленной строки в diff
  static const diffRemovedBackground = Color(0xFFFFEBEE);

  /// Граница удаленной строки в diff
  static const diffRemovedBorder = Color(0xFFEF5350);

  // ---------- Интеграции (Integration indicators) ----------

  /// Confluence активно (зеленый)
  static const confluenceActive = Color(0xFF4CAF50);

  /// Confluence неактивно (серый)
  static const confluenceInactive = Color(0xFF9E9E9E);

  /// Фон активного Confluence (светло-зеленый)
  static const confluenceBackground = Color(0xFFE8F5E9);

  /// Граница активного Confluence
  static const confluenceBorder = Color(0xFF81C784);

  /// Музикация активно (фиолетовый)
  static const musicActive = Color(0xFF9C27B0);

  /// Музикация неактивно (серый)
  static const musicInactive = Color(0xFF9E9E9E);

  /// Фон активной Музикации (светло-фиолетовый)
  static const musicBackground = Color(0xFFF3E5F5);

  /// Граница активной Музикации
  static const musicBorder = Color(0xFFBA68C8);

  /// Фон неактивной интеграции
  static const integrationInactiveBackground = Color(0xFFF5F5F5);

  /// Граница неактивной интеграции
  static const integrationInactiveBorder = Color(0xFFBDBDBD);

  // ---------- Состояния интерактивных элементов ----------

  /// Hover состояние
  static const hoverColor = Color(0xFFF5F5F5);

  /// Hover темный
  static const hoverColorDark = Color(0xFFEEEEEE);

  /// Выбранный файл
  static const selectedColor = Color(0xFFE3F2FD);

  /// Активная вкладка
  static const activeTabColor = Color(0xFFFFFFFF);

  /// Неактивная вкладка
  static const inactiveTabColor = Color(0xFFE0E0E0);

  /// Focus цвет
  static const focusColor = Color(0xFF1976D2);

  // ============================================================================
  // ТИПОГРАФИКА
  // ============================================================================

  /// Заголовок (20px, 600)
  static const headlineStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.15,
  );

  /// Заголовок раздела (16px, 600)
  static const titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.15,
  );

  /// Подзаголовок (14px, 500)
  static const subtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.1,
  );

  /// Основной текст большой (14px, 400)
  static const bodyLargeStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.25,
  );

  /// Основной текст средний (13px, 400)
  static const bodyMediumStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.25,
  );

  /// Основной текст малый (12px, 400)
  static const bodySmallStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.4,
  );

  /// Текст кнопки (14px, 500)
  static const buttonTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  /// Метка (12px, 500, uppercase)
  static const labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  /// Моноширинный шрифт (для кода, 13px, 400)
  static const codeStyle = TextStyle(
    fontFamily: 'Roboto Mono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0,
  );

  // ============================================================================
  // РАЗМЕРЫ И ОТСТУПЫ
  // ============================================================================

  // ---------- Система отступов (8px grid) ----------

  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // ---------- Высоты ----------

  /// Высота панели инструментов
  static const double toolbarHeight = 48.0;

  /// Высота панели вкладок
  static const double tabBarHeight = 36.0;

  /// Высота строки состояния
  static const double statusBarHeight = 24.0;

  /// Высота футера
  static const double footerHeight = 40.0;

  // ---------- Ширины ----------

  /// Начальная ширина проводника файлов
  static const double fileExplorerWidth = 280.0;

  /// Минимальная ширина проводника
  static const double fileExplorerMinWidth = 200.0;

  /// Максимальная ширина проводника
  static const double fileExplorerMaxWidth = 400.0;

  /// Ширина плавающей панели AI чата
  static const double aiChatPanelWidth = 380.0;

  /// Минимальная ширина AI чата
  static const double aiChatPanelMinWidth = 320.0;

  /// Максимальная ширина AI чата
  static const double aiChatPanelMaxWidth = 500.0;

  /// Высота плавающей панели AI чата
  static const double aiChatPanelHeight = 600.0;

  // ---------- Элементы дерева файлов ----------

  /// Высота элемента файла
  static const double fileNodeHeight = 32.0;

  /// Отступ для вложенности
  static const double fileNodeIndent = 20.0;

  /// Размер иконки файла
  static const double fileIconSize = 16.0;

  /// Размер иконки папки
  static const double folderIconSize = 16.0;

  // ---------- Вкладки ----------

  /// Высота вкладки
  static const double tabHeight = 36.0;

  /// Минимальная ширина вкладки
  static const double tabMinWidth = 100.0;

  /// Максимальная ширина вкладки
  static const double tabMaxWidth = 200.0;

  /// Размер кнопки закрытия вкладки
  static const double tabCloseButtonSize = 16.0;

  // ---------- Кнопки ----------

  /// Высота кнопки
  static const double buttonHeight = 36.0;

  /// Минимальная ширина кнопки
  static const double buttonMinWidth = 80.0;

  /// Горизонтальный padding кнопки
  static const double buttonPaddingHorizontal = 16.0;

  /// Вертикальный padding кнопки
  static const double buttonPaddingVertical = 8.0;

  /// Размер иконки-кнопки
  static const double iconButtonSize = 36.0;

  /// Размер плавающей кнопки
  static const double floatingButtonSize = 56.0;

  // ============================================================================
  // АНИМАЦИИ
  // ============================================================================

  /// Короткая анимация (hover, ripple)
  static const shortDuration = Duration(milliseconds: 150);

  /// Средняя анимация (переходы, появление)
  static const mediumDuration = Duration(milliseconds: 250);

  /// Длинная анимация (сложные анимации)
  static const longDuration = Duration(milliseconds: 350);

  /// Стандартная кривая
  static const Curve easeInOut = Curves.easeInOut;

  /// Кривая появления
  static const Curve easeOut = Curves.easeOut;

  /// Кривая исчезновения
  static const Curve easeIn = Curves.easeIn;
}
