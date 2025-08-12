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
    echo [INFO] Creating new Conda environment "%COMFYUI_ENV_NAME%" with Python 3.12.11...
    call "%CONDA_BAT%" create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12.11
    if %ERRORLEVEL% neq 0 (
        echo [WARNING] Python 3.12.11 not available or failed to solve; falling back to latest 3.12.x...
        call "%CONDA_BAT%" create --no-default-packages --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12
        if %ERRORLEVEL% neq 0 (
            echo [ERROR] Failed to create Conda environment "%COMFYUI_ENV_NAME%". Aborting.
            goto END
        )
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
REM [7.1] Ensure Python is 3.12.11 (upgrade in-place if needed).
for /f %%v in ('python -c "import sys;print('.'.join(map(str, sys.version_info[:3])))"') do set "CURRENT_PYTHON=%%v"
echo [INFO] Python in environment: %CURRENT_PYTHON%
if /I not "%CURRENT_PYTHON%"=="3.12.11" (
    echo [INFO] Attempting to install/upgrade Python to 3.12.11...
    call "%CONDA_BAT%" install --yes --channel conda-forge --name %COMFYUI_ENV_NAME% python=3.12.11
    if %ERRORLEVEL% neq 0 (
        echo [WARNING] Could not set Python to 3.12.11. Continuing with %CURRENT_PYTHON%.
    ) else (
        echo [INFO] Re-activating environment with Python 3.12.11...
        call "%CONDA_BAT%" activate %COMFYUI_ENV_NAME%
        for /f %%v in ('python -c "import sys;print('.'.join(map(str, sys.version_info[:3])))"') do set "CURRENT_PYTHON=%%v"
        echo [INFO] Python now: %CURRENT_PYTHON%
    )
)

REM --------------------------------------------------------------------
REM [8] Clone or update the ComfyUI repository.
if not exist "%COMFYUI_DIR%\.git" (
    echo [INFO] Cloning ComfyUI repository into "%COMFYUI_DIR%"...
    mkdir "%COMFYUI_DIR%"
    pushd "%COMFYUI_DIR%"
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git .
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
    git stash push -m "Auto-stash before update"
    REM Determine default branch (master/main) robustly
    set "DEFAULT_BRANCH="
    for /f "tokens=4 delims=/" %%b in ('git rev-parse --abbrev-ref origin/HEAD 2^>nul') do set "DEFAULT_BRANCH=%%b"
    if not defined DEFAULT_BRANCH (
        git remote set-head origin -a >nul 2>&1
        for /f "tokens=4 delims=/" %%b in ('git rev-parse --abbrev-ref origin/HEAD 2^>nul') do set "DEFAULT_BRANCH=%%b"
    )
    if not defined DEFAULT_BRANCH (
        for /f "tokens=2 delims=:" %%b in ('git remote show origin ^| findstr /C:"HEAD branch"') do set "DEFAULT_BRANCH=%%b"
        set "DEFAULT_BRANCH=!DEFAULT_BRANCH: =!"
    )
    if not defined DEFAULT_BRANCH set "DEFAULT_BRANCH=master"
    echo [INFO] Detected default branch: !DEFAULT_BRANCH!
    git fetch --depth 1 origin !DEFAULT_BRANCH!
    git reset --hard origin/!DEFAULT_BRANCH!
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
            git clone --depth 1 "!REPO_URL!" "!TARGET_DIR!"
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
            git stash push -m "Auto-stash before update"
            git pull --ff-only
            popd
        )
    )
)
popd

REM --------------------------------------------------------------------
REM [10] Upgrade pip and install pre-update packages.
echo [INFO] Upgrading pip and installing pre-update packages...
python -m pip install --no-user --upgrade pip setuptools wheel
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to upgrade pip and core packages. Aborting.
    goto END
)
python -m pip install --no-user python-dotenv requests psutil
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install pre-update packages. Aborting.
    goto END
)

