@echo off
setlocal EnableDelayedExpansion

:: Get the directory containing this script
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: Load environment variables from .env file if it exists
if exist ".env" (
    for /F "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
)

:: Set default environment name if not set
if not defined COMFYUI_ENV_NAME (
    set "COMFYUI_ENV_NAME=ComfyUI"
)

:: Detect conda installation
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
    pause
    exit /b 1
)

:: Activate conda environment and install required packages
echo Activating Conda environment: %COMFYUI_ENV_NAME%...
call "%CONDA_BAT%" activate %COMFYUI_ENV_NAME%
if errorlevel 1 (
    echo Error: Failed to activate conda environment
    pause
    exit /b 1
)

:: Install required packages if needed
echo Installing required packages...
pip install python-dotenv requests psutil

:: Run the launcher
echo Starting ComfyUI...
python "%SCRIPT_DIR%comfyui_windows.py"

endlocal