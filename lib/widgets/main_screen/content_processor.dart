/// Base interface for format-specific content processing
abstract class ContentProcessor {
  /// Extracts and processes content from raw AI response
  String extractContent(String rawAiResponse);
  
  /// Returns the file extension for this format
  String getFileExtension();
  
  /// Returns the content type identifier for this format
  String getContentType();
}