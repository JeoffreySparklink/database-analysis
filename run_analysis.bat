@echo off
REM Database Analysis Batch Script
REM This script helps set up and run database analysis tasks

echo ========================================
echo    Database Analysis Tool
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python is not installed or not in PATH
    echo Please install Python to continue
    pause
    exit /b 1
)

echo Python is available
echo.

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    echo Virtual environment created
) else (
    echo Virtual environment already exists
)

echo.

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install requirements if requirements.txt exists
if exist "requirements.txt" (
    echo Installing dependencies...
    pip install -r requirements.txt
) else (
    echo No requirements.txt found. Installing common database analysis packages...
    pip install pandas sqlalchemy psycopg2-binary pymongo matplotlib seaborn
)

echo.
echo Setup complete!
echo.
echo Available commands:
echo - To run analysis: python main.py (if main.py exists)
echo - To start interactive session: python
echo - To deactivate environment: deactivate
echo.

REM Check if main analysis script exists
if exist "main.py" (
    echo Running main analysis script...
    python main.py
) else (
    echo No main.py found. You can create analysis scripts and run them manually.
)

echo.
echo Analysis complete. Press any key to exit...
pause >nul