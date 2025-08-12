#!/bin/bash

# === ComfyUI Automated Installer (Linux, Bash) ===
# This script installs/updates ComfyUI and its dependencies in a Python venv environment.
# It supports Ubuntu and uses only public Git repos.
# Run this script from the directory where you want ComfyUI installed.

set -e

# Error handling function
handle_error() {
    echo "[ERROR] $1"
    exit 1
}

# --------------------------------------------------------------------
# [1] Check for elevated privileges (optional)
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[INFO] Running without elevated privileges."
else
    echo "[INFO] Running with elevated privileges."
fi

# --------------------------------------------------------------------
# [2] Verify required programs: Git and Python 3.12 must be available.
need_apt_update=0
if ! command -v git &> /dev/null; then
    echo "[INFO] Git is not installed. Will install."
    need_apt_update=1
    install_git=1
fi
if ! command -v python3.12 &> /dev/null; then
    echo "[INFO] Python 3.12 is not installed. Will install."
    need_apt_update=1
    install_python=1
fi
# Check if build tools are needed for development packages
if ! command -v ninja &> /dev/null; then
    echo "[INFO] Development tools are not installed. Will install."
    need_apt_update=1
    install_dev_tools=1
fi
if [[ $need_apt_update -eq 1 ]]; then
    sudo apt update
    [[ $install_git -eq 1 ]] && sudo apt install -y git
    [[ $install_python -eq 1 ]] && sudo apt install -y python3.12 python3.12-venv python3-pip
    [[ $install_dev_tools -eq 1 ]] && sudo apt install -y ninja-build build-essential python3.12-dev
    echo "[INFO] Required programs installed successfully."
fi

# --------------------------------------------------------------------
# [3] Set environment variables for the installation.
COMFYUI_ENV_NAME="ComfyUI"
COMFYUI_DIR="$HOME/$COMFYUI_ENV_NAME"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
PYTHON_BIN="python3.12"
PIP_BIN="pip"
echo "[INFO] ComfyUI environment name: $COMFYUI_ENV_NAME"
echo "[INFO] ComfyUI directory: $COMFYUI_DIR"

# --------------------------------------------------------------------
# [4] Create a Python virtual environment if it doesn't exist.
if [[ ! -d "$COMFYUI_DIR/venv" ]]; then
    echo "[INFO] Creating Python virtual environment..."
    mkdir -p "$COMFYUI_DIR" || handle_error "Failed to create ComfyUI directory"
    $PYTHON_BIN -m venv "$COMFYUI_DIR/venv" || handle_error "Failed to create virtual environment"
    echo "[INFO] Virtual environment created successfully."
else
    echo "[INFO] Using existing virtual environment."
fi

# --------------------------------------------------------------------
# [5] Activate the virtual environment.
if [[ -f "$COMFYUI_DIR/venv/bin/activate" ]]; then
    source "$COMFYUI_DIR/venv/bin/activate" || handle_error "Failed to activate virtual environment"
    echo "[INFO] Activated Python virtual environment."
    PYTHON_BIN="$COMFYUI_DIR/venv/bin/python"
    PIP_BIN="$COMFYUI_DIR/venv/bin/pip"
    if [[ ! -f "$PIP_BIN" ]]; then
        echo "[INFO] Installing pip in the virtual environment..."
        "$PYTHON_BIN" -m ensurepip || handle_error "Failed to install pip in the virtual environment"
    fi
    "$PYTHON_BIN" -m pip install --upgrade pip || echo "[WARNING] Failed to upgrade pip, continuing anyway"
else
    handle_error "Virtual environment activation script not found at $COMFYUI_DIR/venv/bin/activate"
fi

# --------------------------------------------------------------------
# [6] Clone or update the ComfyUI repository.
if [[ -d "$COMFYUI_DIR" && ! -d "$COMFYUI_DIR/.git" ]]; then
    echo "[INFO] Directory exists but is not a git repository. Backing up and recreating..."
    BACKUP_DIR="${COMFYUI_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    mv "$COMFYUI_DIR" "$BACKUP_DIR" || handle_error "Failed to backup existing directory"
    echo "[INFO] Existing directory backed up to $BACKUP_DIR"
    mkdir -p "$COMFYUI_DIR"
