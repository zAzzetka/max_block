@echo off
:: Установка кодировки UTF-8 для корректного вывода текста
chcp 65001 >nul
setlocal enabledelayedexpansion

set "SELF=%~dpnx0"
set "TASK_NAME=MaxBlockerAutoRun"
set "VBS_PATH=%~dp0max_block_silent.vbs"
set "HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts"

:: ========================================================
:: Тихий режим: вызывается Планировщиком заданий при входе в систему.
:: Аргумент "1" означает "просто применить блокировку и выйти",
:: без показа меню и без пауз.
:: ========================================================
if "%~1"=="1" (
    call :BLOCK_NET
    call :BLOCK_EXE
    exit /b
)

:: ========================================================
:: Проверка прав администратора (только для интерактивного режима)
:: ========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Требуются права администратора. Запрос повышения прав...
    powershell -Command "Start-Process '%SELF%' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ========================================================
echo УТИЛИТА ДЛЯ БЛОКИРОВКИ РАБОТЫ МЕССЕНДЖЕРА MAX
echo ========================================================
echo 1. Отключение доступа к сети и сайту (Firewall + Hosts)
echo 2. Запрет на запуск exe (Реестр + Блокировка процессов)
echo 3. Добавить скрипт в автозапуск Windows (Каждый запуск ПК)
echo 4. Убрать скрипт из автозапуска Windows
echo 5. Отключить блокировки (Полное восстановление системы)
echo 6. Выход
echo ========================================================
set /p choice="Выберите действие (1-6): "

if "%choice%"=="1" (
    call :BLOCK_NET
    pause
    goto MENU
)
if "%choice%"=="2" (
    call :BLOCK_EXE
    pause
    goto MENU
)
if "%choice%"=="3" goto ADD_AUTOSTART
if "%choice%"=="4" goto REMOVE_AUTOSTART
if "%choice%"=="5" (
    call :UNBLOCK_ALL
    pause
    goto MENU
)
if "%choice%"=="6" exit
goto MENU

:: ========================================================
:: Блокировка сети (Firewall + Hosts)
:: ========================================================
:BLOCK_NET
echo [1/2] Настройка брандмауэра Windows (IP + Порты)...
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_Ports_Block" >nul 2>&1

netsh advfirewall firewall add rule name="MAX_Core_IP_Block" dir=out action=block remoteip="217.20.155.18,155.212.204.140,155.212.204.5,155.212.204.74" enable=yes >nul
netsh advfirewall firewall add rule name="MAX_VK_Subnets_Block" dir=out action=block remoteip="95.163.0.0/16,217.20.144.0/20,217.20.155.0/24,87.240.128.0/19,185.16.150.0/22,185.30.168.0/22,128.140.168.0/21,178.22.88.0/21" enable=yes >nul
netsh advfirewall firewall add rule name="MAX_Ports_Block" dir=out action=block protocol=UDP remoteport=3478,19302,50000-65535 enable=yes >nul

echo [2/2] Модификация файла hosts (DNS-изоляция)...
:: Сначала убираем старый блок (если есть), затем пишем актуальный список.
:: Это гарантирует, что при повторном запуске новые домены тоже попадут в hosts.
call :STRIP_HOSTS_BLOCK
(
echo.
echo # MAX_BLOCK_START
echo 127.0.0.1 max.ru
echo 127.0.0.1 web.max.ru
echo 127.0.0.1 st.max.ru
echo 127.0.0.1 dev.max.ru
echo 127.0.0.1 download.max.ru
echo 127.0.0.1 platform-api.max.ru
echo 127.0.0.1 oneme.ru
echo 127.0.0.1 api2.oneme.ru
echo 127.0.0.1 my.com
echo 127.0.0.1 okcdn.ru
echo 127.0.0.1 calls.okcdn.ru
echo 127.0.0.1 im.vk.me
echo 127.0.0.1 static.vk.me
echo 127.0.0.1 vk.com
echo 127.0.0.1 www.vk.com
echo 127.0.0.1 api.ipify.org
echo 127.0.0.1 api64.ipify.org
echo 127.0.0.1 ifconfig.me
echo 127.0.0.1 icanhazip.com
echo 127.0.0.1 ipinfo.io
echo 127.0.0.1 whoer.net
echo # MAX_BLOCK_END
) >> "%HOSTS_FILE%"
ipconfig /flushdns >nul

