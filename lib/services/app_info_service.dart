import 'package:package_info_plus/package_info_plus.dart';

/// Сервис для получения информации о приложении из pubspec.yaml
class AppInfoService {
  String? _version;
  String? _appName;

  /// Инициализация - загрузка данных из pubspec.yaml
  Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _version = packageInfo.version;
    _appName = packageInfo.appName;
  }

  /// Получить версию приложения из pubspec.yaml
  String get version => _version ?? 'Unknown';

  /// Получить название приложения
  String get appName => _appName ?? 'TeeZeeNator';

  /// Получить полную информацию для футера
  String getFooterText() => '$appName v$version';
}
