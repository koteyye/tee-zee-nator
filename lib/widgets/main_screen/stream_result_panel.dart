import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../models/output_format.dart';
import '../../services/config_service.dart';
import '../../theme/app_theme.dart';
import 'confluence_html_transformer.dart';
import 'html_content_viewer.dart';

class StreamResultPanel extends StatelessWidget {
  final String documentText;
  final bool isActive;
  final bool finalized;
  final bool aborted;
  final String phase;
  final int progress;
  final String? summary;
  final String? error;
  final VoidCallback onSave;
  final VoidCallback? onAbort;

  const StreamResultPanel({
    super.key,
    required this.documentText,
    required this.isActive,
    required this.finalized,
  required this.phase,
    required this.progress,
    this.summary,
    this.error,
  required this.aborted,
    required this.onSave,
    this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Сгенерированное ТЗ:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (isActive && !finalized && onAbort != null) ...[
              TextButton.icon(
                onPressed: onAbort,
                icon: const Icon(Icons.stop_circle, size: 18, color: Colors.red),
                label: const Text('Прервать', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 8),
            ],
            if (documentText.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  final transformed = ConfluenceHtmlTransformer.transformForRender(documentText);
                  Clipboard.setData(ClipboardData(text: transformed));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ТЗ скопировано в буфер'), duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Скопировать'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Сохранить'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (error != null) _buildError(),
        _buildStatusBar(),
        const SizedBox(height: 8),
        Expanded(child: _buildContent(context)),
        if (finalized && summary != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (aborted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children:[
                    Icon(Icons.stop_circle, size: 14, color: Colors.red.shade400),
                    const SizedBox(width:4),
                    Text('Прервано', style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                  ]),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children:[
                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                    const SizedBox(width:4),
                    Text('Готово', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                  ]),
                ),
              Expanded(child: Text('Итог: $summary', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
    );
  }

  Widget _buildStatusBar() {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: isActive && !finalized
                    ? CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(color))
                    : Icon(finalized ? Icons.check_circle : Icons.hourglass_bottom, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Text(_statusLabel(), style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Text('$progress%', style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0, 100) / 100.0,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (documentText.isEmpty && !isActive) {
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
              Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Текст появится во время генерации', style: TextStyle(color: Colors.grey.shade600)),
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
          if (format == OutputFormat.confluence) {
            return HtmlContentViewer(htmlContent: documentText);
          }
          // Markdown rendering
          return Markdown(
            data: documentText,
            selectable: true,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
              h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              codeblockDecoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              code: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              blockquote: const TextStyle(color: Colors.black87),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor() {
    if (error != null) return Colors.red.shade600;
    if (aborted && finalized) return Colors.red.shade400;
    switch (phase) {
      case 'plan':
        return Colors.grey;
      case 'structure':
      case 'draft_sections':
        return AppTheme.primaryRed;
      case 'refine':
        return Colors.orange.shade600;
      case 'validate':
        return Colors.teal.shade600;
      case 'finalize':
        return Colors.green.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  String _phaseLabel(String p) {
    switch (p) {
      case 'init':
        return 'Инициализация';
      case 'plan':
        return 'Планирование';
      case 'structure':
        return 'Структура';
      case 'draft_sections':
        return 'Черновик';
      case 'refine':
        return 'Уточнение';
      case 'validate':
        return 'Проверка';
      case 'finalize':
        return 'Финализация';
      default:
        return p;
    }
  }

  String _statusLabel() {
    if (error != null) return 'Ошибка';
    if (aborted && finalized) return 'Прервано';
    return _phaseLabel(phase);
  }
}
