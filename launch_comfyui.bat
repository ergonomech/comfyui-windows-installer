@echo off
setlocal EnableDelayedExpansion

:: Get script directory with proper path handling
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%"

:: Load environment variables with proper quoting
if exist ".env" (
    for /F "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
)

:: Set default environment name
if not defined COMFYUI_ENV_NAME (
    set "COMFYUI_ENV_NAME=ComfyUI"
)

:: Detect conda installation with proper path handling
set "CONDA_BAT="
if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\miniconda3\condabin\conda.bat"
) else if exist "%USERPROFILE%\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\Anaconda3\condabin\conda.bat"
) else if exist "C:\ProgramData\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=C:\ProgramData\miniconda3\condabin\conda.bat"
) else if exist "C:\ProgramData\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=C:\ProgramData\Anaconda3\condabin\conda.bat"
)

if not defined CONDA_BAT (
    echo Error: Could not find conda installation
    echo Please ensure Conda is installed and 'conda init --all --system' has been run
    pause
    exit /b 1
)

:: Activate environment
echo Activating Conda environment: %COMFYUI_ENV_NAME%...
call "%CONDA_BAT%" activate "%COMFYUI_ENV_NAME%"
if errorlevel 1 (
    echo Error: Failed to activate conda environment
    echo Please ensure 'conda init --all --system' has been run first
    pause
    exit /b 1
)

:: Install required packages with proper flags
echo Installing required packages...
call python -m pip install --no-warn-script-location --user ^
    python-dotenv requests psutil

:: Run the launcher
echo Starting ComfyUI...
python "%SCRIPT_DIR%\comfyui_windows.py"

endlocal