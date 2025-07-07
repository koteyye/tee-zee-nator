import 'package:file_picker/file_picker.dart';
import 'dart:io';

class FileService {
  static Future<String?> saveFile(String content, String filename) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить техническое задание',
        fileName: '$filename.html',
        type: FileType.custom,
        allowedExtensions: ['html'],
      );
      
      if (outputFile == null) return null;
      
      final file = File(outputFile);
      await file.writeAsString(content);
      return outputFile;
    } catch (e) {
      throw Exception('Ошибка при сохранении файла: $e');
    }
  }
}
