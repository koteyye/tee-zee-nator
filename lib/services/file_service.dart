import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/output_format.dart';
import '../widgets/main_screen/content_processor.dart';
import '../widgets/main_screen/markdown_processor.dart';
import '../widgets/main_screen/html_processor.dart';

class FileService {
  static Future<String?> saveFile(String content, String filename) async {
    try {
      // Extract file extension from filename
      final parts = filename.split('.');
      final extension = parts.length > 1 ? parts.last : 'html';
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить техническое задание',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      
      if (outputFile == null) return null;
      
      final file = File(outputFile);
      await file.writeAsString(content);
      return outputFile;
    } catch (e) {
      throw Exception('Ошибка при сохранении файла: $e');
    }
  }

  /// Enhanced save method with format-specific handling and validation
  static Future<String?> saveFileWithFormat({
    required String content,
    required OutputFormat format,
    String? customFilename,
  }) async {
    try {
      // Validate content based on format
      final validatedContent = validateContentForFormat(content, format);
      
      // Generate format-specific filename
      final filename = generateFilename(format, customFilename);
      
      // Get format-specific dialog title and file extension
      final dialogTitle = getDialogTitle(format);
      final extension = format.fileExtension;
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      
      if (outputFile == null) return null;
      
      final file = File(outputFile);
      await file.writeAsString(validatedContent);
      return outputFile;
    } catch (e) {
      throw Exception('Ошибка при сохранении файла: $e');
    }
  }

  /// Validates content based on the selected format
  static String validateContentForFormat(String content, OutputFormat format) {
    switch (format) {
      case OutputFormat.markdown:
        return validateMarkdownContent(content);
      case OutputFormat.confluence:
        return _validateHtmlContent(content);
    }
  }

  /// Validates and ensures Markdown content is compatible with third-party editors
  static String validateMarkdownContent(String content) {
    if (content.trim().isEmpty) {
      throw FileExportException('Cannot export empty Markdown content');
    }

    // Ensure content is properly processed Markdown (not raw AI response)
    if (content.contains('@@@START@@@') || content.contains('@@@END@@@')) {
      throw FileExportException('Content contains unprocessed escape markers');
    }

    // Validate Markdown structure for third-party editor compatibility
    final lines = content.split('\n');
    final processedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      // Ensure proper heading spacing for VSCode/Obsidian compatibility
      if (line.trim().startsWith('#')) {
        // Add blank line before heading if previous line is not empty
        if (i > 0 && processedLines.isNotEmpty && processedLines.last.trim().isNotEmpty) {
          processedLines.add('');
        }
        processedLines.add(line);
        // Add blank line after heading for better readability
        if (i < lines.length - 1 && lines[i + 1].trim().isNotEmpty && !lines[i + 1].trim().startsWith('#')) {
          processedLines.add('');
        }
      } else {
        processedLines.add(line);
      }
    }

    final validatedContent = processedLines.join('\n');

    // Final validation - ensure it's valid Markdown
    performMarkdownStructureValidation(validatedContent);

    return validatedContent;
  }

  /// Validates HTML content structure
  static String _validateHtmlContent(String content) {
    if (content.trim().isEmpty) {
      throw FileExportException('Cannot export empty HTML content');
    }

    // Ensure content has proper HTML structure
    if (!content.toLowerCase().contains('<h1')) {
      throw FileExportException('HTML content must contain at least one heading');
    }

    return content;
  }

  /// Performs structural validation of Markdown content
  static void performMarkdownStructureValidation(String content) {
    final lines = content.split('\n');
    bool hasHeading = false;
    bool hasContent = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        hasHeading = true;
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        hasContent = true;
      }
    }

    if (!hasHeading) {
      throw FileExportException('Markdown content should contain at least one heading for proper structure');
    }

    if (!hasContent) {
      throw FileExportException('Markdown content should contain body text in addition to headings');
    }
  }

  /// Generates format-specific filename with timestamp and format identifier
  static String generateFilename(OutputFormat format, String? customFilename) {
    if (customFilename != null && customFilename.isNotEmpty) {
      // Ensure custom filename has correct extension
      final parts = customFilename.split('.');
      if (parts.length > 1 && parts.last == format.fileExtension) {
        return customFilename;
      } else {
        return '${parts.first}.${format.fileExtension}';
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final formatId = format == OutputFormat.markdown ? 'MD' : 'HTML';
    return 'TZ_${formatId}_$timestamp.${format.fileExtension}';
  }

  /// Gets format-specific dialog title
  static String getDialogTitle(OutputFormat format) {
    switch (format) {
      case OutputFormat.markdown:
        return 'Сохранить техническое задание (Markdown)';
      case OutputFormat.confluence:
        return 'Сохранить техническое задание (HTML)';
    }
  }
}

/// Exception thrown when file export fails
class FileExportException implements Exception {
  final String message;
  
  const FileExportException(this.message);
  
  @override
  String toString() => 'FileExportException: $message';
}
