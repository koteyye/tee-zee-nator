// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get apply => 'Применить';

  @override
  String get cancel => 'Отменить';

  @override
  String get save => 'Сохранить';

  @override
  String get openFolder => 'Открыть папку';

  @override
  String get closeTab => 'Закрыть вкладку';

  @override
  String get publishToConfluence => 'Опубликовать в Confluence';

  @override
  String get musicateButton => 'Музицировать';

  @override
  String get openInFolder => 'Открыть в папке';

  @override
  String get fileExplorer => 'Проводник файлов';

  @override
  String get tabBar => 'Панель вкладок';

  @override
  String get aiChat => 'AI Чат';

  @override
  String get contentViewer => 'Область просмотра';

  @override
  String get toolbar => 'Панель инструментов';

  @override
  String get statusBar => 'Строка состояния';

  @override
  String get fileModified => 'Изменен';

  @override
  String get fileSaved => 'Сохранен';

  @override
  String get filePending => 'Ожидает подтверждения';

  @override
  String get fileAccepted => 'Принято';

  @override
  String get fileRejected => 'Отклонено';

  @override
  String get aiChatModeNew => 'Новое ТЗ';

  @override
  String get aiChatModeAmendments => 'Дополнения';

  @override
  String get aiChatModeAnalysis => 'Анализ';

  @override
  String errorOpeningFile(String fileName) {
    return 'Ошибка открытия файла: $fileName';
  }

  @override
  String get fileSavedSuccess => 'Файл успешно сохранен';

  @override
  String get changesApplied => 'Изменения применены';

  @override
  String get changesCancelled => 'Изменения отменены';

  @override
  String get confluenceIntegrationActive => 'Confluence: активно';

  @override
  String get confluenceIntegrationInactive => 'Confluence: неактивно';

  @override
  String appVersion(String version) {
    return 'Версия $version';
  }

  @override
  String createdBy(String author) {
    return 'Создано $author';
  }

  @override
  String get confluenceActive => 'Confluence: активно';

  @override
  String get confluenceInactive => 'Confluence: неактивно';

  @override
  String get musicActive => 'Музикация: активно';

  @override
  String get musicInactive => 'Музикация: неактивно';

  @override
  String musicActiveWithBalance(String balance) {
    return 'Музикация: активно (баланс: $balance₽)';
  }

  @override
  String get menu => 'Меню';

  @override
  String errorOpeningProject(String error) {
    return 'Ошибка открытия проекта: $error';
  }

  @override
  String get projectRefreshed => 'Проект обновлен';

  @override
  String errorRefreshingProject(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String get contentAppliedSuccessfully => 'Контент успешно применен';

  @override
  String errorApplyingContent(String error) {
    return 'Ошибка применения: $error';
  }

  @override
  String get contentRejected => 'Контент отклонен';

  @override
  String get generatedContentAwaitingApproval =>
      'Сгенерированный контент ожидает одобрения';

  @override
  String get openAIChat => 'Открыть AI Чат (Ctrl+Shift+A)';

  @override
  String projectOpened(String projectName) {
    return 'Проект \"$projectName\" открыт';
  }

  @override
  String errorSavingFile(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get fileEmptyOrNotLoaded => 'Файл пуст или не загружен';

  @override
  String maxOpenTabsReached(int maxTabs) {
    return 'Максимум открытых вкладок: $maxTabs';
  }

  @override
  String get unsavedChangesTitle => 'Несохраненные изменения';

  @override
  String unsavedChangesMessage(String fileName) {
    return 'У вас есть несохраненные изменения в $fileName. Сохранить перед закрытием?';
  }

  @override
  String get dontSave => 'Не сохранять';

  @override
  String errorRevertingChanges(String error) {
    return 'Ошибка отмены изменений: $error';
  }

  @override
  String get quickSearchInDevelopment => 'Быстрый поиск файлов (в разработке)';

  @override
  String get findInFileInDevelopment => 'Поиск в файле (в разработке)';

  @override
  String get errorDirectoryNotFound => 'Директория не найдена';

  @override
  String get errorDirectoryAccessDenied => 'Нет доступа к директории';

  @override
  String errorTooManyFiles(int maxFiles) {
    return 'Слишком много файлов в проекте (максимум $maxFiles)';
  }

  @override
  String get errorNoSupportedFiles =>
      'В директории не найдено поддерживаемых файлов';

  @override
  String get errorFileNotFound => 'Файл не найден';

  @override
  String errorFileTooBig(int maxSizeMb) {
    return 'Файл слишком большой (максимум $maxSizeMb MB)';
  }

  @override
  String get errorFileReadPermission => 'Нет прав для чтения файла';

  @override
  String get errorAiInvalidResponse => 'Получен невалидный ответ от AI';

  @override
  String get errorAiNetworkError => 'Ошибка сети при обращении к AI';

  @override
  String get errorAiTimeout => 'Превышено время ожидания ответа от AI';

  @override
  String errorGeneric(String message) {
    return 'Произошла ошибка: $message';
  }

  @override
  String get retryAction => 'Повторить';

  @override
  String get settings => 'Настройки';

  @override
  String get templates => 'Шаблоны';

  @override
  String get about => 'О программе';

  @override
  String get aboutDialogTitle => 'О программе TeeZeeNator';

  @override
  String get aboutDialogCreator => 'Создатель: Koteyye';

  @override
  String get close => 'Закрыть';
}
