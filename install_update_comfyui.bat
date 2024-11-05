@echo off
setlocal EnableDelayedExpansion

:: Configuration
set "RECREATE_CONDA_ENV=false"
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

:: Function to echo with timestamp
set "TIMESTAMP_CMD=powershell -Command "$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; Write-Host \"[$timestamp]\"""

:: Check for conda initialization
where conda >nul 2>&1
if %errorLevel% neq 0 (
    echo Initializing conda for command line use...
    call "%CONDA_PATH%\Scripts\activate.bat"
    call conda init cmd.exe
    echo Conda initialized. Please restart this script.
    pause
    exit /b 0
)

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

:: Backup models if needed and if directory exists
if "%BACKUP_MODELS%"=="true" (
    if exist "%COMFYUI_DIR%\models" (
        call %TIMESTAMP_CMD% "Backing up existing models directory..."
        if exist "%USER_HOME%\comfyui_models_backup" (
            rmdir /S /Q "%USER_HOME%\comfyui_models_backup"
        )
        xcopy "%COMFYUI_DIR%\models" "%USER_HOME%\comfyui_models_backup" /E /I /H /Y
        if errorlevel 1 (
            echo Error backing up models directory
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

:: Remove conflicting packages
call %TIMESTAMP_CMD% "Removing potentially conflicting packages..."
pip uninstall -y tb-nightly tensorboard onnxruntime onnxruntime-gpu numpy pillow protobuf sympy

:: Install core dependencies with specific versions through conda
call %TIMESTAMP_CMD% "Installing core dependencies through conda..."
call conda install -y -c conda-forge ^
    numpy=1.23.5 ^
    pillow=9.5.0 ^
    sympy=1.13.1 ^
    protobuf=3.20.3 ^
    absl-py=1.4.0 ^
    grpcio=1.48.2 ^
    markdown=3.4.4 ^
    werkzeug=2.3.7 ^
    scipy=1.10.1 ^
    matplotlib=3.7.2 ^
    numba=0.57.1 ^
    opencv=4.8.0 ^
    ffmpeg=4.3 ^
    tensorboard-data-server=0.7.1

:: Install PyTorch with CUDA
call %TIMESTAMP_CMD% "Installing PyTorch..."
call conda install -y pytorch=2.1.0 torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia

:: Install additional conda packages
call %TIMESTAMP_CMD% "Installing additional conda packages..."
call conda install -y -c conda-forge ^
    gradio ^
    streamlit ^
    kornia ^
    gguf ^
    scikit-image ^
    einops ^
    transformers ^
    coloredlogs ^
    humanfriendly ^
    pyreadline3

:: Install xformers through pip
call %TIMESTAMP_CMD% "Installing xformers..."
python -m pip install -U xformers --index-url https://download.pytorch.org/whl/cu121

:: Install/Update ComfyUI
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

:: Install ComfyUI requirements
if exist requirements.txt (
    call %TIMESTAMP_CMD% "Installing/Updating ComfyUI requirements..."
    call python -m pip install --no-cache-dir -r requirements.txt
)

:: Create/Update custom_nodes directory
if not exist "%COMFYUI_DIR%\custom_nodes" (
    mkdir "%COMFYUI_DIR%\custom_nodes"
)

:: Define custom nodes repositories
set "CUSTOM_NODES_REPOS[0]=https://github.com/ltdrdata/ComfyUI-Manager.git"
set "CUSTOM_NODES_REPOS[1]=https://github.com/rgthree/rgthree-comfy.git"
set "CUSTOM_NODES_REPOS[2]=https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
set "CUSTOM_NODES_REPOS[3]=https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
set "CUSTOM_NODES_REPOS[4]=https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git"
set "CUSTOM_NODES_REPOS[5]=https://github.com/city96/ComfyUI_ExtraModels.git"
set "CUSTOM_NODES_REPOS[6]=https://github.com/city96/ComfyUI-GGUF.git"
set "CUSTOM_NODES_REPOS[7]=https://github.com/Gourieff/comfyui-reactor-node.git"
set "CUSTOM_NODES_REPOS[8]=https://github.com/asagi4/ComfyUI-Adaptive-Guidance.git"

:: Install/Update custom nodes
cd "%COMFYUI_DIR%\custom_nodes"
for /L %%i in (0,1,8) do (
    for /f "tokens=2 delims==" %%a in ('echo !CUSTOM_NODES_REPOS[%%i]!') do (
        set "REPO_URL=%%a"
        for %%b in (!REPO_URL!) do set "REPO_NAME=%%~nb"
        
        if not exist "!REPO_NAME!" (
            call %TIMESTAMP_CMD% "Cloning !REPO_NAME!..."
            git clone !REPO_URL!
        ) else (
            call %TIMESTAMP_CMD% "Updating !REPO_NAME!..."
            cd "!REPO_NAME!"
            git stash
            git pull
            cd ..
        )
        
        if exist "!REPO_NAME!\requirements.txt" (
            call %TIMESTAMP_CMD% "Installing requirements for !REPO_NAME!..."
            call python -m pip install --no-cache-dir -r "!REPO_NAME!\requirements.txt" --no-deps
            if errorlevel 1 (
                call %TIMESTAMP_CMD% "Warning: Some requirements failed to install for !REPO_NAME!. Continuing..."
            )
        )
        if exist "!REPO_NAME!\install.py" (
            call %TIMESTAMP_CMD% "Running install.py for !REPO_NAME!..."
            call python "!REPO_NAME!\install.py"
        )
        if exist "!REPO_NAME!\install.bat" (
            call %TIMESTAMP_CMD% "Running install.bat for !REPO_NAME!..."
            call "!REPO_NAME!\install.bat"
        )
    )
)

:: Restore models if backup exists
if exist "%USER_HOME%\comfyui_models_backup" (
    call %TIMESTAMP_CMD% "Restoring models..."
    xcopy "%USER_HOME%\comfyui_models_backup" "%COMFYUI_DIR%\models" /E /I /H /Y
    if not errorlevel 1 (
        rmdir /S /Q "%USER_HOME%\comfyui_models_backup"
    )
)

:: Copy configuration files
call %TIMESTAMP_CMD% "Updating configuration files..."
if not exist "%COMFYUI_DIR%\user\default" mkdir "%COMFYUI_DIR%\user\default"
copy /Y "%SCRIPT_DIR%\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
copy /Y "%SCRIPT_DIR%\manager_config.ini" "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini"

:: Install launcher dependencies
call %TIMESTAMP_CMD% "Installing launcher dependencies..."
call python -m pip install python-dotenv requests psutil portalocker

:: Install onnxruntime-gpu at the very end
call %TIMESTAMP_CMD% "Installing onnxruntime-gpu..."
call python -m pip install --no-deps onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

call %TIMESTAMP_CMD% "Installation/Update complete!"
echo.
echo Next steps:
echo 1. Use launch_comfyui.bat to start ComfyUI
echo 2. Check the logs folder for any issues
echo.
pause
endlocal