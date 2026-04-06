@echo off
setlocal

set "DEBUG_MODE=0"
if /I "%~1"=="--debug" set "DEBUG_MODE=1"

if "%PLAYDATE_SDK_PATH%"=="" (
  echo PLAYDATE_SDK_PATH is not set.
  exit /b 1
)

set "SDK_BIN=%PLAYDATE_SDK_PATH%\bin"
set "PDC=%SDK_BIN%\pdc.exe"
set "SIM=%SDK_BIN%\PlaydateSimulator.exe"

if not exist "%PDC%" (
  echo pdc not found: "%PDC%"
  exit /b 1
)

if not exist "%SIM%" (
  echo PlaydateSimulator not found: "%SIM%"
  exit /b 1
)

set "BUILD_DIR=build"
set "TMP_SOURCE=%BUILD_DIR%\tmp_source"
set "PDX_DIR=%BUILD_DIR%\Azhari.pdx"

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

if exist "%TMP_SOURCE%" rmdir /s /q "%TMP_SOURCE%"
xcopy "source" "%TMP_SOURCE%\" /e /i /q >nul

if "%DEBUG_MODE%"=="1" (
  > "%TMP_SOURCE%\core\build_flags.lua" echo DEBUG_MODE = true
) else (
  > "%TMP_SOURCE%\core\build_flags.lua" echo DEBUG_MODE = false
)

"%PDC%" "%TMP_SOURCE%" "%PDX_DIR%"
if errorlevel 1 exit /b 1

"%SIM%" "%PDX_DIR%"

endlocal