fi
if [[ ! -d "$COMFYUI_DIR/.git" ]]; then
    echo "[INFO] Cloning ComfyUI repository into $COMFYUI_DIR..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR" || handle_error "Failed to clone repository"
    echo "[INFO] ComfyUI repository cloned successfully."
else
    echo "[INFO] Updating ComfyUI repository in $COMFYUI_DIR..."
    git -C "$COMFYUI_DIR" stash || echo "[WARNING] Git stash failed, continuing anyway"
    git -C "$COMFYUI_DIR" pull --ff-only || handle_error "Failed to update repository"
    echo "[INFO] ComfyUI repository updated successfully."
fi

# --------------------------------------------------------------------
# [7] Clone or update custom node repositories.
echo "[INFO] Cloning or updating custom node repositories..."
mkdir -p "$CUSTOM_NODES_DIR" || handle_error "Failed to create custom nodes directory"
CUSTOM_NODES_REPOS=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/rgthree/rgthree-comfy.git"
    "https://github.com/city96/ComfyUI_ExtraModels.git"
    "https://github.com/city96/ComfyUI-GGUF.git"
)
for REPO_URL in "${CUSTOM_NODES_REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO_URL" .git)
    TARGET_DIR="$CUSTOM_NODES_DIR/$REPO_NAME"
    if [[ ! -d "$TARGET_DIR" ]]; then
        echo "[INFO] Cloning custom node: $REPO_NAME..."
        git clone "$REPO_URL" "$TARGET_DIR" || echo "[WARNING] Failed to clone $REPO_NAME, continuing with other repositories"
        if [[ -d "$TARGET_DIR" ]]; then
            echo "[INFO] Custom node $REPO_NAME cloned successfully."
        fi
    else
        echo "[INFO] Updating custom node: $REPO_NAME..."
        git -C "$TARGET_DIR" stash || echo "[WARNING] Git stash failed for $REPO_NAME, continuing anyway"
        git -C "$TARGET_DIR" pull --ff-only || echo "[WARNING] Failed to update $REPO_NAME, continuing with other repositories"
        echo "[INFO] Custom node $REPO_NAME updated successfully."
    fi
done

# --------------------------------------------------------------------
# [8] Install pre-update packages (with pip cache enabled).
echo "[INFO] Installing pre-update packages..."
PIP_CACHE_DIR="$HOME/.cache/pip"
mkdir -p "$PIP_CACHE_DIR"
PIP_CACHE_OPT="--cache-dir $PIP_CACHE_DIR"
"$PYTHON_BIN" -m pip install $PIP_CACHE_OPT python-dotenv psutil || echo "[WARNING] Failed to install some pre-update packages, continuing anyway"

# --------------------------------------------------------------------
# [9] Install onnxruntime for GPU.
echo "[INFO] Installing onnxruntime for GPU..."
"$PYTHON_BIN" -m pip install $PIP_CACHE_OPT onnxruntime-gpu || echo "[WARNING] Failed to install onnxruntime-gpu, continuing anyway"

# --------------------------------------------------------------------
# [10] Install PyTorch for CUDA 12.8.
echo "[INFO] Installing PyTorch (CUDA 12.8) and related packages (this may take a while, ~4GB download)..."
"$PYTHON_BIN" -m pip install $PIP_CACHE_OPT torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall || echo "[WARNING] Failed to install PyTorch packages, continuing anyway"

# --------------------------------------------------------------------
# [11] Install main ComfyUI requirements from requirements.txt.
if [[ -f "$COMFYUI_DIR/requirements.txt" ]]; then
    echo "[INFO] Installing main ComfyUI requirements..."
    "$PYTHON_BIN" -m pip install $PIP_CACHE_OPT -r "$COMFYUI_DIR/requirements.txt" || echo "[WARNING] Failed to install some ComfyUI requirements, continuing anyway"
else
    echo "[WARNING] requirements.txt not found in $COMFYUI_DIR"
fi

