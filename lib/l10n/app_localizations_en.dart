// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get apply => 'Apply';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get openFolder => 'Open Folder';

  @override
  String get closeTab => 'Close Tab';

  @override
  String get publishToConfluence => 'Publish to Confluence';

  @override
  String get musicateButton => 'Musicify';

  @override
  String get openInFolder => 'Open in Folder';

  @override
  String get fileExplorer => 'File Explorer';

  @override
  String get tabBar => 'Tab Bar';

  @override
  String get aiChat => 'AI Chat';

  @override
  String get contentViewer => 'Content Viewer';

  @override
  String get toolbar => 'Toolbar';

  @override
  String get statusBar => 'Status Bar';

  @override
  String get fileModified => 'Modified';

  @override
  String get fileSaved => 'Saved';

  @override
  String get filePending => 'Pending Confirmation';

  @override
  String get fileAccepted => 'Accepted';

  @override
  String get fileRejected => 'Rejected';

  @override
  String get aiChatModeNew => 'New Specification';

  @override
  String get aiChatModeAmendments => 'Amendments';

  @override
  String get aiChatModeAnalysis => 'Analysis';

  @override
  String errorOpeningFile(String fileName) {
    return 'Error opening file: $fileName';
  }

  @override
  String get fileSavedSuccess => 'File saved successfully';

  @override
  String get changesApplied => 'Changes applied';

  @override
  String get changesCancelled => 'Changes cancelled';

  @override
  String get confluenceIntegrationActive => 'Confluence: active';

  @override
  String get confluenceIntegrationInactive => 'Confluence: inactive';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String createdBy(String author) {
    return 'Created by $author';
  }

  @override
  String get confluenceActive => 'Confluence: active';

  @override
  String get confluenceInactive => 'Confluence: inactive';

  @override
  String get musicActive => 'Music: active';

  @override
  String get musicInactive => 'Music: inactive';

  @override
  String musicActiveWithBalance(String balance) {
    return 'Music: active (balance: $balance₽)';
  }

  @override
  String get menu => 'Menu';

  @override
  String errorOpeningProject(String error) {
    return 'Error opening project: $error';
  }

  @override
  String get projectRefreshed => 'Project refreshed';

  @override
  String errorRefreshingProject(String error) {
    return 'Error refreshing: $error';
  }

  @override
  String get contentAppliedSuccessfully => 'Content applied successfully';

  @override
  String errorApplyingContent(String error) {
    return 'Error applying: $error';
  }

  @override
  String get contentRejected => 'Content rejected';

  @override
  String get generatedContentAwaitingApproval =>
      'Generated content awaiting approval';

  @override
  String get openAIChat => 'Open AI Chat (Ctrl+Shift+A)';

  @override
  String projectOpened(String projectName) {
    return 'Project \"$projectName\" opened';
  }

  @override
  String errorSavingFile(String error) {
    return 'Error saving: $error';
  }

  @override
  String get fileEmptyOrNotLoaded => 'File is empty or not loaded';

  @override
  String maxOpenTabsReached(int maxTabs) {
    return 'Maximum open tabs: $maxTabs';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved Changes';

  @override
  String unsavedChangesMessage(String fileName) {
    return 'You have unsaved changes in $fileName. Save before closing?';
  }

  @override
  String get dontSave => 'Don\'t Save';

  @override
  String errorRevertingChanges(String error) {
    return 'Error reverting changes: $error';
  }

  @override
  String get quickSearchInDevelopment => 'Quick file search (in development)';

  @override
  String get findInFileInDevelopment => 'Find in file (in development)';

  @override
  String get errorDirectoryNotFound => 'Directory not found';

  @override
  String get errorDirectoryAccessDenied => 'No access to directory';

  @override
  String errorTooManyFiles(int maxFiles) {
    return 'Too many files in project (max $maxFiles)';
  }

  @override
  String get errorNoSupportedFiles => 'No supported files found in directory';

  @override
  String get errorFileNotFound => 'File not found';

  @override
  String errorFileTooBig(int maxSizeMb) {
    return 'File too big (max $maxSizeMb MB)';
  }

  @override
  String get errorFileReadPermission => 'No read permission for file';

  @override
  String get errorAiInvalidResponse => 'Invalid AI response received';

  @override
  String get errorAiNetworkError => 'Network error when accessing AI';

  @override
  String get errorAiTimeout => 'AI request timeout exceeded';

  @override
  String errorGeneric(String message) {
    return 'An error occurred: $message';
  }

  @override
  String get retryAction => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get templates => 'Templates';

  @override
  String get about => 'About';

  @override
  String get aboutDialogTitle => 'About TeeZeeNator';

  @override
  String get aboutDialogCreator => 'Created by: Koteyye';

  @override
  String get close => 'Close';
}
