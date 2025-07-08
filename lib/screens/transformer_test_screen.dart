import 'package:flutter/material.dart';
import '../widgets/main_screen/confluence_html_transformer.dart';
import '../widgets/main_screen/html_content_viewer.dart';
import 'dart:io';

class TransformerTestScreen extends StatefulWidget {
  const TransformerTestScreen({super.key});

  @override
  State<TransformerTestScreen> createState() => _TransformerTestScreenState();
}

class _TransformerTestScreenState extends State<TransformerTestScreen> {
  String _originalHtml = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTestHtml();
  }

  Future<void> _loadTestHtml() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File('test_confluence.html');
      if (await file.exists()) {
        final content = await file.readAsString();
        ConfluenceHtmlTransformer.transformForRender(content);
        
        setState(() {
          _originalHtml = content;
        });
      }
    } catch (e) {
      print('Ошибка загрузки тестового файла: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест трансформера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTestHtml,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Оригинальный HTML
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Оригинальный HTML:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _originalHtml,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Преобразованный HTML (рендер)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Визуальный рендер:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: HtmlContentViewer(htmlContent: _originalHtml),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
