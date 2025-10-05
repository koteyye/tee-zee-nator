import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/ide_theme.dart';

/// Виджет для отображения Markdown контента
class MarkdownViewer extends StatelessWidget {
  final String content;

  const MarkdownViewer({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IDETheme.editorBackground,
      child: Markdown(
        data: content,
        selectable: true,
        styleSheet: _buildMarkdownStyleSheet(),
        onTapLink: (text, href, title) => _handleLinkTap(href),
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  /// Создать стили для Markdown
  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      // Заголовки
      h1: IDETheme.headlineStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: IDETheme.textPrimary,
      ),
      h2: IDETheme.headlineStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: IDETheme.textPrimary,
      ),
      h3: IDETheme.headlineStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
      ),
      h4: IDETheme.headlineStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
      ),
      h5: IDETheme.headlineStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
      ),
      h6: IDETheme.headlineStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
      ),

      // Текст
      p: IDETheme.bodyLargeStyle.copyWith(
        color: IDETheme.textPrimary,
        height: 1.6,
      ),

      // Код
      code: IDETheme.codeStyle.copyWith(
        backgroundColor: IDETheme.surfaceColor,
        color: IDETheme.primaryColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: IDETheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: IDETheme.borderColor),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // Ссылки
      a: IDETheme.bodyLargeStyle.copyWith(
        color: IDETheme.primaryColor,
        decoration: TextDecoration.underline,
      ),

      // Списки
      listBullet: IDETheme.bodyLargeStyle.copyWith(
        color: IDETheme.textPrimary,
      ),

      // Цитаты
      blockquote: IDETheme.bodyLargeStyle.copyWith(
        color: IDETheme.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: IDETheme.surfaceColor,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(
            color: IDETheme.primaryColor,
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),

      // Таблицы
      tableHead: IDETheme.bodyMediumStyle.copyWith(
        fontWeight: FontWeight.bold,
        color: IDETheme.textPrimary,
      ),
      tableBody: IDETheme.bodyMediumStyle.copyWith(
        color: IDETheme.textPrimary,
      ),
      tableBorder: TableBorder.all(
        color: IDETheme.borderColor,
        width: 1,
      ),

      // Горизонтальная линия
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: IDETheme.borderColor,
            width: 1,
          ),
        ),
      ),
    );
  }

  /// Обработать клик по ссылке
  Future<void> _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;

    try {
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MarkdownViewer] Error launching URL: $e');
    }
  }
}
