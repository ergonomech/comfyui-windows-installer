@echo off
:: ===========================
:: ComfyUI Uninstaller Script
:: ===========================
echo Uninstalling ComfyUI and its environment...

:: Set paths and environment names
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
set "COMFYUI_ENV_NAME=ComfyUI"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"
set "LOG_DIR=%USER_HOME%\ComfyUI\logs"

:: Deactivate the Conda environment if active
echo Deactivating the Conda environment...
call "%CONDA_PATH%\Scripts\deactivate.bat"

:: Remove the Conda environment
echo Removing Conda environment %COMFYUI_ENV_NAME%...
call "%CONDA_PATH%\Scripts\activate.bat" base
conda env remove -n %COMFYUI_ENV_NAME% -y

:: Remove ComfyUI directory
if exist "%COMFYUI_DIR%" (
    echo Deleting ComfyUI directory: %COMFYUI_DIR%...
    rmdir /s /q "%COMFYUI_DIR%"
) else (
    echo ComfyUI directory not found, skipping deletion.
)

:: Remove log directory
if exist "%LOG_DIR%" (
    echo Deleting log directory: %LOG_DIR%...
    rmdir /s /q "%LOG_DIR%"
) else (
    echo Log directory not found, skipping deletion.
)

echo Uninstallation complete.
pause
