@echo off
setlocal EnableDelayedExpansion

REM === ComfyUI Automated Installer (Conda) ===
REM This script installs/updates ComfyUI and its dependencies in a Conda environment.
REM It supports Miniconda/Anaconda, avoids PowerShell, and uses only public Git repos.
REM The script uses a cached Conda environment if available; otherwise, it creates one.
REM Run this script from the directory where you want ComfyUI installed.

REM --------------------------------------------------------------------
REM [1] Check for elevated privileges (optional)
net session >nul 2>&1
if %ERRORLEVEL%==0 (
    echo [INFO] Running with elevated privileges.
) else (
    echo [INFO] Running without elevated privileges.
)

REM --------------------------------------------------------------------
REM [2] Verify required programs: Git must be available.
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git is not installed or not in PATH. Please install Git and try again.
    goto END
)

REM --------------------------------------------------------------------
REM [3] Locate Conda installation (Miniconda/Anaconda) by setting CONDA_BAT.
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
    echo [ERROR] Conda installation not found. Please install Miniconda/Anaconda and try again.
    goto END
)
echo [INFO] Found Conda at: %CONDA_BAT%

REM --------------------------------------------------------------------
REM [4] Activate base Conda environment (so conda commands work).
call "%CONDA_BAT%" activate base
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to activate base Conda environment.
    goto END
)

REM --------------------------------------------------------------------
REM [5] Set environment variables for the installation.
set "COMFYUI_ENV_NAME=ComfyUI"
REM Here, ComfyUI will be cloned into %USERPROFILE%\ComfyUI
set "COMFYUI_DIR=%USERPROFILE%\%COMFYUI_ENV_NAME%"
echo [INFO] ComfyUI environment name: %COMFYUI_ENV_NAME%
echo [INFO] ComfyUI directory: %COMFYUI_DIR%

REM --------------------------------------------------------------------
REM [6] Use cached Conda environment if available; otherwise, create a new one.
echo [INFO] Checking for Conda environment "%COMFYUI_ENV_NAME%"...
call conda env list | findstr /I "\<%COMFYUI_ENV_NAME%\>" >nul
if %ERRORLEVEL%==0 (
    echo [INFO] Environment "%COMFYUI_ENV_NAME%" exists. Using cached environment.
) else (
    echo [INFO] Creating new Conda environment "%COMFYUI_ENV_NAME%"...
    call "%CONDA_BAT%" create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to create Conda environment "%COMFYUI_ENV_NAME%". Aborting.
        goto END
    )
    echo [INFO] Environment "%COMFYUI_ENV_NAME%" created successfully.
)

REM --------------------------------------------------------------------
REM [7] Activate the ComfyUI environment.
call "%CONDA_BAT%" activate %COMFYUI_ENV_NAME%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to activate environment "%COMFYUI_ENV_NAME%". Aborting.
    goto END
)
echo [INFO] Activated Conda environment: %COMFYUI_ENV_NAME%
call python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found in the environment. Aborting.
    goto END
)

REM --------------------------------------------------------------------
REM [8] Clone or update the ComfyUI repository.
if not exist "%COMFYUI_DIR%\.git" (
    echo [INFO] Cloning ComfyUI repository into "%COMFYUI_DIR%"...
    mkdir "%COMFYUI_DIR%"
    pushd "%COMFYUI_DIR%"
    git clone https://github.com/comfyanonymous/ComfyUI.git .
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to clone ComfyUI repository. Aborting.
        popd
        goto END
    )
    REM Trust this directory even if moved
    git config --global --add safe.directory "%COMFYUI_DIR%"
    popd
) else (
    echo [INFO] Updating ComfyUI repository in "%COMFYUI_DIR%"...
    pushd "%COMFYUI_DIR%"
    REM Trust this directory even if moved
    git config --global --add safe.directory "%COMFYUI_DIR%"
    git stash
    git pull --ff-only
    popd
)

