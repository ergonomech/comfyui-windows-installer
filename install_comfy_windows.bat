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
IF EXIST %COMFYUI_DIR%\models (
    echo Backing up existing models directory...
    call move /Y %COMFYUI_DIR%\models %USER_HOME%\comfyui_models_backup
)
echo Checking for existing Conda environment named ComfyUI...
call conda env list | findstr "ComfyUI" >nul
IF %ERRORLEVEL% EQU 0 (
    echo Removing existing Conda environment named ComfyUI and moving on to create a new one...
    call conda env remove -n ComfyUI -y
)
IF EXIST "%CONDA_PATH%\envs\ComfyUI" (
    echo Cleaning up remnants of the ComfyUI environment...
    call rmdir /S /Q "%CONDA_PATH%\envs\ComfyUI"
)
echo Creating a new Conda environment named ComfyUI with Python 3.10...
call conda create --dev -q -n ComfyUI python=3.10 -y
call conda activate ComfyUI
echo Installing Gradio, Streamlit, and additional libraries from conda-forge...
call conda install -c conda-forge gradio streamlit webcolors numba kornia gguf scikit-image opencv einops transformers ffmpeg scipy observatoire-mobiliteecho Installing xformers with CUDA support...
call python -m pip install -U xformers --index-url https://download.pytorch.org/whl/cu124
echo Installing PyTorch and related libraries...
call conda install pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch -c nvidia -y
echo Downgrading numpy to a version less than 2.0...
call conda install -c conda-forge "numpy<2.0" -y
IF EXIST %COMFYUI_DIR% (
    echo Removing existing ComfyUI directory...
    rmdir /S /Q %COMFYUI_DIR%
)
mkdir %COMFYUI_DIR%
cd %COMFYUI_DIR%
echo Cloning ComfyUI repository...
git clone https://github.com/comfyanonymous/ComfyUI.git .
IF EXIST requirements.txt (
    echo Installing ComfyUI base requirements...
    call python -m pip install --no-cache-dir -r requirements.txt
)
IF EXIST %COMFYUI_DIR%\custom_nodes (
    echo Removing existing custom_nodes directory...
    rmdir /S /Q %COMFYUI_DIR%\custom_nodes
)
mkdir %COMFYUI_DIR%\custom_nodes
cd custom_nodes
echo Cloning custom nodes...
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
git clone https://github.com/city96/ComfyUI_ExtraModels.git
git clone https://github.com/city96/ComfyUI-GGUF.git
git clone https://github.com/Gourieff/comfyui-reactor-node.git
for /D %%d in (*) do (
    IF EXIST %%d\requirements.txt (
        echo Installing requirements for %%d...
        call python -m pip install --no-cache-dir -r %%d\requirements.txt
    )
    IF EXIST %%d\install.py (
        echo Running install.py for %%d...
        call python %%d\install.py
    )
    IF EXIST %%d\install.bat (
        echo Running install.bat for %%d...
        install.bat
    )
)
echo Replacing onnxruntime with onnxruntime-gpu...
call python -m pip uninstall -y onnxruntime
call python -m pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/
echo Reinstalling any removed packages...
call python -m pip install -U spandrel
call python -m pip install bitsandbytes --prefer-binary --extra-index-url=https://jllllll.github.io/bitsandbytes-windows-webui
IF EXIST %USER_HOME%\comfyui_models_backup (
    echo Restoring models directory and merging with existing files...
    xcopy /E /H /Y %USER_HOME%\comfyui_models_backup\* %COMFYUI_DIR%\models\
    rmdir /S /Q %USER_HOME%\comfyui_models_backup
)
echo Copying comfy.settings.json to ComfyUI user/default directory...
IF NOT EXIST "%COMFYUI_DIR%\user\default" (
    mkdir "%COMFYUI_DIR%\user\default"
)
copy /Y "%~dp0\comfy.settings.json" "%COMFYUI_DIR%\user\default\comfy.settings.json"
echo Copying manager_config.ini to ComfyUI-Manager as config.ini...
IF NOT EXIST "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager" (
    mkdir "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager"
)
copy /Y "%~dp0\manager_config.ini" "%COMFYUI_DIR%\custom_nodes\ComfyUI-Manager\config.ini"
echo Installation complete. Use launch_comfyui.bat to start ComfyUI.
pause
