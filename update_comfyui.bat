@echo off

:: ===========================
:: Configurable Variables
:: ===========================
set "USER_HOME=%USERPROFILE%"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"
set "PLUGINS_DIR=%COMFYUI_DIR%\custom_nodes"
set "CONDA_ENV_NAME=ComfyUI"
set "CONDA_PATH=%USER_HOME%\miniconda3"

:: ===========================
:: Script Execution
:: ===========================

:: Log script start
echo Starting ComfyUI update...
echo ComfyUI directory: %COMFYUI_DIR%
echo Plugins directory: %PLUGINS_DIR%

:: Check for existing Conda installation
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)

:: Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"

:: Activate the Conda environment
echo Activating the Conda environment...
call "%CONDA_PATH%\Scripts\activate.bat" %CONDA_ENV_NAME%

:: Change to the ComfyUI working directory
echo Changing to the ComfyUI directory...
cd /d "%COMFYUI_DIR%"

:: Pull the latest changes for ComfyUI
echo Updating ComfyUI...
git pull origin main

:: Reinstall base requirements
if exist requirements.txt (
    echo Installing base requirements...
    pip install -r requirements.txt
)

:: Update all plugins
echo Updating plugins...
for /D %%p in ("%PLUGINS_DIR%\*") do (
    echo Updating plugin in directory %%p...
    cd /d "%%p"
    git pull origin main
    if exist requirements.txt (
        echo Installing plugin requirements for %%p...
        pip install -r requirements.txt
    )
)

:: Change back to the ComfyUI directory
cd /d "%COMFYUI_DIR%"

:: Deactivate the Conda environment
echo Deactivating the Conda environment...
call "%CONDA_PATH%\Scripts\deactivate.bat"

:: Log update completion
echo Update completed successfully!
pause
