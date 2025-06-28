@echo off
echo Включение режима разработчика Windows...
echo.
echo Для работы Flutter Desktop приложения необходимо включить режим разработчика.
echo.
echo Способ 1 (автоматический):
start ms-settings:developers
echo.
echo Способ 2 (ручной):
echo 1. Откройте Параметры Windows (Win + I)
echo 2. Перейдите в "Обновление и безопасность"
echo 3. Выберите "Для разработчиков" в левом меню
echo 4. Включите "Режим разработчика"
echo.
echo После включения режима разработчика запустите:
echo flutter run -d windows
echo.
pause