# --------------------------------------------------------------------
# [12] Create and set permissions for shared directories
MODEL_BASE_DIR="/mnt/cache/comfy/models"
INPUT_DIR="/mnt/cache/comfy/input"
OUTPUT_DIR="/mnt/cache/comfy/output"
echo "[INFO] Setting up shared directories for ComfyUI..."
create_shared_dir() {
    dir_path="$1"
    dir_type="$2"
    if [[ ! -d "$dir_path" ]]; then
        echo "[INFO] Creating $dir_type directory at $dir_path..."
        if command -v sudo &> /dev/null && [[ "$(id -u)" -ne 0 ]]; then
            sudo mkdir -p "$dir_path" || echo "[WARNING] Failed to create $dir_type directory with sudo, trying without..."
            if [[ ! -d "$dir_path" ]]; then
                mkdir -p "$dir_path" || echo "[WARNING] Failed to create $dir_type directory without sudo. Continuing anyway."
            fi
        else
            mkdir -p "$dir_path" || echo "[WARNING] Failed to create $dir_type directory. Continuing anyway."
        fi
    fi
    if [[ -d "$dir_path" ]]; then
        echo "[INFO] Setting permissions for $dir_type directory..."
        if command -v sudo &> /dev/null && [[ "$(id -u)" -ne 0 ]]; then
            sudo chmod -R 777 "$dir_path" 2>/dev/null || echo "[WARNING] Failed to set permissions with sudo, trying without..."
            if [[ ! -w "$dir_path" ]]; then
                chmod -R 777 "$dir_path" 2>/dev/null || echo "[WARNING] Failed to set permissions without sudo."
            fi
        else
            chmod -R 777 "$dir_path" 2>/dev/null || echo "[WARNING] Failed to set permissions."
        fi
        if [[ -w "$dir_path" ]]; then
            echo "[INFO] $dir_type directory is writable."
        else
            echo "[WARNING] $dir_type directory is not writable. ComfyUI may have issues accessing it."
        fi
    else
        echo "[WARNING] $dir_type directory does not exist and could not be created. ComfyUI may have issues."
    fi
}
create_shared_dir "$MODEL_BASE_DIR" "models"
create_shared_dir "$INPUT_DIR" "input"
create_shared_dir "$OUTPUT_DIR" "output"

# --------------------------------------------------------------------
# [13] Create a default .env file
ENV_FILE="$HOME/.env.comfyui"
echo "[INFO] Creating default .env file at $ENV_FILE..."
cat > "$ENV_FILE" << 'EOL'
# Custom paths for model storage and processing
MODEL_BASE_PATH=/mnt/cache/comfy/models
INPUT_DIR=/mnt/cache/comfy/input
OUTPUT_DIR=/mnt/cache/comfy/output
# Python settings
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1
PYTHONWARNINGS="ignore"
PIP_DISABLE_PIP_VERSION_CHECK=1
PIP_NO_CACHE_DIR=1
# Hugging Face/Transformers settings
HF_HUB_DISABLE_TELEMETRY=True
# CUDA settings
CUDA_VISIBLE_DEVICES=1,2
TORCH_USE_CUDA_DSA=1
CUDA_LAUNCH_BLOCKING=1
CUDA_DEVICE_MAX_COPY_CONNECTIONS=32
CUDA_DEVICE_MAX_CONNECTIONS=32
CUDA_CACHE_DISABLE=1
CUBLAS_WORKSPACE_CONFIG=:16:8
CUDA_DISABLE_JIT=0
CUDA_DISABLE_PTX_JIT=1
# PyTorch settings
PYTORCH_JIT_LOG_LEVEL=FATAL
# TensorFlow settings
TF_CPP_MIN_LOG_LEVEL=3
TF_ENABLE_DEPRECATION_WARNINGS=0
# Other settings
KMP_DUPLICATE_LIB_OK=True
NO_ALBUMENTATIONS_UPDATE=1
# ComfyUI launch parameters
CUSTOM_PARAMETERS="--listen --normalvram --use-pytorch-cross-attention --cuda-malloc --disable-xformers --disable-smart-memory --force-channels-last --cache-classic --dont-print-server --verbose CRITICAL --log-stdout"
# Monitor settings
MONITOR_INTERVAL=10
MAX_RESTART_COUNT=5
SERVER_PORT=8188
EOL

echo "[INFO] Default .env file created successfully."

# --------------------------------------------------------------------
# [14] Create a robust launch script
LAUNCH_SCRIPT="$HOME/launch_comfyui.sh"
LOG_DIR="$COMFYUI_DIR/logs"
echo "[INFO] Creating launch script at $LAUNCH_SCRIPT..."

