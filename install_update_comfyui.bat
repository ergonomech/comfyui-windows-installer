@echo off
setlocal EnableDelayedExpansion

:: Configuration
set "RECREATE_CONDA_ENV=true"
set "COMFYUI_ENV_NAME=ComfyUI"
set "BACKUP_MODELS=true"

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator privileges are required.
    echo Requesting elevated permissions...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: Initialize paths
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
IF NOT EXIST "%CONDA_PATH%" set "CONDA_PATH=%USER_HOME%\anaconda3"
IF NOT EXIST "%CONDA_PATH%" set "CONDA_PATH=C:\ProgramData\miniconda3"
IF NOT EXIST "%CONDA_PATH%" set "CONDA_PATH=C:\ProgramData\anaconda3"

:: Validate conda installation
if NOT EXIST "%CONDA_PATH%" (
    echo Error: Could not find Conda installation.
    echo Please install Miniconda or Anaconda first.
    pause
    exit /b 1
)

set "TIMESTAMP_CMD=powershell -Command "$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; Write-Host \"[$timestamp]\"""

:: Initialize conda properly
call "%CONDA_PATH%\Scripts\activate.bat"
call "%CONDA_PATH%\condabin\conda.bat" activate base

set "PATH=%CONDA_PATH%\condabin;%PATH%"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"

call %TIMESTAMP_CMD% "Starting ComfyUI installation/update process..."

:: Check if Conda environment exists
call conda env list | findstr /B /C:"%COMFYUI_ENV_NAME% " >nul
set "ENV_EXISTS=%errorlevel%"

:: Create or recreate environment based on conditions
if %ENV_EXISTS% neq 0 (
    call %TIMESTAMP_CMD% "Creating new Conda environment: %COMFYUI_ENV_NAME%..."
    call conda create --dev -n %COMFYUI_ENV_NAME% python=3.10 -y
    if errorlevel 1 (
        call %TIMESTAMP_CMD% "Error: Failed to create Conda environment"
        pause
        exit /b 1
    )
) else (
    if "%RECREATE_CONDA_ENV%"=="true" (
        call %TIMESTAMP_CMD% "Recreating Conda environment..."
        call conda deactivate
        call conda env remove -n %COMFYUI_ENV_NAME% -y
        if exist "%CONDA_PATH%\envs\%COMFYUI_ENV_NAME%" (
            rmdir /S /Q "%CONDA_PATH%\envs\%COMFYUI_ENV_NAME%"
        )
        call conda create --dev -n %COMFYUI_ENV_NAME% python=3.10 -y
        if errorlevel 1 (
            call %TIMESTAMP_CMD% "Error: Failed to recreate Conda environment"
            pause
            exit /b 1
        )
    )
)

:: Activate Conda environment
call %TIMESTAMP_CMD% "Activating Conda environment: %COMFYUI_ENV_NAME%"
call conda activate %COMFYUI_ENV_NAME%
if errorlevel 1 (
    call %TIMESTAMP_CMD% "Error: Failed to activate conda environment"
    pause
    exit /b 1
)

:: Add environment binary paths
set "PATH=%CONDA_PATH%\envs\%COMFYUI_ENV_NAME%;%CONDA_PATH%\envs\%COMFYUI_ENV_NAME%\Scripts;%CONDA_PATH%\envs\%COMFYUI_ENV_NAME%\Library\bin;%PATH%"

:: Install main ComfyUI requirements from the cloned directory
if not exist "%COMFYUI_DIR%" (
    call %TIMESTAMP_CMD% "Cloning ComfyUI repository..."
    mkdir "%COMFYUI_DIR%"
    cd "%COMFYUI_DIR%"
    git clone https://github.com/comfyanonymous/ComfyUI.git .
) else (
    call %TIMESTAMP_CMD% "Updating ComfyUI repository..."
    cd "%COMFYUI_DIR%"
    git stash
    git pull
)

:: Install main ComfyUI requirements from the cloned directory
if exist "%COMFYUI_DIR%\requirements.txt" (
    call %TIMESTAMP_CMD% "Installing main ComfyUI requirements..."
    call python -m pip install -r "%COMFYUI_DIR%\requirements.txt"
)

:: Create/Update custom_nodes directory
if not exist "%COMFYUI_DIR%\custom_nodes" (
    mkdir "%COMFYUI_DIR%\custom_nodes"
)

:: Iterate through all subdirectories in custom_nodes
cd "%COMFYUI_DIR%\custom_nodes"
for /D %%d in (*) do (
    set "NODE_DIR=%%d"
    cd "!NODE_DIR!"
    
    :: Check if the directory is a git repository and pull updates if so
    if exist ".git" (
        call %TIMESTAMP_CMD% "Updating custom node: !NODE_DIR!..."
        git stash
        git pull
    )

    :: Install node-specific dependencies if install files or requirements.txt exist
    set "INSTALL_FLAG=0"
    if exist "install.py" (
        call %TIMESTAMP_CMD% "Running install.py for !NODE_DIR!..."
        call python install.py <nul
        set "INSTALL_FLAG=1"
    )
    if exist "install.bat" (
        call %TIMESTAMP_CMD% "Running install.bat for !NODE_DIR!..."
        call install.bat <nul
        set "INSTALL_FLAG=1"
    )
    if exist "install-manual.py" (
        call %TIMESTAMP_CMD% "Running install-manual.py for !NODE_DIR!..."
        call python install-manual.py <nul
        set "INSTALL_FLAG=1"
    )
    if exist "requirements.txt" (
        call %TIMESTAMP_CMD% "Installing requirements.txt for !NODE_DIR!..."
        call python -m pip install -r requirements.txt
    )
    cd ..
)

:: Restore models if backup exists
if exist "%USER_HOME%\comfyui_models_backup" (
    call %TIMESTAMP_CMD% "Restoring models..."
    xcopy "%USER_HOME%\comfyui_models_backup" "%COMFYUI_DIR%\models\" /E /I /H /Y
    if not errorlevel 1 (
        rmdir /S /Q "%USER_HOME%\comfyui_models_backup"
    )
)

:: Copy configuration files
call %TIMESTAMP_CMD% "Updating configuration files..."
if not exist "%COMFYUI_DIR%\user\default" mkdir "%COMFYUI_DIR%\user\default"
copy /Y "%SCRIPT_DIR%\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
copy /Y "%SCRIPT_DIR%\manager_config.ini" "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini"

:: Install packages with specific versions
call %TIMESTAMP_CMD% "Installing and configuring packages..."
call python -m pip install --no-warn-script-location --user ^
    onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/ --force-reinstall

call python -m pip install --no-warn-script-location --user ^
    -U xformers torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 --force-reinstall

:: Version-specific installations
call %TIMESTAMP_CMD% "Installing specific package versions..."
call python -m pip install --no-warn-script-location --user ^
    "numpy<2.0" ^
    "Pillow<10" ^
    tb-nightly ^
    --force-reinstall

call %TIMESTAMP_CMD% "Installation/Update complete!"
echo.
echo Next steps:
echo 1. Use launch_comfyui.bat to start ComfyUI
echo 2. Check the logs folder for any issues
echo.
pause
endlocal