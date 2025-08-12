@echo off
setlocal EnableDelayedExpansion

:: Get script directory with proper path handling
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
cd /d "%SCRIPT_DIR%"

:: Load optional .env file (only KEY=VALUE lines, ignore comments and blanks)
if exist "%SCRIPT_DIR%\.env" (
    for /f "tokens=1* delims==" %%A in ('type "%SCRIPT_DIR%\.env" ^| findstr /r "^[^#].*=.*"') do (
        if not "%%A"=="" (
            set "__VAL=%%B"
            if defined __VAL set "__VAL=!__VAL:"=!"
            set "%%A=!__VAL!"
        )
    )
)

:: Set default environment name
if not defined COMFYUI_ENV_NAME (
    set "COMFYUI_ENV_NAME=ComfyUI"
)

:: Headless print mode (1=quiet prints, 0=show env details). ComfyUI itself runs headless.
if not defined HEADLESS (
    set "HEADLESS=0"
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
)

:: Print environment details when not in quiet mode
if not "%HEADLESS%"=="1" (
    echo.
    echo ================= Environment Details =================
    call conda info --envs
    echo -------------------------------------------------------
    python -c "import sys, torch; print('Python:', sys.version); print('Exe:', sys.executable); print('Torch:', getattr(torch,'__version__','n/a')); print('CUDA avail:', getattr(torch,'cuda',None) and torch.cuda.is_available()); print('CUDA ver:', getattr(torch,'version',None) and torch.version.cuda)" 2>nul
    echo =======================================================
    echo.
)

:: make sure python is available (avoid verbose conda info output)
python -B -I -s -u --version
if errorlevel 1 (
    echo Error: Python is not available
    echo Please ensure Python is installed and available in the activated environment
    pause
    exit /b 1
)

:: Foreground mode; close this window to terminate the supervisor and its children
echo Starting ComfyUI... (Close this window to stop)
python -B -I -s -u "%SCRIPT_DIR%\comfyui_windows.py"
set "EXIT_CODE=%ERRORLEVEL%"
echo ComfyUI exited with code %EXIT_CODE%.
endlocal & exit /b %EXIT_CODE%