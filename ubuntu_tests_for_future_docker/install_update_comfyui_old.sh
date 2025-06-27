#!/bin/sh

# === ComfyUI Automated Installer (Linux) ===
# This script installs/updates ComfyUI and its dependencies in a Python venv environment.
# It supports Ubuntu and uses only public Git repos.
# Run this script from the directory where you want ComfyUI installed.

# Error handling function
handle_error() {
    echo "[ERROR] $1"
    exit 1
}
# [1] Check for elevated privileges (optional)
if [ "$(id -u)" -ne 0 ]; then
    echo "[INFO] Running without elevated privileges."
else
    echo "[INFO] Running with elevated privileges."
fi

# --------------------------------------------------------------------
# [2] Verify required programs: Git and Python 3.12 must be available.
if ! command -v git &> /dev/null; then
    echo "[ERROR] Git is not installed or not in PATH. Installing Git..."
    sudo apt update && sudo apt install -y git
fi

if ! command -v python3.12 &> /dev/null; then
    echo "[ERROR] Python 3.12 is not installed. Installing Python 3.12..."
    sudo apt update && sudo apt install -y python3.12 python3.12-venv python3-pip
fi

# --------------------------------------------------------------------
# [3] Set environment variables for the installation.
COMFYUI_ENV_NAME="ComfyUI"
COMFYUI_DIR="$HOME/$COMFYUI_ENV_NAME"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
# Set default Python and pip variables (will be overridden after venv activation)
PYTHON_BIN="python3.12"
PIP_BIN="pip"
echo "[INFO] ComfyUI environment name: $COMFYUI_ENV_NAME"
echo "[INFO] ComfyUI directory: $COMFYUI_DIR"

# --------------------------------------------------------------------
# [4] Create a Python virtual environment if it doesn't exist.
if [ ! -d "$COMFYUI_DIR/venv" ]; then
    echo "[INFO] Creating Python virtual environment..."
    mkdir -p "$COMFYUI_DIR" || handle_error "Failed to create ComfyUI directory"
    $PYTHON_BIN -m venv "$COMFYUI_DIR/venv" || handle_error "Failed to create virtual environment"
    echo "[INFO] Virtual environment created successfully."
else
    echo "[INFO] Using existing virtual environment."
fi

# --------------------------------------------------------------------
# [5] Activate the virtual environment.
if [ -f "$COMFYUI_DIR/venv/bin/activate" ]; then
    . "$COMFYUI_DIR/venv/bin/activate" || handle_error "Failed to activate virtual environment"
    echo "[INFO] Activated Python virtual environment."
    
    # Make sure we're using the venv pip
    PYTHON_BIN="$COMFYUI_DIR/venv/bin/python"
    PIP_BIN="$COMFYUI_DIR/venv/bin/pip"
    
    if [ ! -f "$PIP_BIN" ]; then
        echo "[INFO] Installing pip in the virtual environment..."
        "$PYTHON_BIN" -m ensurepip || handle_error "Failed to install pip in the virtual environment"
    fi
    
    # Upgrade pip
    "$PYTHON_BIN" -m pip install --upgrade pip || echo "[WARNING] Failed to upgrade pip, continuing anyway"
else
    handle_error "Virtual environment activation script not found at $COMFYUI_DIR/venv/bin/activate"
fi

# --------------------------------------------------------------------
# [6] Clone or update the ComfyUI repository.
# Check if directory exists but is not a git repository
if [ -d "$COMFYUI_DIR" ] && [ ! -d "$COMFYUI_DIR/.git" ]; then
    echo "[INFO] Directory exists but is not a git repository. Backing up and recreating..."
    BACKUP_DIR="${COMFYUI_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    mv "$COMFYUI_DIR" "$BACKUP_DIR" || handle_error "Failed to backup existing directory"
    echo "[INFO] Existing directory backed up to $BACKUP_DIR"
    mkdir -p "$COMFYUI_DIR"
fi

if [ ! -d "$COMFYUI_DIR/.git" ]; then
    echo "[INFO] Cloning ComfyUI repository into $COMFYUI_DIR..."
    if [ -d "$COMFYUI_DIR" ]; then
        # Directory exists but is empty or we can clone into it
        git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR" || handle_error "Failed to clone repository"
    else
        # Directory doesn't exist
        mkdir -p "$COMFYUI_DIR" || handle_error "Failed to create directory"
        git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR" || handle_error "Failed to clone repository"
    fi
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
CUSTOM_NODES_REPOS="https://github.com/ltdrdata/ComfyUI-Manager.git https://github.com/rgthree/rgthree-comfy.git https://github.com/city96/ComfyUI_ExtraModels.git https://github.com/city96/ComfyUI-GGUF.git"

