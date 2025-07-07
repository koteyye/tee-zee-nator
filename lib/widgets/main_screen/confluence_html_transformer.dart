import 'dart:convert';
import 'dart:io';

/// Преобразователь Confluence Storage Format в обычный HTML для отображения
class ConfluenceHtmlTransformer {
  /// Преобразует Confluence HTML в обычный HTML для визуального отображения
  static String transformForRender(String confluenceHtml) {
    if (confluenceHtml.isEmpty) return confluenceHtml;
    
    String transformed = confluenceHtml;
    
    // 1. Преобразуем info макросы
    transformed = _transformInfoMacros(transformed);
    
    // 2. Преобразуем note макросы
    transformed = _transformNoteMacros(transformed);
    
    // 3. Преобразуем warning макросы
    transformed = _transformWarningMacros(transformed);
    
    // 4. Преобразуем code макросы
    transformed = _transformCodeMacros(transformed);
    
    // 5. Преобразуем panel макросы
    transformed = _transformPanelMacros(transformed);
    
    // 6. Преобразуем PlantUML макросы
    transformed = _transformPlantUmlMacros(transformed);
    
    // 7. Очищаем остальные ac: теги
    transformed = _cleanupConfluenceTags(transformed);
    
    return transformed;
  }
  
  /// Преобразует info макросы
  static String _transformInfoMacros(String html) {
    final infoPattern = RegExp(
      r'<ac:structured-macro ac:name="info"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(infoPattern, (match) {
      final content = match.group(1) ?? '';
      final title = _extractParameter(content, 'title') ?? 'Информация';
      final body = _extractRichTextBody(content);
      
      return '''
<div style="border-left: 4px solid #36B37E; background: #E3FCEF; padding: 12px; margin: 8px 0; border-radius: 4px;">
  <div style="font-weight: bold; color: #00875A; margin-bottom: 8px;">
    <span style="margin-right: 8px;">ℹ️</span>$title
  </div>
  <div>$body</div>
</div>''';
    });
  }
  
  /// Преобразует note макросы
  static String _transformNoteMacros(String html) {
    final notePattern = RegExp(
      r'<ac:structured-macro ac:name="note"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(notePattern, (match) {
      final content = match.group(1) ?? '';
      final title = _extractParameter(content, 'title') ?? 'Примечание';
      final body = _extractRichTextBody(content);
      
      return '''
<div style="border-left: 4px solid #2684FF; background: #DEEBFF; padding: 12px; margin: 8px 0; border-radius: 4px;">
  <div style="font-weight: bold; color: #0052CC; margin-bottom: 8px;">
    <span style="margin-right: 8px;">📝</span>$title
  </div>
  <div>$body</div>
</div>''';
    });
  }
  
  /// Преобразует warning макросы
  static String _transformWarningMacros(String html) {
    final warningPattern = RegExp(
      r'<ac:structured-macro ac:name="warning"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(warningPattern, (match) {
      final content = match.group(1) ?? '';
      final title = _extractParameter(content, 'title') ?? 'Внимание';
      final body = _extractRichTextBody(content);
      
      return '''
<div style="border-left: 4px solid #FF5630; background: #FFEBE6; padding: 12px; margin: 8px 0; border-radius: 4px;">
  <div style="font-weight: bold; color: #DE350B; margin-bottom: 8px;">
    <span style="margin-right: 8px;">⚠️</span>$title
  </div>
  <div>$body</div>
</div>''';
    });
  }
  
  /// Преобразует code макросы
  static String _transformCodeMacros(String html) {
    final codePattern = RegExp(
      r'<ac:structured-macro ac:name="code"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(codePattern, (match) {
      final content = match.group(1) ?? '';
      final language = _extractParameter(content, 'language') ?? '';
      final codeBody = _extractPlainTextBodyWithCdata(content);
      
      // Обычная обработка для всех языков программирования (включая PlantUML)
      final languageLabel = language.isNotEmpty ? ' ($language)' : '';
      
      return '''
<div style="margin: 8px 0;">
  ${language.isNotEmpty ? '<div style="background: #F4F5F7; padding: 4px 8px; font-size: 12px; color: #6B778C; border-radius: 4px 4px 0 0;">Код$languageLabel</div>' : ''}
  <pre style="background: #F4F5F7; padding: 12px; margin: 0; border-radius: ${language.isNotEmpty ? '0 0 4px 4px' : '4px'}; overflow-x: auto; font-family: 'Courier New', monospace; font-size: 13px; line-height: 1.4;"><code>$codeBody</code></pre>
</div>''';
    });
  }
  
  /// Преобразует panel макросы
  static String _transformPanelMacros(String html) {
    final panelPattern = RegExp(
      r'<ac:structured-macro ac:name="panel"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(panelPattern, (match) {
      final content = match.group(1) ?? '';
      final title = _extractParameter(content, 'title') ?? '';
      final body = _extractRichTextBody(content);
      
      return '''
<div style="border: 1px solid #DFE1E6; background: #F4F5F7; padding: 12px; margin: 8px 0; border-radius: 4px;">
  ${title.isNotEmpty ? '<div style="font-weight: bold; color: #172B4D; margin-bottom: 8px;">$title</div>' : ''}
  <div>$body</div>
</div>''';
    });
  }
  
  /// Преобразует PlantUML макросы (старый формат)
  static String _transformPlantUmlMacros(String html) {
    final plantUmlPattern = RegExp(
      r'<ac:structured-macro ac:name="plantuml"[^>]*>(.*?)</ac:structured-macro>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    return html.replaceAllMapped(plantUmlPattern, (match) {
      final content = match.group(1) ?? '';
      final plantUmlCode = _extractPlainTextBodyWithCdata(content);
      
      return _generatePlantUmlImage(plantUmlCode);
    });
  }
  
  /// Очищает остальные Confluence-специфичные теги
  static String _cleanupConfluenceTags(String html) {
    // Удаляем остальные ac: теги, оставляя их содержимое
    html = html.replaceAll(RegExp(r'<ac:rich-text-body[^>]*>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'</ac:rich-text-body>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'<ac:plain-text-body[^>]*>', caseSensitive: false), '');
    html = html.replaceAll(RegExp(r'</ac:plain-text-body>', caseSensitive: false), '');
    
    return html;
  }
  
  /// Извлекает параметр из Confluence макроса
  static String? _extractParameter(String content, String paramName) {
    final paramPattern = RegExp(
      r'<ac:parameter ac:name="' + paramName + r'"[^>]*>(.*?)</ac:parameter>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    final match = paramPattern.firstMatch(content);
    return match?.group(1)?.trim();
  }
  
  /// Извлекает содержимое ac:rich-text-body
  static String _extractRichTextBody(String content) {
    final bodyPattern = RegExp(
      r'<ac:rich-text-body[^>]*>(.*?)</ac:rich-text-body>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    final match = bodyPattern.firstMatch(content);
    return match?.group(1)?.trim() ?? '';
  }
  
  /// Извлекает содержимое ac:plain-text-body
  /// Извлекает содержимое ac:plain-text-body с CDATA
  static String _extractPlainTextBodyWithCdata(String content) {
    final bodyPattern = RegExp(
      r'<ac:plain-text-body[^>]*>(.*?)</ac:plain-text-body>',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    
    final match = bodyPattern.firstMatch(content);
    if (match == null) return '';
    
    String body = match.group(1) ?? '';
    
    // Извлекаем содержимое из CDATA
    final cdataPattern = RegExp(r'<!\[CDATA\[(.*?)\]\]>', multiLine: true, dotAll: true);
    final cdataMatch = cdataPattern.firstMatch(body);
    
    return cdataMatch?.group(1)?.trim() ?? body.trim();
  }
  
  /// Кодирование PlantUML с использованием deflate + base64 
  static String _encodePlantUml(String plantUmlCode) {
    try {
      // Конвертируем текст в UTF-8 байты
      final utf8Bytes = utf8.encode(plantUmlCode);
      
      // Сжимаем с помощью deflate алгоритма
      final deflateCodec = ZLibCodec(level: 9, raw: true);
      final compressedBytes = deflateCodec.encode(utf8Bytes);
      
      // Конвертируем в base64
      String base64 = base64Encode(compressedBytes);
      
      // Заменяем символы для PlantUML URL безопасности
      base64 = base64
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '');
      
      return base64;
    } catch (e) {
      // В случае ошибки возвращаем простую заглушку
      return 'error_encoding';
    }
  }
  
  /// Генерирует HTML с изображением PlantUML диаграммы
  static String _generatePlantUmlImage(String plantUmlCode) {
    if (plantUmlCode.isEmpty) {
      return '''
<div style="border: 2px dashed #DFE1E6; padding: 16px; margin: 8px 0; text-align: center; color: #6B778C; border-radius: 4px;">
  <div style="margin-bottom: 8px;">📊 PlantUML диаграмма</div>
  <div style="font-size: 12px;">Код диаграммы пуст</div>
</div>''';
    }
    
    // Генерируем URL для PlantUML сервера
    final encodedCode = _encodePlantUml(plantUmlCode);
    final imageUrl = 'https://www.plantuml.com/plantuml/png/$encodedCode';
    
    return '''
<div style="margin: 8px 0; text-align: center;">
  <div style="background: #F4F5F7; padding: 8px; margin-bottom: 8px; border-radius: 4px;">
    <span style="font-size: 12px; color: #6B778C;">📊 PlantUML диаграмма</span>
  </div>
  <img src="$imageUrl" alt="PlantUML диаграмма" style="max-width: 100%; height: auto; border: 1px solid #DFE1E6; border-radius: 4px;" 
       onerror="this.style.display='none'; this.nextElementSibling.style.display='block';" />
  <div style="display: none; border: 2px dashed #DFE1E6; padding: 16px; color: #6B778C; border-radius: 4px;">
    <div>❌ Не удалось загрузить диаграмму</div>
    <details style="margin-top: 8px;">
      <summary style="cursor: pointer;">Показать код</summary>
      <pre style="background: #F4F5F7; padding: 8px; margin-top: 8px; font-size: 11px; text-align: left;">$plantUmlCode</pre>
    </details>
  </div>
</div>''';
  }
}
