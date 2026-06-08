@echo off
:: Установка кодировки UTF-8 для корректного вывода текста
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ==========================================
:: 1. Проверка прав администратора
:: ==========================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Требуются права администратора. Запрос повышения прав...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ========================================================
echo Утилита сетевой изоляции MAX Messenger (VK)
echo ========================================================
echo 1. Активировать блокировку (Hosts + Firewall + Taskkill)
echo 2. Снять блокировку (Очистка правил и Hosts)
echo 3. Выход
echo ========================================================
set /p choice="Выберите действие (1-3): "

if "%choice%"=="1" goto BLOCK
if "%choice%"=="2" goto UNBLOCK
if "%choice%"=="3" exit
goto MENU

:BLOCK
cls
echo [1/3] Принудительное завершение процессов MAX...
taskkill /F /IM max.exe >nul 2>&1
taskkill /F /IM max_updater.exe >nul 2>&1

echo [2/3] Применение правил брандмауэра (L3/L4 Фильтрация)...
:: Очистка старых правил перед применением
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1

:: Статические IP-адреса авторизации
netsh advfirewall firewall add rule name="MAX_Core_IP_Block" dir=out action=block remoteip="155.212.204.140,155.212.204.5,155.212.204.74,217.20.155.18" enable=yes >nul

:: Диапазоны подсетей VK AS47764 / AS47541
netsh advfirewall firewall add rule name="MAX_VK_Subnets_Block" dir=out action=block remoteip="95.163.0.0/16,128.140.168.0/21,178.22.88.0/21,217.20.144.0/20,217.20.155.0/24,185.16.150.0/22,185.30.168.0/22,87.240.128.0/19" enable=yes >nul

echo [3/3] Модификация файла hosts (DNS-изоляция)...
set HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts
:: Проверка на наличие уже внесенных записей, чтобы избежать дублирования
findstr /C:"# MAX_BLOCK_START" "%HOSTS_FILE%" >nul
if %errorlevel% equ 0 (
    echo Записи в hosts уже существуют. Пропуск.
) else (
    echo.>>"%HOSTS_FILE%"
    echo # MAX_BLOCK_START>>"%HOSTS_FILE%"
    echo 127.0.0.1 max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 web.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 st.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 download.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 platform-api.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 oneme.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 my.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 calls.okcdn.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 okcdn.ru>>"%HOSTS_FILE%"
    echo # MAX_BLOCK_END>>"%HOSTS_FILE%"
)

echo.
echo [УСПЕШНО] Система изолирована от инфраструктуры MAX.
pause
goto MENU

:UNBLOCK
cls
echo [1/2] Удаление правил из брандмауэра Windows...
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1

echo [2/2] Очистка файла hosts...
set HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts
set TEMP_HOSTS=%TEMP%\hosts_temp.txt

:: Построчное копирование hosts без блока MAX
findstr /V /R /C:"max\.ru" /C:"oneme\.ru" /C:"my\.com" /C:"okcdn\.ru" /C:"# MAX_BLOCK" "%HOSTS_FILE%" > "%TEMP_HOSTS%"
move /Y "%TEMP_HOSTS%" "%HOSTS_FILE%" >nul

echo.
echo [УСПЕШНО] Блокировка полностью снята. Трафик восстановлен.
pause
goto MENU