mkdir -p "$LOG_DIR"

cat > "$LAUNCH_SCRIPT" << 'EOL'
#!/bin/bash

# ComfyUI Launcher Script with auto-restart and error handling
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_DIR="$HOME/ComfyUI"
ENV_FILE="$HOME/.env.comfyui"
LOG_DIR="$COMFYUI_DIR/logs"
VENV_PATH="$COMFYUI_DIR/venv"

# Global variable to track ComfyUI process ID
comfy_pid=""

# Setup signal trap for clean exit
trap cleanup SIGINT SIGTERM

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Clean up logs older than 24 hours (on launch only)
find "$LOG_DIR" -name "comfyui_*.log" -type f -mmin +1440 -exec rm {} \; 2>/dev/null || true

# Function to create a timestamped log file (reused for this run)
create_log_file() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_id=$(head /dev/urandom | tr -dc 'a-f0-9' | head -c 8)
    local pid=$$
    echo "$LOG_DIR/comfyui_${timestamp}_${session_id}_${pid}.log"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp | $level | $message" | tee -a "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    if [[ -n "$comfy_pid" ]] && kill -0 $comfy_pid 2>/dev/null; then
        log_message "INFO" "Terminating ComfyUI process (PID: $comfy_pid)"
        kill $comfy_pid 2>/dev/null || true
        sleep 2
        if kill -0 $comfy_pid 2>/dev/null; then
            kill -9 $comfy_pid 2>/dev/null || true
        fi
    fi
    log_message "INFO" "ComfyUI launcher stopped"
    exit 0
}

# Function to create extra_model_paths.yaml if MODEL_BASE_PATH is set
create_model_paths_yaml() {
    if [[ -n "$MODEL_BASE_PATH" ]]; then
        if [[ ! -d "$MODEL_BASE_PATH" ]]; then
            log_message "WARNING" "Model path $MODEL_BASE_PATH does not exist. Creating it..."
            mkdir -p "$MODEL_BASE_PATH" 2>/dev/null || log_message "ERROR" "Failed to create model directory"
            if [[ -d "$MODEL_BASE_PATH" ]]; then
                chmod -R 777 "$MODEL_BASE_PATH" 2>/dev/null || log_message "WARNING" "Failed to set permissions on model directory"
            fi
        fi
        cat > "$COMFYUI_DIR/extra_model_paths.yaml" << EOF
comfyui:
  base_path: $MODEL_BASE_PATH
  is_default: true
  checkpoints: checkpoints
  clip: clip
  clip_vision: clip_vision
  configs: configs
  controlnet: controlnet
  diffusion_models: |
    diffusion_models
    unet
  embeddings: embeddings
  loras: loras
  text_encoders: text_encoders
  upscale_models: upscale_models
  vae: vae
  reactor: reactor
EOF
        log_message "INFO" "Created model paths configuration at $COMFYUI_DIR/extra_model_paths.yaml"
    fi
}

# Function to clean old logs (not used, handled on launch)
# clean_old_logs() {
#     find "$LOG_DIR" -name "comfyui_*.log" -type f -mtime +1 -exec rm {} \; 2>/dev/null || true
#     log_message "INFO" "Cleaned old log files"
# }

# Create log file (reused for this run)
LOG_FILE=$(create_log_file)
log_message "INFO" "=== Starting new ComfyUI session ==="
log_message "INFO" "Log file: $LOG_FILE"

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    log_message "INFO" "Loading environment from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    log_message "WARNING" "Environment file not found at $ENV_FILE"
fi

# Set default values for any missing variables
SERVER_PORT=${SERVER_PORT:-8188}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}
MAX_RESTART_COUNT=${MAX_RESTART_COUNT:-5}
CUSTOM_PARAMETERS=${CUSTOM_PARAMETERS:-"--listen"}

# Create model paths YAML if needed
create_model_paths_yaml

# Check for virtual environment
if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
    log_message "ERROR" "Virtual environment not found at $VENV_PATH"
    exit 1
fi

