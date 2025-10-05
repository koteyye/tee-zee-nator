import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// Кнопка применения изменений
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// Кнопка отмены действия
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get cancel;

  /// Кнопка сохранения файла
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// Кнопка открытия папки проекта
  ///
  /// In ru, this message translates to:
  /// **'Открыть папку'**
  String get openFolder;

  /// Кнопка закрытия вкладки
  ///
  /// In ru, this message translates to:
  /// **'Закрыть вкладку'**
  String get closeTab;

  /// Кнопка публикации в Confluence
  ///
  /// In ru, this message translates to:
  /// **'Опубликовать в Confluence'**
  String get publishToConfluence;

  /// Кнопка запуска музикации
  ///
  /// In ru, this message translates to:
  /// **'Музицировать'**
  String get musicateButton;

  /// Открыть файл в файловом менеджере
  ///
  /// In ru, this message translates to:
  /// **'Открыть в папке'**
  String get openInFolder;

  /// Название панели проводника файлов
  ///
  /// In ru, this message translates to:
  /// **'Проводник файлов'**
  String get fileExplorer;

  /// Название панели вкладок
  ///
  /// In ru, this message translates to:
  /// **'Панель вкладок'**
  String get tabBar;

  /// Название AI чат панели
  ///
  /// In ru, this message translates to:
  /// **'AI Чат'**
  String get aiChat;

  /// Название области просмотра содержимого
  ///
  /// In ru, this message translates to:
  /// **'Область просмотра'**
  String get contentViewer;

  /// Название панели инструментов
  ///
  /// In ru, this message translates to:
  /// **'Панель инструментов'**
  String get toolbar;

  /// Название строки состояния
  ///
  /// In ru, this message translates to:
  /// **'Строка состояния'**
  String get statusBar;

  /// Статус файла - изменен
  ///
  /// In ru, this message translates to:
  /// **'Изменен'**
  String get fileModified;

  /// Статус файла - сохранен
  ///
  /// In ru, this message translates to:
  /// **'Сохранен'**
  String get fileSaved;

  /// Статус файла - ожидает подтверждения
  ///
  /// In ru, this message translates to:
  /// **'Ожидает подтверждения'**
  String get filePending;

  /// Статус файла - изменения приняты
  ///
  /// In ru, this message translates to:
  /// **'Принято'**
  String get fileAccepted;

  /// Статус файла - изменения отклонены
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get fileRejected;

  /// Режим AI чата - создание нового ТЗ
  ///
  /// In ru, this message translates to:
  /// **'Новое ТЗ'**
  String get aiChatModeNew;

  /// Режим AI чата - дополнения к существующему ТЗ
  ///
  /// In ru, this message translates to:
  /// **'Дополнения'**
  String get aiChatModeAmendments;

  /// Режим AI чата - анализ ТЗ
  ///
  /// In ru, this message translates to:
  /// **'Анализ'**
  String get aiChatModeAnalysis;

  /// Сообщение об ошибке при открытии файла
  ///
  /// In ru, this message translates to:
  /// **'Ошибка открытия файла: {fileName}'**
  String errorOpeningFile(String fileName);

  /// Сообщение об успешном сохранении файла
  ///
  /// In ru, this message translates to:
  /// **'Файл успешно сохранен'**
  String get fileSavedSuccess;

  /// Сообщение об успешном применении изменений
  ///
  /// In ru, this message translates to:
  /// **'Изменения применены'**
  String get changesApplied;

  /// Сообщение об отмене изменений
  ///
  /// In ru, this message translates to:
  /// **'Изменения отменены'**
  String get changesCancelled;

  /// Статус интеграции Confluence - активна
  ///
  /// In ru, this message translates to:
  /// **'Confluence: активно'**
  String get confluenceIntegrationActive;

  /// Статус интеграции Confluence - неактивна
  ///
  /// In ru, this message translates to:
  /// **'Confluence: неактивно'**
  String get confluenceIntegrationInactive;

  /// Версия приложения
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String appVersion(String version);

  /// Информация об авторе
  ///
  /// In ru, this message translates to:
  /// **'Создано {author}'**
  String createdBy(String author);

  /// Tooltip для индикатора Confluence - активно
  ///
  /// In ru, this message translates to:
  /// **'Confluence: активно'**
  String get confluenceActive;

  /// Tooltip для индикатора Confluence - неактивно
  ///
  /// In ru, this message translates to:
  /// **'Confluence: неактивно'**
  String get confluenceInactive;

  /// Tooltip для индикатора Музикации - активно
  ///
  /// In ru, this message translates to:
  /// **'Музикация: активно'**
  String get musicActive;

  /// Tooltip для индикатора Музикации - неактивно
  ///
  /// In ru, this message translates to:
  /// **'Музикация: неактивно'**
  String get musicInactive;

  /// Tooltip для индикатора Музикации с балансом
  ///
  /// In ru, this message translates to:
  /// **'Музикация: активно (баланс: {balance}₽)'**
  String musicActiveWithBalance(String balance);

  /// Tooltip для кнопки меню
  ///
  /// In ru, this message translates to:
  /// **'Меню'**
  String get menu;

  /// Сообщение об ошибке при открытии проекта
  ///
  /// In ru, this message translates to:
  /// **'Ошибка открытия проекта: {error}'**
  String errorOpeningProject(String error);

  /// Сообщение об успешном обновлении проекта
  ///
  /// In ru, this message translates to:
  /// **'Проект обновлен'**
  String get projectRefreshed;

  /// Сообщение об ошибке при обновлении проекта
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обновления: {error}'**
  String errorRefreshingProject(String error);

  /// Сообщение об успешном применении контента
  ///
  /// In ru, this message translates to:
  /// **'Контент успешно применен'**
  String get contentAppliedSuccessfully;

  /// Сообщение об ошибке при применении контента
  ///
  /// In ru, this message translates to:
  /// **'Ошибка применения: {error}'**
  String errorApplyingContent(String error);

  /// Сообщение об отклонении контента
  ///
  /// In ru, this message translates to:
  /// **'Контент отклонен'**
  String get contentRejected;

  /// Сообщение о том, что сгенерированный контент ожидает одобрения
  ///
  /// In ru, this message translates to:
  /// **'Сгенерированный контент ожидает одобрения'**
  String get generatedContentAwaitingApproval;

  /// Tooltip для кнопки открытия AI чата
  ///
  /// In ru, this message translates to:
  /// **'Открыть AI Чат (Ctrl+Shift+A)'**
  String get openAIChat;

  /// Сообщение об успешном открытии проекта
  ///
  /// In ru, this message translates to:
  /// **'Проект \"{projectName}\" открыт'**
  String projectOpened(String projectName);

  /// Сообщение об ошибке при сохранении файла
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {error}'**
  String errorSavingFile(String error);

  /// Сообщение об ошибке - файл пуст или не загружен
  ///
  /// In ru, this message translates to:
  /// **'Файл пуст или не загружен'**
  String get fileEmptyOrNotLoaded;

  /// Сообщение о достижении максимального количества вкладок
  ///
  /// In ru, this message translates to:
  /// **'Максимум открытых вкладок: {maxTabs}'**
  String maxOpenTabsReached(int maxTabs);

  /// Заголовок диалога о несохраненных изменениях
  ///
  /// In ru, this message translates to:
  /// **'Несохраненные изменения'**
  String get unsavedChangesTitle;

  /// Сообщение диалога о несохраненных изменениях
  ///
  /// In ru, this message translates to:
  /// **'У вас есть несохраненные изменения в {fileName}. Сохранить перед закрытием?'**
  String unsavedChangesMessage(String fileName);

  /// Кнопка 'Не сохранять' в диалоге
  ///
  /// In ru, this message translates to:
  /// **'Не сохранять'**
  String get dontSave;

  /// Сообщение об ошибке при отмене изменений
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отмены изменений: {error}'**
  String errorRevertingChanges(String error);

  /// Сообщение о том, что быстрый поиск в разработке
  ///
  /// In ru, this message translates to:
  /// **'Быстрый поиск файлов (в разработке)'**
  String get quickSearchInDevelopment;

  /// Сообщение о том, что поиск в файле в разработке
  ///
  /// In ru, this message translates to:
  /// **'Поиск в файле (в разработке)'**
  String get findInFileInDevelopment;

  /// Ошибка - директория не найдена
  ///
  /// In ru, this message translates to:
  /// **'Директория не найдена'**
  String get errorDirectoryNotFound;

  /// Ошибка - нет прав доступа к директории
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к директории'**
  String get errorDirectoryAccessDenied;

  /// Ошибка - слишком много файлов в проекте
  ///
  /// In ru, this message translates to:
  /// **'Слишком много файлов в проекте (максимум {maxFiles})'**
  String errorTooManyFiles(int maxFiles);

  /// Ошибка - нет поддерживаемых файлов в директории
  ///
  /// In ru, this message translates to:
  /// **'В директории не найдено поддерживаемых файлов'**
  String get errorNoSupportedFiles;

  /// Ошибка - файл не найден
  ///
  /// In ru, this message translates to:
  /// **'Файл не найден'**
  String get errorFileNotFound;

  /// Ошибка - файл слишком большой
  ///
  /// In ru, this message translates to:
  /// **'Файл слишком большой (максимум {maxSizeMb} MB)'**
  String errorFileTooBig(int maxSizeMb);

  /// Ошибка - нет прав для чтения файла
  ///
  /// In ru, this message translates to:
  /// **'Нет прав для чтения файла'**
  String get errorFileReadPermission;

  /// Ошибка - невалидный ответ от AI
  ///
  /// In ru, this message translates to:
  /// **'Получен невалидный ответ от AI'**
  String get errorAiInvalidResponse;

  /// Ошибка - проблемы с сетью при обращении к AI
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети при обращении к AI'**
  String get errorAiNetworkError;

  /// Ошибка - таймаут при обращении к AI
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания ответа от AI'**
  String get errorAiTimeout;

  /// Общее сообщение об ошибке
  ///
  /// In ru, this message translates to:
  /// **'Произошла ошибка: {message}'**
  String errorGeneric(String message);

  /// Кнопка повторить действие
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retryAction;

  /// Настройки приложения
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// Шаблоны требований
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны'**
  String get templates;

  /// О программе
  ///
  /// In ru, this message translates to:
  /// **'О программе'**
  String get about;

  /// Заголовок диалога о программе
  ///
  /// In ru, this message translates to:
  /// **'О программе TeeZeeNator'**
  String get aboutDialogTitle;

  /// Информация о создателе
  ///
  /// In ru, this message translates to:
  /// **'Создатель: Koteyye'**
  String get aboutDialogCreator;

  /// Закрыть окно
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