REM --------------------------------------------------------------------
REM [9] Clone or update custom node repositories.
set "CUSTOM_NODES_DIR=%COMFYUI_DIR%\custom_nodes"
cd /d "%COMFYUI_DIR%"
if not exist "%CUSTOM_NODES_DIR%" mkdir "%CUSTOM_NODES_DIR%"
pushd "%CUSTOM_NODES_DIR%"

REM Configure Git credential helper to avoid login prompts.
git config --global credential.helper manager-core

REM Define custom nodes repositories.
set "CUSTOM_NODES_REPOS[0]=https://github.com/ltdrdata/ComfyUI-Manager.git"
set "CUSTOM_NODES_REPOS[1]=https://github.com/rgthree/rgthree-comfy.git"
set "CUSTOM_NODES_REPOS[5]=https://github.com/city96/ComfyUI_ExtraModels.git"
set "CUSTOM_NODES_REPOS[6]=https://github.com/city96/ComfyUI-GGUF.git"

for /L %%i in (0,1,7) do (
    set "REPO_URL=!CUSTOM_NODES_REPOS[%%i]!"
    if defined REPO_URL (
        REM Extract repository name from URL (strip .git and path components)
        for %%A in ("!REPO_URL!") do set "REPO_NAME=%%~nA"
        set "TARGET_DIR=%CUSTOM_NODES_DIR%\!REPO_NAME!"
        if not exist "!TARGET_DIR!" (
            echo [INFO] Cloning custom node: !REPO_NAME!...
            git clone "!REPO_URL!" "!TARGET_DIR!"
            if !ERRORLEVEL! neq 0 (
                echo [ERROR] Failed to clone custom node repository: !REPO_NAME!
                popd
                goto END
            )
            REM Trust this custom_nodes directory even if moved
            git config --global --add safe.directory "!TARGET_DIR!"
        ) else (
            echo [INFO] Updating custom node: !REPO_NAME!...
            pushd "!TARGET_DIR!"
            REM Trust this custom_nodes directory even if moved
            git config --global --add safe.directory "%CD%"
            git stash
            git pull --ff-only
            popd
        )
    )
)
popd

REM --------------------------------------------------------------------
REM [10] Install pre-update packages.
echo [INFO] Installing pre-update packages...
python -m pip install --no-user python-dotenv requests psutil
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install pre-update packages. Aborting.
    goto END
)

REM --------------------------------------------------------------------
REM [11] Install onnxruntime for GPU.
echo [INFO] Installing onnxruntime for GPU...
python -m pip install --no-user onnxruntime-gpu

REM --------------------------------------------------------------------
REM [12] Install PyTorch for CUDA 12.8.
echo [INFO] Installing PyTorch (CUDA 12.8) and related packages...
python -m pip install --no-user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install PyTorch for CUDA 12.8. Aborting.
    goto END
)

REM --------------------------------------------------------------------
REM [13] Install main ComfyUI requirements from requirements.txt.
cd /d "%COMFYUI_DIR%"
if exist "requirements.txt" (
    echo [INFO] Installing main ComfyUI requirements...
    python -m pip install --no-user -r requirements.txt
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to install main ComfyUI requirements. Aborting.
        goto END
    )
)

REM --------------------------------------------------------------------
REM [14] Copy configuration files.
echo [INFO] Updating configuration files...
if not exist "%COMFYUI_DIR%\user\default" mkdir "%COMFYUI_DIR%\user\default"
copy /Y "%~dp0\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
copy /Y "%~dp0\manager_config.ini" "%CUSTOM_NODES_DIR%\ComfyUI-Manager\config.ini"

REM --------------------------------------------------------------------
REM [15] Completion message.
echo.
echo [SUCCESS] Finished installation/update process.
echo Next steps:
echo   - Use launch_comfyui.bat to start ComfyUI.
echo   - Check the logs folder for any issues.
pause

:END
echo.
echo [ERROR] Installer encountered a problem. Check above logs.
pause
