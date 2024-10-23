@echo off
:: Activating the Conda environment
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
set "CONDA_ENV_NAME=ComfyUI"
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"
call "%CONDA_PATH%\Scripts\activate.bat" %CONDA_ENV_NAME%

:: Launching the Python script
python comfyui_windows.py
pause
