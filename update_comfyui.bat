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
call conda activate ComfyUI
cd %COMFYUI_DIR%
echo Updating ComfyUI base repository...
git pull
IF EXIST requirements.txt (
    echo Updating ComfyUI base requirements...
    call python -m pip install --no-cache-dir -r requirements.txt
)
cd %COMFYUI_DIR%\custom_nodes
for /D %%d in (*) do (
    echo Updating %%d repository...
    cd %%d
    git pull
    IF EXIST requirements.txt (
        echo Installing requirements for %%d...
        call python -m pip install --no-cache-dir -r requirements.txt
    )
    IF EXIST install.py (
        echo Running install.py for %%d...
        call python install.py
    )
    IF EXIST install.bat (
        echo Running install.bat for %%d...
        call install.bat
    )
    cd ..
)
echo Update complete.
pause
