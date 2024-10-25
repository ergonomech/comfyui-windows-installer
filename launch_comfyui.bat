@echo off
set "CONDA_ENV_NAME=ComfyUI"
set "PYTHON_SCRIPT=comfyui_windows.py"
echo Activating Conda environment...
call conda activate %CONDA_ENV_NAME%
echo Running Python script...
cmd.exe /c python %PYTHON_SCRIPT%
pause
