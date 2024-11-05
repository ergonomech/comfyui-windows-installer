@echo off
setlocal EnableDelayedExpansion

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges are required.
    echo Requesting elevated permissions...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

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

:: Activate conda environment
echo Activating Conda environment: %COMFYUI_ENV_NAME%...
call "%CONDA_BAT%" activate %COMFYUI_ENV_NAME%
if errorlevel 1 (
    echo Error: Failed to activate conda environment
    pause
    exit /b 1
)

:: Install required packages
echo Installing required packages...
pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/
pip install --upgrade huggingface_hub tqdm python-dotenv pyyaml

:: Run the installer
echo Starting model installation...
python "%SCRIPT_DIR%install_models.py"

if errorlevel 1 (
    echo Error: Model installation failed. Check the logs for details.
    pause
    exit /b 1
)

echo Model installation complete!
pause
endlocal