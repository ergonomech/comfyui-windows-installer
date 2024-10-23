import os
import time
import subprocess
from dotenv import load_dotenv
import requests
import logging
from datetime import datetime, timedelta

# Load environment variables from .env file
load_dotenv()

# Get configuration values
CONDA_PATH = os.getenv("CONDA_PATH")
COMFYUI_ENV_NAME = os.getenv("COMFYUI_ENV_NAME")
COMFYUI_DIR = os.getenv("COMFYUI_DIR", os.path.join(os.getenv("USERPROFILE"), "ComfyUI"))
MODEL_BASE_PATH = os.getenv("MODEL_BASE_PATH")
INPUT_DIR = os.getenv("INPUT_DIR")
OUTPUT_DIR = os.getenv("OUTPUT_DIR")
TEMP_DIR = os.getenv("TEMP_DIR")
USE_CUSTOM_PATHS = os.getenv("USE_CUSTOM_PATHS", "false").lower() == "true"
SERVER_PORT = os.getenv("SERVER_PORT", "8188")
MONITOR_INTERVAL = int(os.getenv("MONITOR_INTERVAL", 10))
BOOT_WAIT_TIME = int(os.getenv("BOOT_WAIT_TIME", 30))
LOG_DIR = os.getenv("LOG_DIR", "logs")

# Create log directory if it doesn't exist
os.makedirs(LOG_DIR, exist_ok=True)

# Set environment variables for PyTorch, CUDA, etc.
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["CUDA_AUTO_BOOST"] = "1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True,max_split_size_mb:512"
os.environ["PYTORCH_NO_CUDA_MEMORY_CACHING"] = "1"
os.environ["TORCH_USE_CUDA_DSA"] = "1"

def setup_logger():
    """Set up logging to a daily file."""
    log_filename = os.path.join(LOG_DIR, f"ComfyUI_{datetime.now().strftime('%Y-%m-%d')}.log")
    logging.basicConfig(
        filename=log_filename,
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
    )
    return log_filename

def log(message):
    """Log messages to the file and print minimal status to the console."""
    logging.info(message)
    print(message)

def clean_old_logs():
    """Remove log files older than two days."""
    cutoff_date = datetime.now() - timedelta(days=2)
    for log_file in os.listdir(LOG_DIR):
        log_path = os.path.join(LOG_DIR, log_file)
        if os.path.isfile(log_path):
            file_date_str = log_file.replace("ComfyUI_", "").replace(".log", "")
            try:
                file_date = datetime.strptime(file_date_str, "%Y-%m-%d")
                if file_date < cutoff_date:
                    os.remove(log_path)
                    log(f"Removed old log file: {log_file}")
            except ValueError:
                pass  # Ignore files that don't match the date pattern

def launch_comfyui():
    """Launch ComfyUI as a subprocess."""
    args = [
        "python", os.path.join(COMFYUI_DIR, "main.py"), "--listen", f"--port={SERVER_PORT}"
    ]

    # Add custom paths if enabled
    if USE_CUSTOM_PATHS:
        args += [
            f"--input-directory={INPUT_DIR}",
            f"--output-directory={OUTPUT_DIR}",
            f"--temp-directory={TEMP_DIR}"
        ]

    log(f"Launching ComfyUI with args: {' '.join(args)}")
    return subprocess.Popen(args)

def is_server_responding():
    """Check if the server is responding at the specified port."""
    try:
        response = requests.get(f"http://127.0.0.1:{SERVER_PORT}")
        return response.status_code == 200
    except requests.ConnectionError:
        return False

def main():
    log_filename = setup_logger()
    log("Starting ComfyUI management script...")
    log(f"Logs are being written to: {log_filename}")

    # Clean up old logs
    clean_old_logs()

    # Launch ComfyUI initially
    process = launch_comfyui()
    time.sleep(BOOT_WAIT_TIME)

    while True:
        # Check if the process has exited or the server is not responding
        if process.poll() is not None:
            log("ComfyUI process has exited. Restarting...")
            process = launch_comfyui()
            time.sleep(BOOT_WAIT_TIME)
        elif not is_server_responding():
            log("Server not responding. Restarting ComfyUI...")
            process.terminate()
            process = launch_comfyui()
            time.sleep(BOOT_WAIT_TIME)
        
        # Clean up old logs during each check cycle
        clean_old_logs()

        # Wait before the next check
        time.sleep(MONITOR_INTERVAL)

if __name__ == "__main__":
    main()
