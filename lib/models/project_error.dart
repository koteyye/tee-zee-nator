/// Типы ошибок проекта
enum ProjectErrorType {
  directoryNotFound,
  directoryAccessDenied,
  tooManyFiles,
  noSupportedFiles,
  fileNotFound,
  fileTooBig,
  fileReadPermission,
  aiInvalidResponse,
  aiNetworkError,
  aiTimeout,
  generic,
}

/// Класс для представления ошибок проекта
class ProjectError implements Exception {
  final ProjectErrorType type;
  final String message;
  final dynamic originalError;

  ProjectError({
    required this.type,
    required this.message,
    this.originalError,
  });

  /// Фабричный метод для создания ошибки "директория не найдена"
  factory ProjectError.directoryNotFound(String path) {
    return ProjectError(
      type: ProjectErrorType.directoryNotFound,
      message: 'Directory not found: $path',
    );
  }

  /// Фабричный метод для создания ошибки "нет доступа к директории"
  factory ProjectError.directoryAccessDenied(String path) {
    return ProjectError(
      type: ProjectErrorType.directoryAccessDenied,
      message: 'Access denied to directory: $path',
    );
  }

  /// Фабричный метод для создания ошибки "слишком много файлов"
  factory ProjectError.tooManyFiles(int filesFound, int maxFiles) {
    return ProjectError(
      type: ProjectErrorType.tooManyFiles,
      message: 'Too many files: $filesFound (max: $maxFiles)',
    );
  }

  /// Фабричный метод для создания ошибки "нет поддерживаемых файлов"
  factory ProjectError.noSupportedFiles() {
    return ProjectError(
      type: ProjectErrorType.noSupportedFiles,
      message: 'No supported files found in directory',
    );
  }

  /// Фабричный метод для создания ошибки "файл не найден"
  factory ProjectError.fileNotFound(String path) {
    return ProjectError(
      type: ProjectErrorType.fileNotFound,
      message: 'File not found: $path',
    );
  }

  /// Фабричный метод для создания ошибки "файл слишком большой"
  factory ProjectError.fileTooBig(int sizeBytes, int maxSizeBytes) {
    return ProjectError(
      type: ProjectErrorType.fileTooBig,
      message: 'File too big: $sizeBytes bytes (max: $maxSizeBytes bytes)',
    );
  }

  /// Фабричный метод для создания ошибки "нет прав для чтения файла"
  factory ProjectError.fileReadPermission(String path) {
    return ProjectError(
      type: ProjectErrorType.fileReadPermission,
      message: 'No read permission for file: $path',
    );
  }

  /// Фабричный метод для создания ошибки "невалидный ответ AI"
  factory ProjectError.aiInvalidResponse([String? details]) {
    return ProjectError(
      type: ProjectErrorType.aiInvalidResponse,
      message: 'Invalid AI response${details != null ? ': $details' : ''}',
    );
  }

  /// Фабричный метод для создания ошибки "ошибка сети AI"
  factory ProjectError.aiNetworkError([dynamic error]) {
    return ProjectError(
      type: ProjectErrorType.aiNetworkError,
      message: 'AI network error',
      originalError: error,
    );
  }

  /// Фабричный метод для создания ошибки "таймаут AI"
  factory ProjectError.aiTimeout() {
    return ProjectError(
      type: ProjectErrorType.aiTimeout,
      message: 'AI request timeout',
    );
  }

  /// Фабричный метод для создания общей ошибки
  factory ProjectError.generic(String message, [dynamic error]) {
    return ProjectError(
      type: ProjectErrorType.generic,
      message: message,
      originalError: error,
    );
  }

  @override
  String toString() => 'ProjectError: $message${originalError != null ? ' ($originalError)' : ''}';
}
