@echo off

:: ===========================
:: Configurable Variables
:: ===========================

:: Set paths and environment names
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
set "COMFYUI_ENV_NAME=ComfyUI"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"
set "PYTHON_VERSION=3.10"
set "CUDA_VERSION=12.4"

:: Custom package repositories and versions
set "ONNX_GPU_REPO=https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/"
set "XFORMERS_INDEX_URL=https://download.pytorch.org/whl/cu124"
set "GRADIO_VERSION=latest"
set "STREAMLIT_VERSION=latest"
set "NUMPY_VERSION=<2.0"

:: ===========================
:: Script Execution
:: ===========================

:: Log script start
echo Starting ComfyUI installation script...
echo Using Python version %PYTHON_VERSION% with CUDA version %CUDA_VERSION%.

:: Check for existing Conda installation
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)

:: Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"

:: Remove the existing Conda environment if it exists
conda env list | findstr "%COMFYUI_ENV_NAME%"
IF %ERRORLEVEL% EQU 0 (
    echo Removing existing Conda environment named %COMFYUI_ENV_NAME%...
    conda env remove -n %COMFYUI_ENV_NAME% -y
)

:: Create a new Conda environment with the specified Python version
echo Creating a new Conda environment named %COMFYUI_ENV_NAME% with Python %PYTHON_VERSION%...
conda create -n %COMFYUI_ENV_NAME% python=%PYTHON_VERSION% -y

:: Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
call "%CONDA_PATH%\Scripts\activate.bat" %COMFYUI_ENV_NAME%

:: Install Gradio, Streamlit, and additional libraries from conda-forge
echo Installing Gradio, Streamlit, and additional libraries from conda-forge...
conda install -c conda-forge gradio=%GRADIO_VERSION% streamlit=%STREAMLIT_VERSION% numba scikit-image opencv transformers scipy -y

:: Install xformers using pip with the specified index URL
echo Installing xformers with CUDA support...
pip install -U xformers --index-url %XFORMERS_INDEX_URL%

:: Install PyTorch with CUDA support
echo Installing PyTorch and related libraries...
conda install pytorch torchvision torchaudio pytorch-cuda=%CUDA_VERSION% -c pytorch -c nvidia -y

:: Downgrade numpy before installing plugins
echo Downgrading numpy to version %NUMPY_VERSION%...
conda install -c conda-forge "numpy%NUMPY_VERSION%" -y

:: Set up the ComfyUI directory and repository
IF EXIST %COMFYUI_DIR% (
    echo Removing existing ComfyUI directory...
    rmdir /S /Q %COMFYUI_DIR%
)
mkdir %COMFYUI_DIR%
cd %COMFYUI_DIR%

:: Clone the ComfyUI repository
echo Cloning ComfyUI repository...
git clone https://github.com/comfyanonymous/ComfyUI.git .

:: Install the base requirements for ComfyUI if the requirements.txt file exists
IF EXIST requirements.txt (
    echo Installing ComfyUI base requirements...
    pip install --no-cache-dir -r requirements.txt
)

:: Delete the custom_nodes directory if it exists
IF EXIST %COMFYUI_DIR%\custom_nodes (
    echo Removing existing custom_nodes directory...
    rmdir /S /Q %COMFYUI_DIR%\custom_nodes
)

:: Create the custom_nodes directory and change to it
mkdir %COMFYUI_DIR%\custom_nodes
cd custom_nodes

:: Clone each custom node and install its dependencies if necessary
echo Cloning and setting up custom nodes...
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

:: Replace onnxruntime with onnxruntime-gpu using the specified repository
echo Replacing onnxruntime with onnxruntime-gpu...
pip uninstall -y onnxruntime
pip install onnxruntime-gpu --extra-index-url %ONNX_GPU_REPO%

:: Log script completion
echo Installation complete. Use launch_comfyui.bat to start ComfyUI.
pause