# Main loop for auto-restart
restart_count=0
while [[ $restart_count -lt $MAX_RESTART_COUNT ]]; do
    source "$VENV_PATH/bin/activate"
    log_message "INFO" "Activated virtual environment: $VENV_PATH"
    launch_args=(
        "python" "-u" "$COMFYUI_DIR/main.py"
        "--port=$SERVER_PORT"
    )
    if [[ -n "$CUSTOM_PARAMETERS" ]]; then
        read -ra custom_params <<< "$CUSTOM_PARAMETERS"
        launch_args+=("${custom_params[@]}")
    fi
    if [[ -n "$INPUT_DIR" ]]; then
        launch_args+=("--input-directory=$INPUT_DIR")
    fi
    if [[ -n "$OUTPUT_DIR" ]]; then
        launch_args+=("--output-directory=$OUTPUT_DIR")
    fi
    log_message "INFO" "Launching ComfyUI with: ${launch_args[*]}"
    "${launch_args[@]}" >> "$LOG_FILE" 2>&1 &
    comfy_pid=$!
    log_message "INFO" "ComfyUI started with PID: $comfy_pid"
    log_message "INFO" "ComfyUI server should be available at http://127.0.0.1:$SERVER_PORT in a moment..."
    log_message "INFO" "Monitoring ComfyUI process (PID: $comfy_pid)..."
    while kill -0 $comfy_pid 2>/dev/null; do
        sleep $MONITOR_INTERVAL
    done
    log_message "ERROR" "ComfyUI process has terminated unexpectedly"
    # Highlight last 20 lines of the log file in yellow for debugging
    if [[ -f "$LOG_FILE" ]]; then
        tput setaf 3  # Yellow
        echo "====================[ Last 20 lines of log ]===================="
        tail -n 20 "$LOG_FILE"
        echo "==============================================================="
        tput sgr0  # Reset color
    fi
    if kill -0 $comfy_pid 2>/dev/null; then
        log_message "INFO" "Killing lingering ComfyUI process (PID: $comfy_pid)"
        kill $comfy_pid 2>/dev/null || true
        sleep 2
        if kill -0 $comfy_pid 2>/dev/null; then
            kill -9 $comfy_pid 2>/dev/null || true
        fi
    fi
    comfy_pid=""
    restart_count=$((restart_count + 1))
    if [[ $restart_count -lt $MAX_RESTART_COUNT ]]; then
        log_message "WARNING" "Restarting ComfyUI (attempt $restart_count of $MAX_RESTART_COUNT)..."
        sleep 5
    else
        log_message "ERROR" "Maximum restart attempts reached ($MAX_RESTART_COUNT). Giving up."
    fi
    deactivate || true
done
log_message "INFO" "ComfyUI launcher stopped"
EOL

chmod +x "$LAUNCH_SCRIPT"
echo "[INFO] Launch script created successfully."

# --------------------------------------------------------------------
# [14] Check CUDA availability
# Activate venv to check PyTorch/CUDA versions
source "$COMFYUI_DIR/venv/bin/activate"
"$PYTHON_BIN" -m pip install --upgrade pip wheel packaging || echo "[WARNING] Failed to install wheel/packaging, continuing anyway."
PYTORCH_VERSION=$($PYTHON_BIN -c 'import torch; print(torch.__version__)' 2>/dev/null || echo "none")
CUDA_VERSION=$($PYTHON_BIN -c 'import torch; print(torch.version.cuda)' 2>/dev/null || echo "none")
echo "[INFO] Detected PyTorch version: $PYTORCH_VERSION"
echo "[INFO] Detected CUDA version: $CUDA_VERSION"

# Check if NVIDIA driver is installed
if nvidia-smi &>/dev/null; then
    echo "[INFO] NVIDIA driver found: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"
    echo "[INFO] ComfyUI will utilize GPU acceleration with xformers."
else
    echo "[WARNING] No NVIDIA drivers detected. ComfyUI will run in CPU-only mode."
fi

deactivate || true

deactivate || true

# --------------------------------------------------------------------
# [15] Completion message.
echo
echo "[SUCCESS] Finished installation/update process."
echo "Next steps:"
echo "  1. Check the default environment settings in '$ENV_FILE' and modify if needed"
echo "  2. Start ComfyUI by running '$LAUNCH_SCRIPT'"
echo "  3. ComfyUI will be available at http://localhost:8188"
echo "  4. Check the logs folder for any issues: $COMFYUI_DIR/logs"
