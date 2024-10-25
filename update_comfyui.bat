@echo off
:: Detect the user's home directory
set "USER_HOME=%USERPROFILE%"
:: Define the Conda path and environment name
set "CONDA_PATH=%USER_HOME%\miniconda3"
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)
set "COMFYUI_ENV_NAME=ComfyUI"
:: Define the ComfyUI directory
set COMFYUI_DIR=%USER_HOME%\ComfyUI
:: Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"
:: Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
call "%CONDA_PATH%\Scripts\activate.bat" %COMFYUI_ENV_NAME%
:: Change to the ComfyUI directory
echo Changing to the ComfyUI directory...
cd %COMFYUI_DIR%
:: Pull the latest changes for the base ComfyUI repository
echo Pulling updates for ComfyUI...
cmd.exe /c git pull
:: Reinstall the base requirements for ComfyUI
IF EXIST requirements.txt (
    echo Reinstalling requirements for ComfyUI...
    cmd.exe /c pip install --no-cache-dir -r requirements.txt
)
:: Update each plugin in the custom_nodes directory
echo Updating custom nodes...
cd custom_nodes
for /D %%d in (*) do (
    echo Updating %%d...
    cd %%d
    cmd.exe /c git pull
    :: Reinstall requirements if present
    IF EXIST requirements.txt (
        echo Reinstalling requirements for %%d...
        cmd.exe /c pip install --no-cache-dir -r requirements.txt
    )
    cd ..
)
:: Final message
echo Update complete. All repositories have been pulled and dependencies reinstalled.
pause