for REPO_URL in $CUSTOM_NODES_REPOS; do
    REPO_NAME=$(basename "$REPO_URL" .git)
    TARGET_DIR="$CUSTOM_NODES_DIR/$REPO_NAME"
    if [ ! -d "$TARGET_DIR" ]; then
        echo "[INFO] Cloning custom node: $REPO_NAME..."
        git clone "$REPO_URL" "$TARGET_DIR" || echo "[WARNING] Failed to clone $REPO_NAME, continuing with other repositories"
        if [ -d "$TARGET_DIR" ]; then
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
# [8] Install pre-update packages.
echo "[INFO] Installing pre-update packages..."
"$PYTHON_BIN" -m pip install python-dotenv requests psutil || echo "[WARNING] Failed to install some pre-update packages, continuing anyway"

# --------------------------------------------------------------------
# [9] Install onnxruntime for GPU.
echo "[INFO] Installing onnxruntime for GPU..."
"$PYTHON_BIN" -m pip install onnxruntime-gpu || echo "[WARNING] Failed to install onnxruntime-gpu, continuing anyway"

# --------------------------------------------------------------------
# [10] Install PyTorch for CUDA 12.8.
echo "[INFO] Installing PyTorch (CUDA 12.8) and related packages (this may take a while, ~4GB download)..."
"$PYTHON_BIN" -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 --force-reinstall || echo "[WARNING] Failed to install PyTorch packages, continuing anyway"

# --------------------------------------------------------------------
# [11] Install main ComfyUI requirements from requirements.txt.
if [ -f "$COMFYUI_DIR/requirements.txt" ]; then
    echo "[INFO] Installing main ComfyUI requirements..."
    "$PYTHON_BIN" -m pip install -r "$COMFYUI_DIR/requirements.txt" || echo "[WARNING] Failed to install some ComfyUI requirements, continuing anyway"
else
    echo "[WARNING] requirements.txt not found in $COMFYUI_DIR"
fi

# --------------------------------------------------------------------
# [12] Create a default .env file
ENV_FILE="$HOME/.env.comfyui"
echo "[INFO] Creating default .env file at $ENV_FILE..."

cat > "$ENV_FILE" << 'EOL'
# Custom paths for model storage and processing
MODEL_BASE_PATH=/mnt/cache/comfy/models
INPUT_DIR=/mnt/cache/comfy/input
OUTPUT_DIR=/mnt/cache/comfy/output
TEMP_DIR=/mnt/cache/comfy/temp

# Python settings
PYTHONUNBUFFERED=1
PYTHONDONTWRITEBYTECODE=1
PYTHONWARNINGS="ignore"
PIP_DISABLE_PIP_VERSION_CHECK=1
PIP_NO_CACHE_DIR=1

# Hugging Face/Transformers settings
HF_HUB_DISABLE_TELEMETRY=True

# CUDA settings
CUDA_LAUNCH_BLOCKING=1
CUBLAS_WORKSPACE_CONFIG=:16:8
CUDA_DEVICE_MAX_COPY_CONNECTIONS=1
CUDA_DEVICE_MAX_CONNECTIONS=1
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
CUSTOM_PARAMETERS="--listen --normalvram --cuda-malloc --cache-classic --dont-print-server --verbose CRITICAL --log-stdout"

# Monitor settings
MONITOR_INTERVAL=10
BOOT_WAIT_TIME=180
MAX_RESTART_COUNT=5
SERVER_PORT=8188
EOL

echo "[INFO] Default .env file created successfully."

# --------------------------------------------------------------------
# [13] Create a robust launch script
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

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to create a timestamped log file
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

# Function to check if server is responding
check_server() {
    local port="$1"
    local timeout="${2:-5}"  # Default timeout of 5 seconds if not specified
    
    # Use curl with timeout to prevent hanging
    curl -s -m "$timeout" -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port" 2>/dev/null | grep -q "200"
    return $?
}

# Function to create extra_model_paths.yaml if MODEL_BASE_PATH is set
create_model_paths_yaml() {
    if [ -n "$MODEL_BASE_PATH" ]; then
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

# Function to clean old logs
clean_old_logs() {
    find "$LOG_DIR" -name "comfyui_*.log" -type f -mtime +7 -exec rm {} \; 2>/dev/null || true
    log_message "INFO" "Cleaned old log files"
}

# Create log file
LOG_FILE=$(create_log_file)
log_message "INFO" "=== Starting new ComfyUI session ==="
log_message "INFO" "Log file: $LOG_FILE"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    log_message "INFO" "Loading environment from $ENV_FILE"
    set -a
    . "$ENV_FILE"
    set +a
else
    log_message "WARNING" "Environment file not found at $ENV_FILE"
fi

# Set default values for any missing variables
SERVER_PORT=${SERVER_PORT:-8188}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}
BOOT_WAIT_TIME=${BOOT_WAIT_TIME:-180}
MAX_RESTART_COUNT=${MAX_RESTART_COUNT:-5}
CUSTOM_PARAMETERS=${CUSTOM_PARAMETERS:-"--listen"}

# Create model paths YAML if needed
create_model_paths_yaml

