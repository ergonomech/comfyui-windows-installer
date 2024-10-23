@echo off
:: ===========================
:: ComfyUI Updater Script
:: ===========================
echo Updating ComfyUI and its plugins...

:: Set paths and environment names
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
set "COMFYUI_ENV_NAME=ComfyUI"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"
set "PLUGINS_DIR=%COMFYUI_DIR%\custom_nodes"

:: Activate the Conda environment
echo Activating the Conda environment...
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"
call "%CONDA_PATH%\Scripts\activate.bat" %COMFYUI_ENV_NAME%

:: Navigate to the ComfyUI directory and update the main repository
if exist "%COMFYUI_DIR%" (
    cd "%COMFYUI_DIR%"
    echo Pulling the latest changes for ComfyUI...
    git pull origin main
) else (
    echo ComfyUI directory not found, cannot update.
    pause
    exit /b 1
)

:: Iterate through each plugin directory and update
if exist "%PLUGINS_DIR%" (
    cd "%PLUGINS_DIR%"
    for /d %%D in (*) do (
        if exist "%%D\.git" (
            echo Updating plugin in %%D...
            cd "%%D"
            git pull origin main
            cd ..
        )
    )
) else (
    echo Plugins directory not found, cannot update plugins.
)

echo Update complete.
pause
