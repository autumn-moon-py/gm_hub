@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%" || exit /b 1

echo %* | findstr /i /c:"--help" /c:" -h" >nul
if %ERRORLEVEL% EQU 0 (
  call flutter pub run inno_bundle --help
  exit /b %ERRORLEVEL%
)

if not exist ".dart_appdata" mkdir ".dart_appdata"
set "APPDATA=%CD%\.dart_appdata"

call :resolve_iscc
if not defined ISCC_EXE (
  echo Inno Setup not found. Install it first, e.g. winget install JRSoftware.InnoSetup
  echo Or download from https://jrsoftware.org/isdl.php
  exit /b 1
)

call flutter pub get
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

set "BUILD_TYPE=release"
echo %* | findstr /i /c:"--debug" >nul
if %ERRORLEVEL% EQU 0 set "BUILD_TYPE=debug"
echo %* | findstr /i /c:"--profile" >nul
if %ERRORLEVEL% EQU 0 set "BUILD_TYPE=profile"

set "ENV_FILE=%TEMP%\inno_bundle_env_%RANDOM%_%RANDOM%.txt"
call flutter pub run inno_bundle --no-install-inno --no-gen-app-id --no-gen-publisher --envs --no-hf > "%ENV_FILE%"
if %ERRORLEVEL% NEQ 0 (
  del /q "%ENV_FILE%" >nul 2>nul
  exit /b %ERRORLEVEL%
)

set "APP_NAME_CAMEL_CASE="
set "PUBSPEC_NAME="
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
  if /i "%%A"=="APP_NAME_CAMEL_CASE" set "APP_NAME_CAMEL_CASE=%%B"
  if /i "%%A"=="PUBSPEC_NAME" set "PUBSPEC_NAME=%%B"
)
del /q "%ENV_FILE%" >nul 2>nul

if not defined APP_NAME_CAMEL_CASE (
  echo Failed to parse APP_NAME_CAMEL_CASE from inno_bundle --envs output.
  exit /b 1
)
if not defined PUBSPEC_NAME (
  echo Failed to parse PUBSPEC_NAME from inno_bundle --envs output.
  exit /b 1
)

call flutter pub run inno_bundle --no-install-inno --no-gen-app-id --no-gen-publisher --no-installer --no-hf %*
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

set "BUILD_TYPE_TITLE=Release"
if /i "%BUILD_TYPE%"=="debug" set "BUILD_TYPE_TITLE=Debug"
if /i "%BUILD_TYPE%"=="profile" set "BUILD_TYPE_TITLE=Profile"

set "ISS_FILE="
if exist "%CD%\build\windows\x64\installer\%BUILD_TYPE_TITLE%\inno-script.iss" (
  set "ISS_FILE=%CD%\build\windows\x64\installer\%BUILD_TYPE_TITLE%\inno-script.iss"
)
if not defined ISS_FILE if exist "%CD%\build\windows\x64\installer\%BUILD_TYPE%\inno-script.iss" (
  set "ISS_FILE=%CD%\build\windows\x64\installer\%BUILD_TYPE%\inno-script.iss"
)
if not defined ISS_FILE if exist "%TEMP%\%APP_NAME_CAMEL_CASE%Installer\%BUILD_TYPE%\inno-script.iss" (
  set "ISS_FILE=%TEMP%\%APP_NAME_CAMEL_CASE%Installer\%BUILD_TYPE%\inno-script.iss"
)

if not exist "%ISS_FILE%" (
  echo Generated ISS file not found.
  echo Tried:
  echo   %CD%\build\windows\x64\installer\%BUILD_TYPE_TITLE%\inno-script.iss
  echo   %CD%\build\windows\x64\installer\%BUILD_TYPE%\inno-script.iss
  echo   %TEMP%\%APP_NAME_CAMEL_CASE%Installer\%BUILD_TYPE%\inno-script.iss
  exit /b 1
)

for %%I in ("%ISS_FILE%") do set "ISS_DIR=%%~dpI"
set "PATCHED_ISS=%ISS_DIR%inno-script-with-assoc.iss"
for %%I in ("%ISCC_EXE%") do set "INNO_DIR=%%~dpI"
set "ZH_LANG_FILE=%INNO_DIR%Languages\ChineseSimplified.isl"
if not exist "%ZH_LANG_FILE%" (
  set "ZH_LANG_FILE=%CD%\scripts\Languages\ChineseSimplified.isl"
)
if not exist "%ZH_LANG_FILE%" (
  echo Chinese language file not found.
  echo Checked:
  echo   %INNO_DIR%Languages\ChineseSimplified.isl
  echo   %CD%\scripts\Languages\ChineseSimplified.isl
  echo Please put ChineseSimplified.isl into one of the above paths.
  exit /b 1
)

> "%PATCHED_ISS%" echo #define MyExeName "%PUBSPEC_NAME%.exe"
set "IN_LANG=0"
set "LANG_WRITTEN=0"

for /f "usebackq delims=" %%L in ("%ISS_FILE%") do (
  set "line=%%L"
  if "!IN_LANG!"=="1" (
    if "!line:~0,1!"=="[" (
      set "IN_LANG=0"
      >> "%PATCHED_ISS%" echo !line!
    )
  ) else (
    if /i "!line!"=="[Languages]" (
      set "IN_LANG=1"
      set "LANG_WRITTEN=1"
      >> "%PATCHED_ISS%" echo [Languages]
      >> "%PATCHED_ISS%" echo Name: "chinesesimplified"; MessagesFile: "!ZH_LANG_FILE!"
    ) else (
      >> "%PATCHED_ISS%" echo !line!
    )
  )
)

if "!LANG_WRITTEN!"=="0" (
  >> "%PATCHED_ISS%" echo(
  >> "%PATCHED_ISS%" echo [Languages]
  >> "%PATCHED_ISS%" echo Name: "chinesesimplified"; MessagesFile: "!ZH_LANG_FILE!"
)

(
  echo(
  echo [Registry]
  echo Root: HKCU; Subkey: "Software\Classes\.gmh"; ValueType: string; ValueName: ""; ValueData: "gm_hub.gmh"; Flags: uninsdeletevalue
  echo Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh"; ValueType: string; ValueName: ""; ValueData: "GM Hub Project File"; Flags: uninsdeletekey
  echo Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyExeName},0"
  echo Root: HKCU; Subkey: "Software\Classes\gm_hub.gmh\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyExeName}"" ""%%1"""
)>> "%PATCHED_ISS%"

"%ISCC_EXE%" "%PATCHED_ISS%"
exit /b %ERRORLEVEL%

:resolve_iscc
set "ISCC_EXE="
for /f "delims=" %%I in ('where ISCC.exe 2^>nul') do (
  set "ISCC_EXE=%%I"
  goto :eof
)
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
  set "ISCC_EXE=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
  goto :eof
)
if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
  set "ISCC_EXE=%ProgramFiles%\Inno Setup 6\ISCC.exe"
  goto :eof
)
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" (
  set "ISCC_EXE=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
  goto :eof
)
if exist "%USERPROFILE%\AppData\Local\Programs\Inno Setup 6\ISCC.exe" (
  set "ISCC_EXE=%USERPROFILE%\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
  goto :eof
)
goto :eof