echo.
echo [УСПЕШНО] Сетевой доступ к серверам и сайту MAX заблокирован.
exit /b

:: Вспомогательная подпрограмма: вырезает старый блок MAX_BLOCK_START..END из hosts
:STRIP_HOSTS_BLOCK
set "TEMP_HOSTS=%TEMP%\hosts_temp.txt"
set in_block=0
(for /f "delims=" %%a in ('type "%HOSTS_FILE%"') do (
    set "line=%%a"
    if "!line!"=="# MAX_BLOCK_START" (set in_block=1)
    if !in_block! equ 0 (echo %%a)
    if "!line!"=="# MAX_BLOCK_END" (set in_block=0)
)) > "%TEMP_HOSTS%"
move /Y "%TEMP_HOSTS%" "%HOSTS_FILE%" >nul
exit /b

:: ========================================================
:: Запрет на запуск exe
:: ========================================================
:BLOCK_EXE
echo [1/3] Принудительное закрытие запущенных копий приложения...
taskkill /F /IM max.exe >nul 2>&1
taskkill /F /IM max_updater.exe >nul 2>&1

echo [2/3] Запрет на запуск исполняемых файлов в реестре Windows...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max.exe" /v Debugger /t REG_SZ /d "ntsd -d" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max_updater.exe" /v Debugger /t REG_SZ /d "ntsd -d" /f >nul 2>&1

echo [3/3] Удаление задач автообновления мессенджера...
schtasks /delete /tn "MAXUpdater" /f >nul 2>&1
schtasks /delete /tn "MAX AutoUpdate" /f >nul 2>&1

echo.
echo [УСПЕШНО] Запуск файлов max.exe заблокирован на уровне системы.
exit /b

:: ========================================================
:: Автозапуск (через скрытый VBS-лаунчер, без мелькания консоли)
:: ========================================================
:ADD_AUTOSTART
cls
echo Создание файла скрытого запуска...
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo WshShell.Run "cmd /c ""%SELF%"" 1", 0, False
) > "%VBS_PATH%"

echo Создание фоновой задачи в Планировщике Windows...
schtasks /create /tn "%TASK_NAME%" /tr "wscript.exe \"%VBS_PATH%\"" /sc onlogon /rl highest /f >nul 2>&1

if %errorlevel% equ 0 (
    echo [УСПЕШНО] Скрипт добавлен в автозапуск.
    echo Теперь при каждом входе в систему блокировка сети и exe будет обновляться автоматически, без окна консоли.
) else (
    echo [ОШИБКА] Не удалось создать задачу в планировщике.
)
pause
goto MENU

:REMOVE_AUTOSTART
cls
echo Удаление задачи автозапуска из системы...
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
del "%VBS_PATH%" >nul 2>&1

if %errorlevel% equ 0 (
    echo [УСПЕШНО] Скрипт успешно удален из автозапуска.
) else (
    echo [ИНФО] Задача автозапуска не найдена или уже удалена.
)
pause
goto MENU

:: ========================================================
:: Полный откат всех блокировок
:: ========================================================
:UNBLOCK_ALL
echo [1/3] Снятие ограничений на запуск EXE в реестре...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max.exe" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max_updater.exe" /f >nul 2>&1

echo [2/3] Удаление запрещающих правил из брандмауэра Windows...
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_Ports_Block" >nul 2>&1

echo [3/3] Восстановление оригинального файла hosts...
call :STRIP_HOSTS_BLOCK
ipconfig /flushdns >nul

echo.
echo [УСПЕШНО] Все виды блокировок сняты. Система полностью восстановлена.
exit /b
