import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/ide_theme.dart';

/// Виджет для отображения HTML/Confluence контента
class HtmlViewer extends StatelessWidget {
  final String content;

  const HtmlViewer({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IDETheme.editorBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Html(
          data: content,
          style: _buildHtmlStyles(),
          onLinkTap: (url, attributes, element) => _handleLinkTap(url),
        ),
      ),
    );
  }

  /// Создать стили для HTML
  Map<String, Style> _buildHtmlStyles() {
    return {
      // Заголовки
      'h1': Style(
        fontSize: FontSize(32),
        fontWeight: FontWeight.bold,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 16, bottom: 8),
      ),
      'h2': Style(
        fontSize: FontSize(24),
        fontWeight: FontWeight.bold,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 16, bottom: 8),
      ),
      'h3': Style(
        fontSize: FontSize(20),
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 12, bottom: 6),
      ),
      'h4': Style(
        fontSize: FontSize(18),
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 12, bottom: 6),
      ),
      'h5': Style(
        fontSize: FontSize(16),
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 8, bottom: 4),
      ),
      'h6': Style(
        fontSize: FontSize(14),
        fontWeight: FontWeight.w600,
        color: IDETheme.textPrimary,
        margin: Margins.only(top: 8, bottom: 4),
      ),

      // Текст
      'p': Style(
        fontSize: FontSize(16),
        color: IDETheme.textPrimary,
        lineHeight: LineHeight.number(1.6),
        margin: Margins.only(bottom: 12),
      ),

      // Код
      'code': Style(
        fontFamily: 'monospace',
        fontSize: FontSize(14),
        backgroundColor: IDETheme.surfaceColor,
        color: IDETheme.primaryColor,
        padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
      ),
      'pre': Style(
        fontFamily: 'monospace',
        fontSize: FontSize(14),
        backgroundColor: IDETheme.surfaceColor,
        color: IDETheme.textPrimary,
        padding: HtmlPaddings.all(12),
        margin: Margins.only(bottom: 12),
        border: Border.all(color: IDETheme.borderColor),
      ),

      // Ссылки
      'a': Style(
        color: IDETheme.primaryColor,
        textDecoration: TextDecoration.underline,
      ),

      // Списки
      'ul': Style(
        margin: Margins.only(bottom: 12),
        padding: HtmlPaddings.only(left: 20),
      ),
      'ol': Style(
        margin: Margins.only(bottom: 12),
        padding: HtmlPaddings.only(left: 20),
      ),
      'li': Style(
        margin: Margins.only(bottom: 4),
        color: IDETheme.textPrimary,
      ),

      // Цитаты
      'blockquote': Style(
        backgroundColor: IDETheme.surfaceColor,
        color: IDETheme.textSecondary,
        fontStyle: FontStyle.italic,
        padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 8),
        margin: Margins.only(bottom: 12),
        border: Border(
          left: BorderSide(
            color: IDETheme.primaryColor,
            width: 4,
          ),
        ),
      ),

      // Таблицы
      'table': Style(
        border: Border.all(color: IDETheme.borderColor),
        margin: Margins.only(bottom: 12),
      ),
      'th': Style(
        fontWeight: FontWeight.bold,
        backgroundColor: IDETheme.surfaceColor,
        padding: HtmlPaddings.all(8),
        border: Border.all(color: IDETheme.borderColor),
        color: IDETheme.textPrimary,
      ),
      'td': Style(
        padding: HtmlPaddings.all(8),
        border: Border.all(color: IDETheme.borderColor),
        color: IDETheme.textPrimary,
      ),

      // Горизонтальная линия
      'hr': Style(
        border: Border(
          top: BorderSide(color: IDETheme.borderColor, width: 1),
        ),
        margin: Margins.symmetric(vertical: 16),
      ),

      // Confluence специфичные элементы
      'ac:structured-macro': Style(
        backgroundColor: IDETheme.surfaceColor,
        padding: HtmlPaddings.all(12),
        margin: Margins.only(bottom: 12),
        border: Border.all(color: IDETheme.borderColor),
      ),

      // Общий стиль для body
      'body': Style(
        fontSize: FontSize(16),
        color: IDETheme.textPrimary,
      ),
    };
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
      debugPrint('[HtmlViewer] Error launching URL: $e');
    }
  }
}
