@echo off
setlocal EnableDelayedExpansion

:: Get script directory with proper path handling
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%"

:: Set default environment name
if not defined COMFYUI_ENV_NAME (
    set "COMFYUI_ENV_NAME=ComfyUI"
)

:: Detect conda installation with proper path handling
set "CONDA_BAT="
if exist "%USERPROFILE%\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\miniconda3\condabin\conda.bat"
)
if exist "%USERPROFILE%\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\Anaconda3\condabin\conda.bat"
)
if exist "C:\ProgramData\miniconda3\condabin\conda.bat" (
    set "CONDA_BAT=C:\ProgramData\miniconda3\condabin\conda.bat"
)
if exist "C:\ProgramData\Anaconda3\condabin\conda.bat" (
    set "CONDA_BAT=C:\ProgramData\Anaconda3\condabin\conda.bat"
)
if exist "%USERPROFILE%\.conda\condabin\conda.bat" (
    set "CONDA_BAT=%USERPROFILE%\.conda\condabin\conda.bat"
)

if not defined CONDA_BAT (
    echo Error: Could not find conda installation
    echo Please ensure Conda is installed and 'conda init --all --system' has been run
    pause
    exit /b 1
) else (
    echo Found Conda installation: %CONDA_BAT%
)

:: Activate environment
echo Activating Conda environment: %COMFYUI_ENV_NAME%...
call "%CONDA_BAT%" activate "%COMFYUI_ENV_NAME%"
if errorlevel 1 (
    echo Error: Failed to activate conda environment
    echo Please ensure 'conda init --all --system' has been run first
    pause
    exit /b 1
) else (
    echo Conda environment activated
)

:: make sure python is available
call "%CONDA_BAT%" info
python -B -I -s -u --version
if errorlevel 1 (
    echo Error: Python is not available
    echo Please ensure Python is installed and available in the activated environment
    pause
    exit /b 1
)

:: Run the launcher
echo Starting ComfyUI...
python -B -I -s -u "%SCRIPT_DIR%\comfyui_windows.py"

endlocal