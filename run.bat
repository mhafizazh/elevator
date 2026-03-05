REM ...existing code...
@echo off
setlocal

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
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

"%PDC%" "source" "%BUILD_DIR%\game.pdx"
if errorlevel 1 exit /b 1

"%SIM%" "%BUILD_DIR%\game.pdx"

endlocal