# Check for virtual environment
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    log_message "ERROR" "Virtual environment not found at $VENV_PATH"
    exit 1
fi

# Main loop for auto-restart
restart_count=0
while [ $restart_count -lt $MAX_RESTART_COUNT ]; do
    # Activate virtual environment
    . "$VENV_PATH/bin/activate"
    log_message "INFO" "Activated virtual environment: $VENV_PATH"
    
    # Clean old logs periodically
    clean_old_logs
    
    # Launch ComfyUI with all parameters
    launch_args=(
        "python" "-u" "$COMFYUI_DIR/main.py"
        "--port=$SERVER_PORT"
    )
    
    # Add custom parameters
    if [ -n "$CUSTOM_PARAMETERS" ]; then
        read -ra custom_params <<< "$CUSTOM_PARAMETERS"
        launch_args+=("${custom_params[@]}")
    fi
    
    # Add directory parameters if set
    if [ -n "$INPUT_DIR" ]; then
        launch_args+=("--input-directory=$INPUT_DIR")
    fi
    if [ -n "$OUTPUT_DIR" ]; then
        launch_args+=("--output-directory=$OUTPUT_DIR")
    fi
    if [ -n "$TEMP_DIR" ]; then
        launch_args+=("--temp-directory=$TEMP_DIR")
    fi
    
    # Log the launch command
    log_message "INFO" "Launching ComfyUI with: ${launch_args[*]}"
    
    # Launch ComfyUI and redirect output to log file
    "${launch_args[@]}" >> "$LOG_FILE" 2>&1 &
    comfy_pid=$!
    log_message "INFO" "ComfyUI started with PID: $comfy_pid"
    
    # Wait for server to start
    log_message "INFO" "Waiting for server to start (up to $BOOT_WAIT_TIME seconds)..."
    start_time=$(date +%s)
    server_ready=0
    status_check_interval=10  # Check status every 10 seconds during boot
    last_status_time=$start_time
    
    while [ $(($(date +%s) - start_time)) -lt $BOOT_WAIT_TIME ]; do
        # Check server is responding (with longer timeout during boot)
        if check_server $SERVER_PORT 15; then
            server_ready=1
            log_message "INFO" "ComfyUI server is ready at http://127.0.0.1:$SERVER_PORT"
            break
        fi
        
        # Check if process died during startup
        if ! kill -0 $comfy_pid 2>/dev/null; then
            log_message "ERROR" "ComfyUI process died during startup"
            break
        fi
        
        # Show periodic progress messages during long startup
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        if [ $((current_time - last_status_time)) -ge $status_check_interval ]; then
            log_message "INFO" "Still waiting for ComfyUI to start... ($elapsed seconds elapsed)"
            last_status_time=$current_time
        fi
        
        sleep 1
    done
    
    if [ $server_ready -eq 0 ]; then
        log_message "ERROR" "Server failed to start within timeout"
        if kill -0 $comfy_pid 2>/dev/null; then
            log_message "INFO" "Terminating hanging process: $comfy_pid"
            kill $comfy_pid 2>/dev/null || true
        fi
    else
        # Monitor the server while it's running
        log_message "INFO" "Monitoring ComfyUI server..."
        while true; do
            # Check if process is still running
            if ! kill -0 $comfy_pid 2>/dev/null; then
                log_message "ERROR" "ComfyUI process has terminated unexpectedly"
                break
            fi
            
            # Check if server is still responding
            if ! check_server $SERVER_PORT; then
                log_message "ERROR" "Server not responding"
                # Try to terminate gracefully
                kill $comfy_pid 2>/dev/null || true
                sleep 2
                # Force kill if still running
                if kill -0 $comfy_pid 2>/dev/null; then
                    kill -9 $comfy_pid 2>/dev/null || true
                fi
                break
            fi
            
            sleep $MONITOR_INTERVAL
        done
    fi
    
    # Increment restart counter
    restart_count=$((restart_count + 1))
    
    if [ $restart_count -lt $MAX_RESTART_COUNT ]; then
        log_message "WARNING" "Restarting ComfyUI (attempt $restart_count of $MAX_RESTART_COUNT)..."
        sleep 5
    else
        log_message "ERROR" "Maximum restart attempts reached ($MAX_RESTART_COUNT). Giving up."
    fi
    
    # Always ensure we deactivate the virtual environment before the next loop
    deactivate || true
done

log_message "INFO" "ComfyUI launcher stopped"
EOL

chmod +x "$LAUNCH_SCRIPT"
echo "[INFO] Launch script created successfully."

# --------------------------------------------------------------------
# [14] Completion message.
echo
echo "[SUCCESS] Finished installation/update process."
echo "Next steps:"
echo "  1. Check the default environment settings in '$ENV_FILE' and modify if needed"
echo "  2. Start ComfyUI by running '$LAUNCH_SCRIPT'"
echo "  3. ComfyUI will be available at http://localhost:8188"
echo "  4. Check the logs folder for any issues: $COMFYUI_DIR/logs"