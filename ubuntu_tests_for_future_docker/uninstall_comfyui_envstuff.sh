#!/bin/bash

# === ComfyUI Automated Uninstaller (Linux, Bash) ===
# This script uninstalls ComfyUI by removing the venv and apt packages
# Run this script with appropriate permissions

set -e

echo "=== ComfyUI Uninstaller ==="
echo "This script will:"
echo "  1. Remove the ComfyUI virtual environment only (preserving ComfyUI code)"
echo "  2. Remove extra apt packages installed by the installer (except git)"
echo "  3. NOT remove your model files or generated images"
echo "  4. Remove launcher scripts and environment files"
echo

# Prompt user for confirmation
read -p "Are you sure you want to proceed with uninstallation? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Define paths
COMFYUI_DIR="$HOME/ComfyUI"
VENV_PATH="$COMFYUI_DIR/venv"
ENV_FILE="$HOME/.env.comfyui"
LAUNCH_SCRIPT="$HOME/launch_comfyui.sh"

# Check if ComfyUI is installed
if [[ ! -d "$COMFYUI_DIR" ]]; then
    echo "[WARNING] ComfyUI directory not found at $COMFYUI_DIR"
    read -p "Do you want to continue with removing packages? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
fi

# Kill any running ComfyUI processes
echo "[INFO] Checking for running ComfyUI processes..."
pkill -f "python.*main.py" 2>/dev/null || true
echo "[INFO] Any running ComfyUI processes have been terminated."

# Remove virtual environment
if [[ -d "$VENV_PATH" ]]; then
    echo "[INFO] Removing ComfyUI virtual environment..."
    rm -rf "$VENV_PATH"
    echo "[INFO] Virtual environment removed."
else
    echo "[INFO] Virtual environment not found at $VENV_PATH"
fi

# Remove ENV file
if [[ -f "$ENV_FILE" ]]; then
    echo "[INFO] Removing environment file..."
    rm -f "$ENV_FILE"
    echo "[INFO] Environment file removed."
fi

# Remove launch script
if [[ -f "$LAUNCH_SCRIPT" ]]; then
    echo "[INFO] Removing launch script..."
    rm -f "$LAUNCH_SCRIPT"
    echo "[INFO] Launch script removed."
fi

# Clean up venv-related files but keep the ComfyUI code
echo "[INFO] Keeping ComfyUI directory but cleaning up venv-related files..."
rm -rf "$COMFYUI_DIR/__pycache__" 2>/dev/null || true
rm -rf "$COMFYUI_DIR/.venv" 2>/dev/null || true  # In case venv was created in alternate location

# Optional: Clean logs
read -p "Do you want to remove ComfyUI log files? (y/n): " clean_logs
if [[ "$clean_logs" == "y" || "$clean_logs" == "Y" ]]; then
    if [[ -d "$COMFYUI_DIR/logs" ]]; then
        echo "[INFO] Removing log files..."
        rm -rf "$COMFYUI_DIR/logs"
        echo "[INFO] Log files removed."
    else
        echo "[INFO] No log directory found."
    fi
fi

# Remove apt packages (except git)
echo "[INFO] Removing installed APT packages (except git)..."

# Check for root/sudo
if [[ "$(id -u)" -ne 0 ]]; then
    echo "[INFO] Running package removal with sudo..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Packages to remove
# These are the packages we installed in the setup script
PACKAGES_TO_REMOVE=(
    "python3.12"
    "python3.12-venv"
    "python3-pip"
    "ninja-build"
    "build-essential"
    "python3.12-dev"
    "libcudnn8"
    "libcufft-dev-11-8"
    "libcurand-dev-11-8"
    "libcusolver-dev-11-8"
    "libcusparse-dev-11-8"
)

# Remove packages
$SUDO_CMD apt remove --purge -y "${PACKAGES_TO_REMOVE[@]}" 2>/dev/null || echo "[WARNING] Some packages were not installed or could not be removed."

# Clean up any leftover dependencies
$SUDO_CMD apt autoremove -y

# Clean pip cache
read -p "Do you want to clean the pip cache? (y/n): " clean_pip
if [[ "$clean_pip" == "y" || "$clean_pip" == "Y" ]]; then
    echo "[INFO] Cleaning pip cache..."
    rm -rf "$HOME/.cache/pip"
    echo "[INFO] Pip cache cleaned."
fi

# Optional: Remove models
MODEL_BASE_DIR="/mnt/cache/comfy/models"
if [[ -d "$MODEL_BASE_DIR" ]]; then
    read -p "Do you want to remove model files at $MODEL_BASE_DIR? (y/n): " remove_models
    if [[ "$remove_models" == "y" || "$remove_models" == "Y" ]]; then
        echo "[INFO] Removing model files..."
        rm -rf "$MODEL_BASE_DIR"
        echo "[INFO] Model files removed."
    else
        echo "[INFO] Keeping model files."
    fi
fi

# Check for and remove extra_model_paths.yaml if it exists
MODEL_PATHS_FILE="$COMFYUI_DIR/extra_model_paths.yaml"
if [[ -f "$MODEL_PATHS_FILE" ]]; then
    read -p "Do you want to remove the model paths configuration file? (y/n): " remove_model_paths
    if [[ "$remove_model_paths" == "y" || "$remove_model_paths" == "Y" ]]; then
        echo "[INFO] Removing model paths configuration file..."
        rm -f "$MODEL_PATHS_FILE"
        echo "[INFO] Model paths configuration file removed."
    else
        echo "[INFO] Keeping model paths configuration file."
    fi
fi

# Done
echo
echo "[SUCCESS] ComfyUI uninstallation completed."
echo "Summary:"
echo "  • Virtual environment removed"
echo "  • Launcher scripts and environment files removed"
echo "  • ComfyUI code preserved at $COMFYUI_DIR"
echo "  • Model files preserved"
echo
echo "If you want to reinstall ComfyUI, you can run install_update_comfyui.sh again."
