/// Утилиты для обработки HTML контента от AI
class HtmlProcessor {
  /// Извлекает HTML-документ из ответа AI
  /// Ищет тег <h1>Техническое задание</h1> и возвращает всё с этого места
  static String extractHtml(String rawAiResponse) {
    final text = rawAiResponse.trim();
    
    // Ищем начало HTML-документа с заголовком "Техническое задание"
    final h1Pattern = RegExp(r'<h1[^>]*>.*?[Тт]ехническое\s+задание.*?</h1>', 
                              caseSensitive: false, 
                              multiLine: true, 
                              dotAll: true);
    
    final match = h1Pattern.firstMatch(text);
    if (match != null) {
      final htmlStartIndex = match.start;
      String htmlContent = text.substring(htmlStartIndex);
      
      // Убираем лишний текст после закрывающего тега </body> или </html>
      final bodyEndPattern = RegExp(r'</body>\s*</html>.*$', 
                                   caseSensitive: false, 
                                   multiLine: true, 
                                   dotAll: true);
      htmlContent = htmlContent.replaceAll(bodyEndPattern, '</body></html>');
      
      return htmlContent.trim();
    }
    
    // Если не нашли стандартный заголовок, ищем любой <h1>
    final anyH1Pattern = RegExp(r'<h1[^>]*>.*?</h1>', 
                               caseSensitive: false, 
                               multiLine: true, 
                               dotAll: true);
    
    final anyH1Match = anyH1Pattern.firstMatch(text);
    if (anyH1Match != null) {
      final htmlStartIndex = anyH1Match.start;
      String htmlContent = text.substring(htmlStartIndex);
      
      // Добавляем стандартный заголовок, если его нет
      if (!htmlContent.toLowerCase().contains('техническое задание')) {
        htmlContent = '<h1>Техническое задание</h1>\n\n' + htmlContent;
      }
      
      return htmlContent.trim();
    }
    
    // Если не найдено HTML-разметки, возвращаем с добавлением заголовка
    if (text.isNotEmpty && !text.toLowerCase().contains('<h1')) {
      return '<h1>Техническое задание</h1>\n\n' + text;
    }
    
    return text;
  }
}
