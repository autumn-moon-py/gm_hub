@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo ==========================================
echo   一键构建并更新本机已安装的 GM Hub
echo ==========================================
echo.

set "EPHEMERAL=windows\flutter\ephemeral"
set "SETUP_DIR=build\windows\x64\installer\Release"
set "EXE_NAME=gm_hub.exe"
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\GM Hub"
set "BUILD_LOG=%TEMP%\gm_hub_build.log"

echo [1/4] 修复构建环境
rem cpp 源文件缺失后 flutter 不会自动补回, 删掉 ephemeral 交给普通构建重新解包
if not exist "%EPHEMERAL%\cpp_client_wrapper\core_implementations.cc" (
    echo     cpp_client_wrapper 不完整, 清理后重建
    if exist "%EPHEMERAL%" rmdir /s /q "%EPHEMERAL%"
)
fvm flutter build windows --release
if errorlevel 1 goto :fail
if not exist "%EPHEMERAL%\cpp_client_wrapper\core_implementations.cc" goto :fail

echo.
echo [2/4] 构建 Release 安装包
call build_exe.bat > "%BUILD_LOG%" 2>&1
set "RC=%errorlevel%"
type "%BUILD_LOG%"
if not "%RC%"=="0" goto :fail

echo.
echo [3/4] 定位安装包
set "SETUP_NAME="
for /f "tokens=2 delims==" %%A in ('findstr /b /c:"OutputBaseFilename=" "%SETUP_DIR%\inno-script.iss" 2^>nul') do set "SETUP_NAME=%%A"
if not defined SETUP_NAME goto :fail
set "SETUP=%SETUP_DIR%\%SETUP_NAME%.exe"
if not exist "%SETUP%" goto :fail
echo     %SETUP%

echo.
echo [4/4] 关闭正在运行的程序并静默覆盖安装
taskkill /f /im %EXE_NAME% >nul 2>&1
pwsh -NoProfile -Command "Start-Sleep -Milliseconds 800"
pwsh -NoProfile -Command "$p = Start-Process -FilePath '%CD%\%SETUP%' -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CLOSEAPPLICATIONS' -Wait -PassThru; exit $p.ExitCode"
if errorlevel 1 goto :fail

if not exist "%INSTALL_DIR%\%EXE_NAME%" goto :fail

echo.
echo 更新完成: %INSTALL_DIR%\%EXE_NAME%
goto :end

:fail
echo.
echo [失败] 更新未完成, 请查看上方输出.
goto :end

:end
del /q "%BUILD_LOG%" >nul 2>nul
pause
exit /b 0
