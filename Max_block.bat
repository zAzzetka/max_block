@echo off
:: Установка кодировки UTF-8 для корректного вывода текста
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ========================================================
:: Проверка прав администратора
:: ========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Требуются права администратора. Запрос повышения прав...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ========================================================
echo БЛОКИРОВЩИК РАБОТЫ МЕССЕНДЖЕРА MAX
echo ========================================================
echo 1. Отключение доступа к сети и сайту (Firewall + Hosts)
echo 2. Запрет на запуск exe (Реестр + Блокировка процессов)
echo 3. Отключение блокировки (Полное восстановление доступа)
echo 4. Выход
echo ========================================================
set /p choice="Выберите действие (1-4): "

if "%choice%"=="1" goto BLOCK_NET
if "%choice%"=="2" goto BLOCK_EXE
if "%choice%"=="3" goto UNBLOCK_ALL
if "%choice%"=="4" exit
goto MENU

:BLOCK_NET
cls
echo [1/2] Настройка брандмауэра Windows (IP + Порты)...
:: Очистка старых сетевых правил, чтобы избежать дублирования
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_Ports_Block" >nul 2>&1

:: Блокировка статических IP-адресов мессенджера MAX
netsh advfirewall firewall add rule name="MAX_Core_IP_Block" dir=out action=block remoteip="217.20.155.18,155.212.204.140,155.212.204.5,155.212.204.74" enable=yes >nul

:: Блокировка ключевых подсетей VK, отвечающих за передачу данных приложения
netsh advfirewall firewall add rule name="MAX_VK_Subnets_Block" dir=out action=block remoteip="95.163.0.0/16,217.20.144.0/20,217.20.155.0/24,87.240.128.0/19,185.16.150.0/22,185.30.168.0/22,128.140.168.0/21,178.22.88.0/21" enable=yes >nul

:: Блокировка сетевых UDP-портов WebRTC/STUN, через которые мессенджер обходит HTTP-прокси
netsh advfirewall firewall add rule name="MAX_Ports_Block" dir=out action=block protocol=UDP remoteport=3478,19302,50000-65535 enable=yes >nul

echo [2/2] Модификация файла hosts (DNS-изоляция)...
set HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts

findstr /C:"# MAX_BLOCK_START" "%HOSTS_FILE%" >nul
if %errorlevel% equ 0 (
    echo Записи в файле hosts уже существуют. Пропускаю.
) else (
    echo.>>"%HOSTS_FILE%"
    echo # MAX_BLOCK_START>>"%HOSTS_FILE%"
    echo 127.0.0.1 max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 web.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 st.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 dev.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 download.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 platform-api.max.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 oneme.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 my.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 okcdn.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 calls.okcdn.ru>>"%HOSTS_FILE%"
    echo 127.0.0.1 im.vk.me>>"%HOSTS_FILE%"
    echo 127.0.0.1 static.vk.me>>"%HOSTS_FILE%"
    echo 127.0.0.1 ://vk.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 ://vk.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 api.ipify.org>>"%HOSTS_FILE%"
    echo 127.0.0.1 api64.ipify.org>>"%HOSTS_FILE%"
    echo 127.0.0.1 ://amazonaws.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 ifconfig.me>>"%HOSTS_FILE%"
    echo 127.0.0.1 icanhazip.com>>"%HOSTS_FILE%"
    echo 127.0.0.1 ipinfo.io>>"%HOSTS_FILE%"
    echo 127.0.0.1 whoer.net>>"%HOSTS_FILE%"
    echo # MAX_BLOCK_END>>"%HOSTS_FILE%"
    ipconfig /flushdns >nul
)

echo.
echo [УСПЕШНО] Сетевой доступ к серверам и сайту MAX заблокирован.
pause
goto MENU

:BLOCK_EXE
cls
echo [1/3] Принудительное закрытие запущенных копий приложения...
taskkill /F /IM max.exe >nul 2>&1
taskkill /F /IM max_updater.exe >nul 2>&1

echo [2/3] Запрет на запуск исполняемых файлов в реестре Windows...
:: Подменяем отладчик файлов на фиктивную команду. ОС откажется их запускать.
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max.exe" /v Debugger /t REG_SZ /d "ntsd -d" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max_updater.exe" /v Debugger /t REG_SZ /d "ntsd -d" /f >nul 2>&1

echo [3/3] Удаление задач автообновления мессенджера...
schtasks /delete /tn "MAXUpdater" /f >nul 2>&1
schtasks /delete /tn "MAX AutoUpdate" /f >nul 2>&1

echo.
echo [УСПЕШНО] Запуск файлов max.exe заблокирован на уровне системы.
pause
goto MENU

:UNBLOCK_ALL
cls
echo [1/3] Снятие ограничений на запуск EXE в реестре...
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max.exe" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\max_updater.exe" /f >nul 2>&1

echo [2/3] Удаление запрещающих правил из брандмауэра Windows...
netsh advfirewall firewall delete rule name="MAX_Core_IP_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_VK_Subnets_Block" >nul 2>&1
netsh advfirewall firewall delete rule name="MAX_Ports_Block" >nul 2>&1

echo [3/3] Восстановление оригинального файла hosts...
set HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts
set TEMP_HOSTS=%TEMP%\hosts_temp.txt
set in_block=0
(for /f "delims=" %%a in ('type "%HOSTS_FILE%"') do (
    set "line=%%a"
    if "!line!"=="# MAX_BLOCK_START" (set in_block=1)
    if !in_block! equ 0 (echo %%a)
    if "!line!"=="# MAX_BLOCK_END" (set in_block=0)
)) > "%TEMP_HOSTS%"
move /Y "%TEMP_HOSTS%" "%HOSTS_FILE%" >nul
ipconfig /flushdns >nul

echo.
echo [УСПЕШНО] Все виды блокировок сняты. Система полностью восстановлена.
pause
goto MENU
