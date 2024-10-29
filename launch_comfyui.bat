@echo off
set "CONDA_ENV_NAME=ComfyUI"
set "PYTHON_SCRIPT=comfyui_windows.py"
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
echo Activating Conda environment...
call conda activate %CONDA_ENV_NAME%
echo Running Python script...
call pip install python-dotenv
call python "%SCRIPT_DIR%%PYTHON_SCRIPT%"
pause
