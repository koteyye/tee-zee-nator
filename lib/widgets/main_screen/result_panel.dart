import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Сохранить .html'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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
      child: HtmlContentViewer(htmlContent: generatedTz),
    );
  }
}
