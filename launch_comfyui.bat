@echo off

:: ===========================
:: Configurable Variables
:: ===========================

:: Set paths and environment names
set "USER_HOME=%USERPROFILE%"
set "CONDA_PATH=%USER_HOME%\miniconda3"
set "COMFYUI_ENV_NAME=ComfyUI"
set "COMFYUI_DIR=%USER_HOME%\ComfyUI"
set "MODEL_BASE_PATH=T:\models"
set "INPUT_DIR=D:\temp\ComfyUI\input"
set "OUTPUT_DIR=D:\temp\ComfyUI\output"
set "TEMP_DIR=D:\temp\ComfyUI\temp"

:: Environment variables for PyTorch, CUDA, and TensorFlow
set "PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
set "KMP_DUPLICATE_LIB_OK=TRUE"
set "CUDA_LAUNCH_BLOCKING=1"
set "TF_FORCE_GPU_ALLOW_GROWTH=true"
set "TF_CPP_MIN_LOG_LEVEL=3"
set "TF_XLA_FLAGS=--tf_xla_auto_jit=2 --tf_xla_cpu_global_jit"
set "PYTHONWARNINGS=ignore"
set "TORCH_USE_CUDA_DSA=1"

:: ===========================
:: Script Execution
:: ===========================

:: Log script start
echo Starting ComfyUI launcher...
echo Using model base path: %MODEL_BASE_PATH%

:: Check for existing Conda installation
IF NOT EXIST "%CONDA_PATH%" (
    set "CONDA_PATH=%USER_HOME%\anaconda3"
)

:: Temporarily add Conda to the PATH for the current session
set "PATH=%CONDA_PATH%\Scripts;%CONDA_PATH%\Library\bin;%CONDA_PATH%\condabin;%PATH%"

:: Activate the Conda environment directly using activate.bat
echo Activating the Conda environment...
call "%CONDA_PATH%\Scripts\activate.bat" %COMFYUI_ENV_NAME%

:: Change to the ComfyUI working directory
echo Setting working directory to %COMFYUI_DIR%...
cd %COMFYUI_DIR%

:: Set environment variables for PyTorch, CUDA, and TensorFlow
echo Setting environment variables...
set PYTORCH_CUDA_ALLOC_CONF=%PYTORCH_CUDA_ALLOC_CONF%
set KMP_DUPLICATE_LIB_OK=%KMP_DUPLICATE_LIB_OK%
set CUDA_LAUNCH_BLOCKING=%CUDA_LAUNCH_BLOCKING%
set TF_FORCE_GPU_ALLOW_GROWTH=%TF_FORCE_GPU_ALLOW_GROWTH%
set TF_CPP_MIN_LOG_LEVEL=%TF_CPP_MIN_LOG_LEVEL%
set TF_XLA_FLAGS=%TF_XLA_FLAGS%
set PYTHONWARNINGS=%PYTHONWARNINGS%
set TORCH_USE_CUDA_DSA=%TORCH_USE_CUDA_DSA%

:: Create or update the extra_model_paths.yaml file next to main.py
echo Creating or updating extra_model_paths.yaml...
(
    echo comfyui:
    echo   base_path: %MODEL_BASE_PATH%
    echo   is_default: true
    echo   checkpoints: checkpoints
    echo   clip: clip
    echo   clip_vision: clip_vision
    echo   configs: configs
    echo   controlnet: controlnet
    echo   diffusion_models: ^| 
    echo     diffusion_models
    echo     unet
    echo   embeddings: embeddings
    echo   loras: loras
    echo   upscale_models: upscale_models
    echo   vae: vae
) > "%COMFYUI_DIR%\extra_model_paths.yaml"

:: Log starting the ComfyUI server
echo Starting ComfyUI server with custom directories...
echo Input directory: %INPUT_DIR%
echo Output directory: %OUTPUT_DIR%
echo Temp directory: %TEMP_DIR%

:: Run ComfyUI with --listen and specified directories
python main.py --listen --lowvram --reserve-vram 2 --preview-method auto --enable-cors-header --force-channels-last --dont-upcast-attention --input-directory "%INPUT_DIR%" --output-directory "%OUTPUT_DIR%" --temp-directory "%TEMP_DIR%"

:: Pause to keep the window open after the server starts
pause
