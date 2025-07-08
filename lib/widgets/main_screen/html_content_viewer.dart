import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'confluence_html_transformer.dart';

class HtmlContentViewer extends StatelessWidget {
  final String htmlContent;

  const HtmlContentViewer({
    super.key,
    required this.htmlContent,
  });

  @override
  Widget build(BuildContext context) {
    // Преобразуем Confluence HTML в обычный HTML для рендера
    final transformedHtml = ConfluenceHtmlTransformer.transformForRender(htmlContent);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Html(
        data: transformedHtml,
        style: {
          "h1": Style(
            fontSize: FontSize(24),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            margin: Margins.symmetric(vertical: 8),
          ),
          "h2": Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            margin: Margins.symmetric(vertical: 6),
          ),
          "h3": Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.w600,
            margin: Margins.symmetric(vertical: 4),
          ),
          "p": Style(
            fontSize: FontSize(14),
            lineHeight: const LineHeight(1.5),
            margin: Margins.symmetric(vertical: 4),
          ),
          "pre": Style(
            backgroundColor: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            padding: HtmlPaddings.all(12),
            margin: Margins.symmetric(vertical: 8),
            fontSize: FontSize(13),
            fontFamily: 'monospace',
            whiteSpace: WhiteSpace.pre,
          ),
          "code": Style(
            backgroundColor: Colors.grey.shade100,
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            fontSize: FontSize(13),
            fontFamily: 'monospace',
          ),
          "img": Style(
            width: Width(100, Unit.percent),
            margin: Margins.symmetric(vertical: 8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          "table": Style(
            border: Border.all(color: Colors.grey.shade300),
            margin: Margins.symmetric(vertical: 8),
          ),
          "th": Style(
            backgroundColor: Colors.grey.shade100,
            fontWeight: FontWeight.bold,
            padding: HtmlPaddings.all(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          "td": Style(
            padding: HtmlPaddings.all(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          "ul": Style(
            margin: Margins.symmetric(vertical: 4),
          ),
          "li": Style(
            margin: Margins.symmetric(vertical: 2),
          ),
          "strong": Style(
            fontWeight: FontWeight.bold,
          ),
          "em": Style(
            fontStyle: FontStyle.italic,
          ),
        },
      ),
    );
  }
}
