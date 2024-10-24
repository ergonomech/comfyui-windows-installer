@echo off
REM Detect the user's home directory
set "USER_HOME=%USERPROFILE%"

REM Determine the default Conda path (modify if your installation is elsewhere)
set "CONDA_PATH=%USER_HOME%\miniconda3"
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)

REM Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"

REM Remove the existing Conda environment if it exists
conda env list | findstr "ComfyUI"
IF %ERRORLEVEL% EQU 0 (
    echo Removing existing Conda environment named ComfyUI...
    conda env remove -n ComfyUI -y
)

REM Create a new Conda environment with the latest Python 3.10
echo Creating a new Conda environment named ComfyUI with Python 3.10...
conda create -n ComfyUI python=3.10 -y

REM Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
call "%CONDA_PATH%\Scripts\activate.bat" ComfyUI

REM Install Gradio, Streamlit, and additional libraries from conda-forge
echo Installing Gradio, Streamlit, and additional libraries from conda-forge...
conda install -c conda-forge gradio streamlit numba scikit-image opencv transformers scipy -y

REM Install xformers first using pip to ensure compatibility
echo Installing xformers with CUDA support...
pip install -U xformers --index-url https://download.pytorch.org/whl/cu124

REM Install PyTorch with CUDA support
echo Installing PyTorch and related libraries...
conda install pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch -c nvidia -y

REM Downgrade numpy to <2.0 using conda-forge before installing plugins
echo Downgrading numpy to a version less than 2.0...
conda install -c conda-forge "numpy<2.0" -y

REM Set the working directory to user home
set COMFYUI_DIR=%USERPROFILE%\ComfyUI

REM Delete the ComfyUI directory if it exists
IF EXIST %COMFYUI_DIR% (
    echo Removing existing ComfyUI directory...
    rmdir /S /Q %COMFYUI_DIR%
)

REM Create the ComfyUI directory
mkdir %COMFYUI_DIR%

REM Change to the ComfyUI directory
cd %COMFYUI_DIR%

REM Clone the ComfyUI repository
echo Cloning ComfyUI repository...
git clone https://github.com/comfyanonymous/ComfyUI.git .

REM Install the base requirements for ComfyUI
IF EXIST requirements.txt (
    echo Installing ComfyUI base requirements...
    pip install --no-cache-dir -r requirements.txt
)

REM Delete the custom_nodes directory if it exists
IF EXIST %COMFYUI_DIR%\custom_nodes (
    echo Removing existing custom_nodes directory...
    rmdir /S /Q %COMFYUI_DIR%\custom_nodes
)

REM Create the custom_nodes directory
mkdir %COMFYUI_DIR%\custom_nodes
cd custom_nodes

REM Clone each custom node
echo Cloning custom nodes...
git clone https://github.com/ltdrdata/ComfyUI-Manager.git
git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/Gourieff/comfyui-reactor-node.git
git clone https://github.com/WASasquatch/was-node-suite-comfyui.git
git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
git clone https://github.com/Anibaaal/ComfyUI-UX-Nodes.git
git clone https://github.com/city96/ComfyUI_ExtraModels.git
git clone https://github.com/city96/ComfyUI-GGUF.git
git clone https://github.com/DenkingOfficial/ComfyUI_UNet_bitsandbytes_NF4.git
git clone https://github.com/comfyanonymous/ComfyUI_bitsandbytes_NF4.git


REM Iterate over each custom node to install its dependencies and run install.py if present
for /D %%d in (*) do (
    IF EXIST %%d\requirements.txt (
        echo Installing requirements for %%d...
        pip install --no-cache-dir -r %%d\requirements.txt
    )
    IF EXIST %%d\install.py (
        echo Running install.py for %%d...
        python %%d\install.py
    )
)

REM Uninstall onnxruntime and install onnxruntime-gpu
echo Replacing onnxruntime with onnxruntime-gpu...
pip uninstall -y onnxruntime
pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

echo Installation complete. Use launch_comfyui.bat to start ComfyUI.
pause
