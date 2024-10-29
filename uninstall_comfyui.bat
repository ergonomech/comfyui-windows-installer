@echo off
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=C:\ProgramData\miniconda3"
)
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=C:\ProgramData\anaconda3"
)
set COMFYUI_DIR=%USER_HOME%\ComfyUI
echo Checking for existing Conda environment named ComfyUI...
call conda env list | findstr "ComfyUI" >nul
IF %ERRORLEVEL% EQU 0 (
    echo Removing Conda environment named ComfyUI...
    call conda env remove -n ComfyUI -y
)
IF EXIST "%CONDA_PATH%\envs\ComfyUI" (
    echo Cleaning up any remaining files from the ComfyUI environment...
    rmdir /S /Q "%CONDA_PATH%\envs\ComfyUI"
)
IF EXIST %COMFYUI_DIR% (
    echo Removing the ComfyUI directory and all installed plugins and models...
    rmdir /S /Q %COMFYUI_DIR%
)
echo Uninstallation complete.
pause