REM --------------------------------------------------------------------
REM [11] Install main ComfyUI requirements (before accelerator libs).
cd /d "%COMFYUI_DIR%"
if exist "requirements.txt" (
    echo [INFO] Installing main ComfyUI requirements...
    python -m pip install --no-user -r requirements.txt
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to install main ComfyUI requirements. Aborting.
        goto END
    )
) else (
    echo [INFO] No requirements.txt found in ComfyUI root; skipping.
)

REM --------------------------------------------------------------------
REM [12] Pre-accelerator: install custom node requirements and run install scripts.
if exist "%CUSTOM_NODES_DIR%" (
    echo [INFO] Processing custom nodes requirements and install scripts...
    pushd "%CUSTOM_NODES_DIR%"
    for /d %%D in (*) do (
        if exist "%%D" (
            echo [INFO] Checking custom node: %%D
            REM Install any requirements*.txt files found
            for %%R in ("%%D\requirements*.txt") do (
                if exist "%%~fR" (
                    echo [INFO] Installing requirements: %%~nxR
                    python -m pip install --no-user -r "%%~fR"
                    if !ERRORLEVEL! neq 0 (
                        echo [WARNING] Failed to install requirements from %%~nxR (continuing)
                    )
                )
            )
            REM Run install.bat if present
            if exist "%%D\install.bat" (
                echo [INFO] Running install.bat in %%D
                pushd "%%D"
                call install.bat
                if !ERRORLEVEL! neq 0 (
                    echo [WARNING] install.bat in %%D returned a non-zero exit code (continuing)
                )
                popd
            )
        )
    )
    popd
) else (
    echo [INFO] No custom_nodes directory found at %CUSTOM_NODES_DIR%.
)

REM --------------------------------------------------------------------
REM [13] Install onnxruntime for GPU (with fallback to CPU version).
echo [INFO] Installing onnxruntime for GPU...
python -m pip install --no-user onnxruntime-gpu
if %ERRORLEVEL% neq 0 (
    echo [WARNING] Failed to install onnxruntime-gpu, falling back to CPU version...
    python -m pip install --no-user onnxruntime
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to install onnxruntime. Aborting.
        goto END
    )
)

REM --------------------------------------------------------------------
REM [14] Install PyTorch for CUDA 12.8 (preferred), fallback to 12.6.
echo [INFO] Installing PyTorch (CUDA 12.8) and related packages...
python -m pip install --no-user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
if %ERRORLEVEL% neq 0 (
    echo [WARNING] CUDA 12.8 wheels failed. Trying CUDA 12.6...
    python -m pip install --no-user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to install PyTorch for CUDA 12.6 as fallback. Aborting.
        goto END
    )
)

REM Verify PyTorch installation
echo [INFO] Verifying PyTorch installation...
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); import platform; print('Python:', platform.python_version())"
if %ERRORLEVEL% neq 0 (
    echo [WARNING] PyTorch verification failed, but continuing...
)

REM --------------------------------------------------------------------

REM --------------------------------------------------------------------
REM [15] Final verification and cleanup.
echo [INFO] Performing final verification...
cd /d "%COMFYUI_DIR%"
python -c "import sys; print(f'Python version: {sys.version}')"
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device count: {torch.cuda.device_count() if torch.cuda.is_available() else 0}')"

REM Clean pip cache to save space
echo [INFO] Cleaning pip cache...
python -m pip cache purge

REM --------------------------------------------------------------------
REM [16] Completion message.
echo.
echo [SUCCESS] Finished installation/update process.
echo Environment Details:
echo   - Python Version: Use 'python --version' in the activated environment
echo   - ComfyUI Location: %COMFYUI_DIR%
echo   - Environment Name: %COMFYUI_ENV_NAME%
echo.
echo Next steps:
echo   - Use launch_comfyui.bat to start ComfyUI.
echo   - Check the logs folder for any issues.
echo   - Activate environment with: conda activate %COMFYUI_ENV_NAME%
pause
exit /b 0

:END
echo.
echo [ERROR] Installer encountered a problem. Check above logs.
pause
exit /b 1
