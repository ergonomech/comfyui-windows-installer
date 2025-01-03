@echo off
setlocal EnableDelayedExpansion

:: Check if the script is running with administrative privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: If not running as admin, check if the elevation flag is set
    if "%~1" neq "--elevated" (
        echo Running script in PowerShell as current user...
        :: Restart the script inside cmd via PowerShell
        powershell -NoProfile -ExecutionPolicy Bypass -Command "cmd.exe /c '%~f0' --elevated"
        exit /b
    ) else (
        echo Continuing as current user without elevated privileges...
    )
)

:: Set default environment variables
set "RECREATE_CONDA_ENV=true"
set "COMFYUI_ENV_NAME=ComfyUI"

:: Function to echo with timestamp
set "TIMESTAMP_CMD=powershell -Command "$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; Write-Host \"[$timestamp]\""" 
where conda >nul 2>&1
where git >nul 2>&1
if errorlevel 1 (
    echo "Error: Required programs not found, please ensure Git, Python, and Conda are installed and in the system PATH"
    pause
    exit /b 1
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
)

:: Set environment variables
set "USER_HOME=%USERPROFILE%"
echo "User home directory: %USER_HOME%"
echo "ComfyUI environment name: %COMFYUI_ENV_NAME%"
echo "Recreate conda environment: %RECREATE_CONDA_ENV%"
set "COMFYUI_DIR=%USER_HOME%\%COMFYUI_ENV_NAME%"
echo "ComfyUI directory: %COMFYUI_DIR%"
if not exist "%COMFYUI_DIR%" (
    echo "Error: ComfyUI directory does not exist, it will be populated during installation"
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

:: Validate conda user based installation
echo "Checking for conda installation..."
set "CONDA_ENVS_PATH=%USER_HOME%\.conda\envs"
if NOT EXIST "%CONDA_ENVS_PATH%" set "CONDA_ENVS_PATH=%USER_HOME%\miniconda3\envs"
iF NOT EXIST "%CONDA_ENVS_PATH%" set "CONDA_ENVS_PATH=%USER_HOME%\anaconda3\envs"
if NOT EXIST "%CONDA_ENVS_PATH%" (
    call conda info
    if errorlevel 1 (
        echo "Error: Failed to see conda, please install Anaconda or Miniconda and try again"
        pause
        exit /b 1
    ) else (
        echo "Conda is Installed, but current user does not have environments, troubleshoot by creating a new environment manually"
        pause
        exit /b 1
    )
)

:: Activate environment
echo Activating Base Conda environment...
call "%CONDA_BAT%" activate "base"
if errorlevel 1 (
    echo Error: Failed to activate conda environment
    echo Please ensure 'conda init --all --system' has been run first
    pause
    exit /b 1
)
echo "Conda base is installed and activated, checking for python..."
call python -B -I -s -u --version
if errorlevel 1 (
    echo "Error: Failed to see python"
    pause
    exit /b 1
)

echo "Starting ComfyUI installation/update process..."

:: Create or recreate environment based on conditions
echo "Creating new conda environment: %COMFYUI_ENV_NAME%..."
call conda env list | findstr /B /C:"%COMFYUI_ENV_NAME% "
set "ENV_EXISTS_ERROR=!errorlevel!"
if "%RECREATE_CONDA_ENV%"=="true" (
    if !ENV_EXISTS_ERROR! EQU 0 (
        echo "Recreating existing conda environment: %COMFYUI_ENV_NAME%"
        call conda create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12
    )
    if !ENV_EXISTS_ERROR! EQU 1 (
        echo "Creating conda environment: %COMFYUI_ENV_NAME%"
        call conda create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12
    )
) else (
    if !ENV_EXISTS_ERROR! EQU 0 (
        echo "Conda environment already exists: %COMFYUI_ENV_NAME%"
    )
    if !ENV_EXISTS_ERROR! EQU 1 (
        echo "Error: Conda environment does not exist: %COMFYUI_ENV_NAME%"
        call conda create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12
    )
)

:: Activate conda environment
echo "Activating conda environment: %COMFYUI_ENV_NAME%"
call conda env list | findstr /B /C:"%COMFYUI_ENV_NAME% "
:: Activate environment
call "%CONDA_BAT%" activate "%COMFYUI_ENV_NAME%"
if errorlevel 1 (
    echo "Error: Failed to activate conda environment"
    pause
    exit /b 1
) else (
    echo "Conda environment activate, lets make sure we can see python...."
    if not exist "%CONDA_ENVS_PATH%\%COMFYUI_ENV_NAME%\python.exe" (
        echo "Conda Environment Path is Hardcoded Wrong, please troubleshoot and try again"
        pause
        exit /b 1
    )
    call python -B -I -s -u --version
    if errorlevel 1 (
        echo "Error: Failed to see python"
        pause
        exit /b 1
    )
)

:: Pre update package installations
echo "Installing Pre Update Packages..."
call python -B -I -s -u -m pip install -U python-dotenv requests psutil
if not errorlevel 1 (
    echo "Installed Pre Update Packages"
) else (
    echo "Failed to install Pre Update Packages"
    pause
    exit /b 1
)
echo "Installing onxxruntime for GPU..."
call python -B -I -s -u -m pip install -U onnxruntime-gpu
echo "Installing xformers..."
call python -B -I -s -u -m pip install -U xformers --index-url https://download.pytorch.org/whl/cu124
echo "Installing PyTorch for CUDA 12.4..."
call python -B -I -s -u -m pip install -U torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
if not errorlevel 1 (
    echo "Installed PyTorch for CUDA 12.4"
) else (
    echo "Failed to install PyTorch for CUDA 12.4"
    pause
    exit /b 1
)

:: Install main ComfyUI requirements from the cloned directory
if not exist "%COMFYUI_DIR%" (
    echo "Cloning ComfyUI repository..."
    mkdir "%COMFYUI_DIR%"
    cd "%COMFYUI_DIR%"
    git clone https://github.com/comfyanonymous/ComfyUI.git .
    if errorlevel 1 (
        echo "Error: Failed to clone ComfyUI repository"
        pause
        exit /b 1
    )
) else (
    echo "Updating ComfyUI repository..."
    cd "%COMFYUI_DIR%"
    git config --global --add safe.directory .
    git stash
    git pull
)

:: Install main ComfyUI requirements from the cloned directory
cd "%COMFYUI_DIR%"
if exist "requirements.txt" (
    echo "Installing main ComfyUI requirements..."
    call python -B -I -s -u -m pip install -U -r requirements.txt
    if errorlevel 1 (
        echo "Error: Failed to install main ComfyUI requirements"
        pause
        exit /b 1
    )
)

:: Create/Update custom_nodes directory
if not exist "%COMFYUI_DIR%\custom_nodes" (
    mkdir "%COMFYUI_DIR%\custom_nodes"
    echo "Created custom_nodes directory"
) else (
    echo "custom_nodes directory already exists at %COMFYUI_DIR%\custom_nodes"
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

:: Clone or update custom nodes repositories
cd "%COMFYUI_DIR%\custom_nodes"
for /L %%i in (0,1,7) do (
    set "REPO_URL=!CUSTOM_NODES_REPOS[%%i]!"
    set "REPO_NAME=!REPO_URL:~19,-4!"
    if not exist "!REPO_NAME!" (
        echo "Cloning custom node: !REPO_NAME!..."
        git clone !REPO_URL!
    ) else (
        echo "Updating custom node: !REPO_NAME!..."
        cd "!REPO_NAME!"
        git config --global --add safe.directory .
        git stash
        git pull
        cd ..
    )
)

:: Iterate through all subdirectories in custom_nodes
cd "%COMFYUI_DIR%\custom_nodes"
for /D %%d in (*) do (
    set "NODE_DIR=%%d"
    cd "!NODE_DIR!"
    
    :: Check if the directory is a git repository and pull updates if so
    if exist ".git" (
        call %TIMESTAMP_CMD% "Updating custom node: !NODE_DIR!..."
        git config --global --add safe.directory .
        git stash
        git pull
    )

    :: Install node-specific dependencies if install files or requirements.txt exist
    if exist "requirements.txt" (
        call %TIMESTAMP_CMD% "Installing requirements.txt for !NODE_DIR!..."
        call python -B -I -s -u -m pip install -U -r requirements.txt
        set "INSTALL_FLAG=1"
    )
    if not defined INSTALL_FLAG (
        call %TIMESTAMP_CMD% "No installation files found for !NODE_DIR!..."
    )
    cd ..
)
echo "Install other packages..."
call python -B -I -s -u -m pip install -U gradio

:: Install Torch a second time to ensure compatibility with PyTorch
echo "Installing PyTorch for CUDA 12.4...again"
call python -B -I -s -u -m pip install -U torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 --force-reinstall
if not errorlevel 1 (
    echo "Installed PyTorch for CUDA 12.4"
) else (
    echo "Failed to install PyTorch for CUDA 12.4"
    pause
    exit /b 1
)
echo "Installing typing-extensions..."
call s

:: Copy configuration files
echo "Updating configuration files..."
if not exist "%COMFYUI_DIR%\user\default" mkdir "%COMFYUI_DIR%\user\default"
copy /Y "%SCRIPT_DIR%\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
if not exist "%COMFYUI_DIR%\user\default\comfy.settings.json" (
    echo "Error: Failed to copy comfy.settings.json"
)
copy /Y "%SCRIPT_DIR%\manager_config.ini" "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini"
if not exist "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini" (
    echo "Error: Failed to copy manager_config.ini"
)

:: Finish
echo Finished installation/update process.
echo Next steps:
echo 1. Use launch_comfyui.bat to start ComfyUI
echo 2. Check the logs folder for any issues
pause