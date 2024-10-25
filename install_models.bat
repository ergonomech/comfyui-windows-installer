@echo off
:: Detect the user's home directory
set "USER_HOME=%USERPROFILE%"
:: Determine the default Conda path (modify if your installation is elsewhere)
set "CONDA_PATH=%USER_HOME%\miniconda3"
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)
:: Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"
:: Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
cmd.exe /c call "%CONDA_PATH%\Scripts\activate.bat" ComfyUI
:: Run the model installation script
echo Running Python script...
cmd.exe /c python install_models.py
pause
