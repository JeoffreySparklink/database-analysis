@echo off
setlocal

REM Configuration
set "SERVER=SPR-JEOFFREY-C\SQLEXPRESS"
set "DATABASE=MESRecovery"
set "OUT_DIR=Analysis"
set "OUT_FILE=MESanalysis.csv"
set "OUT_PATH=%OUT_DIR%\%OUT_FILE%"

REM Ensure sqlcmd is available
where sqlcmd >nul 2>&1
if errorlevel 1 (
  echo ERROR: sqlcmd not found on PATH.
  echo Please install SQLCMD and retry.
  exit /b 1
)

REM Create output directory if it doesn't exist
if not exist "%OUT_DIR%" (
  mkdir "%OUT_DIR%" 2>nul
)

REM Generate complete analysis using PowerShell (includes distinct values and header)
echo Generating complete database analysis...
powershell -ExecutionPolicy Bypass -File "generate_complete_analysis.ps1" -Server "%SERVER%" -Database "%DATABASE%" -OutputPath "%OUT_PATH%"
if errorlevel 1 (
  echo ERROR: Failed to query database %DATABASE% on %SERVER%.
  exit /b 1
)

echo Export complete: %OUT_PATH%
endlocal
exit /b 0