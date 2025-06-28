import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FileService {
  static Future<String?> saveMarkdownFile(String content, String filename) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить техническое задание',
        fileName: '$filename.md',
        type: FileType.custom,
        allowedExtensions: ['md'],
      );
      
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(content);
        return outputFile;
      }
      return null;
    } catch (e) {
      throw Exception('Ошибка при сохранении файла: $e');
    }
  }
}
