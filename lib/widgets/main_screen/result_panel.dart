import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/config_service.dart';
import '../../models/output_format.dart';
import 'html_content_viewer.dart';
import 'confluence_html_transformer.dart';

class ResultPanel extends StatelessWidget {
  final String generatedTz;
  final VoidCallback onSave;

  const ResultPanel({
    super.key,
    required this.generatedTz,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок и кнопка сохранения
        Row(
          children: [
            const Text(
              'Сгенерированное ТЗ:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (generatedTz.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  // Преобразуем HTML в рендер-вариант перед копированием
                  final transformedHtml = ConfluenceHtmlTransformer.transformForRender(generatedTz);
                  Clipboard.setData(ClipboardData(text: transformedHtml));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ТЗ скопировано в буфер обмена'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Скопировать в буфер'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              Consumer<ConfigService>(
                builder: (context, configService, child) {
                  final format = configService.config?.preferredFormat ?? OutputFormat.markdown;
                  final extension = format.fileExtension;
                  
                  return ElevatedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save, size: 16),
                    label: Text('Сохранить .$extension'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        
        // Область отображения контента
        Expanded(
          child: _buildContentArea(),
        ),
      ],
    );
  }

  Widget _buildContentArea() {
    if (generatedTz.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Сгенерированное ТЗ появится здесь',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Consumer<ConfigService>(
        builder: (context, configService, child) {
          final format = configService.config?.preferredFormat ?? OutputFormat.markdown;
          
          if (format == OutputFormat.markdown) {
            return _buildMarkdownViewer();
          } else {
            return HtmlContentViewer(htmlContent: generatedTz);
          }
        },
      ),
    );
  }

  Widget _buildMarkdownViewer() {
    return Markdown(
      data: generatedTz,
      padding: const EdgeInsets.all(16.0),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        p: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
        code: TextStyle(
          backgroundColor: Colors.grey.shade100,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        blockquote: TextStyle(
          color: Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(
            left: BorderSide(
              color: Colors.grey.shade400,
              width: 4,
            ),
          ),
        ),
        listBullet: const TextStyle(
          color: Colors.black87,
        ),
        tableHead: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
        tableBorder: TableBorder.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
    );
  }
}
