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
:: Define the ComfyUI directory
set COMFYUI_DIR=%USER_HOME%\ComfyUI
:: Backup the existing models directory if it exists
IF EXIST %COMFYUI_DIR%\models (
    echo Backing up existing models directory...
    move /Y %COMFYUI_DIR%\models %USER_HOME%\comfyui_models_backup
)
:: Remove the existing Conda environment if it exists
echo Checking for existing Conda environment named ComfyUI...
cmd.exe /c conda env list | findstr "ComfyUI" >nul
IF %ERRORLEVEL% EQU 0 (
    echo Removing existing Conda environment named ComfyUI...
    conda env remove -n ComfyUI -y
)
:: Remove the ComfyUI environment folder if it exists but is not recognized as an environment
IF EXIST "%CONDA_PATH%\envs\ComfyUI" (
    echo Cleaning up remnants of the ComfyUI environment...
    rmdir /S /Q "%CONDA_PATH%\envs\ComfyUI"
)
:: Create a new Conda environment with the latest Python 3.10
echo Creating a new Conda environment named ComfyUI with Python 3.10...
cmd.exe /c conda create -n ComfyUI python=3.10 -y
:: Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
cmd.exe /c call "%CONDA_PATH%\Scripts\activate.bat" ComfyUI
:: Install Gradio, Streamlit, and additional libraries from conda-forge
echo Installing Gradio, Streamlit, and additional libraries from conda-forge...
cmd.exe /c conda install -c conda-forge gradio streamlit webcolors numba kornia gguf scikit-image opencv einops transformers ffmpeg scipy observatoire-mobilite::nssm -y
:: Install xformers first using pip to ensure compatibility
echo Installing xformers with CUDA support...
cmd.exe /c pip install -U xformers --index-url https://download.pytorch.org/whl/cu124
:: Install PyTorch with CUDA support
echo Installing PyTorch and related libraries...
cmd.exe /c conda install pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch -c nvidia -y
cmd.exe /c conda install conda-forge::bitsandbytes -y
:: Install Spandrel for graph neural networks
cmd.exe /c pip install -U spandrel
:: Downgrade numpy to <2.0 using conda-forge before installing plugins
echo Downgrading numpy to a version less than 2.0...
cmd.exe /c conda install -c conda-forge "numpy<2.0" -y
:: Delete the ComfyUI directory if it exists
IF EXIST %COMFYUI_DIR% (
    echo Removing existing ComfyUI directory...
    rmdir /S /Q %COMFYUI_DIR%
)
:: Create the ComfyUI directory
mkdir %COMFYUI_DIR%
:: Change to the ComfyUI directory
cd %COMFYUI_DIR%
:: Clone the ComfyUI repository
echo Cloning ComfyUI repository...
cmd.exe /c git clone https://github.com/comfyanonymous/ComfyUI.git .
:: Install the base requirements for ComfyUI
IF EXIST requirements.txt (
    echo Installing ComfyUI base requirements...
    cmd.exe /c pip install --no-cache-dir -r requirements.txt
)
:: Delete the custom_nodes directory if it exists
IF EXIST %COMFYUI_DIR%\custom_nodes (
    echo Removing existing custom_nodes directory...
    rmdir /S /Q %COMFYUI_DIR%\custom_nodes
)
:: Create the custom_nodes directory
mkdir %COMFYUI_DIR%\custom_nodes
cd custom_nodes
:: Clone each custom node
echo Cloning custom nodes...
cmd.exe /c git clone https://github.com/ltdrdata/ComfyUI-Manager.git
cmd.exe /c git clone https://github.com/rgthree/rgthree-comfy.git
cmd.exe /c git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
cmd.exe /c git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
cmd.exe /c git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
cmd.exe /c git clone https://github.com/city96/ComfyUI_ExtraModels.git
cmd.exe /c git clone https://github.com/city96/ComfyUI-GGUF.git
cmd.exe /c git clone https://github.com/Gourieff/comfyui-reactor-node.git
:: Iterate over each custom node to install its dependencies and run install.py if present
for /D %%d in (*) do (
    IF EXIST %%d\requirements.txt (
        echo Installing requirements for %%d...
        cmd.exe /c pip install --no-cache-dir -r %%d\requirements.txt
    )
    IF EXIST %%d\install.py (
        echo Running install.py for %%d...
        cmd.exe /c python %%d\install.py
    )
)
:: Uninstall onnxruntime and install onnxruntime-gpu (should be done after every plugin install process)
echo Replacing onnxruntime with onnxruntime-gpu...
cmd.exe /c pip uninstall -y onnxruntime
cmd.exe /c pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/
:: Reinstall any packages that were removed during the custom node installation (a common issue with installing custom nodes)
echo Reinstalling any removed packages...
cmd.exe /c pip install -U spandrel
cmd.exe /c pip install bitsandbytes --prefer-binary --extra-index-url=https://jllllll.github.io/bitsandbytes-windows-webui
:: Restore the models directory if it was backed up, merging with existing files
IF EXIST %USER_HOME%\comfyui_models_backup (
    echo Restoring models directory and merging with existing files...
    xcopy /E /H /Y %USER_HOME%\comfyui_models_backup\* %COMFYUI_DIR%\models\
    rmdir /S /Q %USER_HOME%\comfyui_models_backup
)
:: Copy comfy.settings.json into the ComfyUI user/default directory, creating the directory if needed
echo Copying comfy.settings.json to ComfyUI user/default directory...
IF NOT EXIST "%COMFYUI_DIR%\user\default" (
    mkdir "%COMFYUI_DIR%\user\default"
)
copy /Y "%~dp0\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
:: Copy manager_config.ini to the ComfyUI-Manager directory as config.ini, creating the directory if needed
echo Copying manager_config.ini to ComfyUI-Manager as config.ini...
IF NOT EXIST "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager" (
    mkdir "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager"
)
copy /Y "%~dp0\manager_config.ini" "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini"
echo Installation complete. Use launch_comfyui.bat to start ComfyUI.
pause
