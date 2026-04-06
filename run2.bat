@echo off
setlocal EnableExtensions

if "%~1"=="" (
  echo Usage: %~nx0 ^<game.pdx^>
  echo Example: %~nx0 mouse.pdx
  exit /b 1
)

if "%PLAYDATE_SDK_PATH%"=="" (
  echo PLAYDATE_SDK_PATH is not set.
  exit /b 1
)

set "SDK_BIN=%PLAYDATE_SDK_PATH%\bin"
set "SIM=%SDK_BIN%\PlaydateSimulator.exe"

if not exist "%SIM%" (
  echo PlaydateSimulator not found: "%SIM%"
  exit /b 1
)

set "TARGET=%~1"
set "PDX_PATH="

REM If caller passes a direct path that exists, use it.
if exist "%TARGET%" set "PDX_PATH=%TARGET%"

REM If caller passes only a file name, try build\<name> first.
if not defined PDX_PATH (
  if exist "build\%TARGET%" set "PDX_PATH=build\%TARGET%"
)

REM Otherwise search recursively under build for the first matching file name.
if not defined PDX_PATH (
  for /r "build" %%F in (%TARGET%) do (
    set "PDX_PATH=%%F"
    goto :found
  )
)

:found
if not defined PDX_PATH (
  echo Could not find "%TARGET%".
  echo Searched current path and build\ recursively.
  exit /b 1
)

"%SIM%" "%PDX_PATH%"

endlocal
