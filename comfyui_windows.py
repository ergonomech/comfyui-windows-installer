import os
import time
import subprocess
import requests
import logging
from datetime import datetime, timedelta
import psutil
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration values from .env
USER_HOME = os.getenv("USERPROFILE")
CONDA_PATH = os.getenv("CONDA_PATH", os.path.join(USER_HOME, "miniconda3"))
COMFYUI_ENV_NAME = os.getenv("COMFYUI_ENV_NAME", "ComfyUI")
COMFYUI_DIR = os.getenv("COMFYUI_DIR", os.path.join(USER_HOME, "ComfyUI"))
MODEL_BASE_PATH = os.getenv("MODEL_BASE_PATH")
INPUT_DIR = os.getenv("INPUT_DIR")
OUTPUT_DIR = os.getenv("OUTPUT_DIR")
TEMP_DIR = os.getenv("TEMP_DIR")
USE_CUSTOM_PATHS = os.getenv("USE_CUSTOM_PATHS", "false").lower() == "true"
SERVER_PORT = os.getenv("SERVER_PORT", "8188")
CUSTOM_PARAMETERS = os.getenv("CUSTOM_PARAMETERS", "")
MONITOR_INTERVAL = int(os.getenv("MONITOR_INTERVAL", 10))
BOOT_WAIT_TIME = int(os.getenv("BOOT_WAIT_TIME", 30))
LOG_DIR = os.getenv("LOG_DIR", "logs")

# Create log directory if it doesn't exist
os.makedirs(LOG_DIR, exist_ok=True)

# Set environment variables for PyTorch, CUDA, etc.
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
os.environ["CUDA_AUTO_BOOST"] = "0"

def setup_logger(log_type="script"):
    """Set up logging to a daily file for script runner or ComfyUI logs."""
    log_filename = os.path.join(LOG_DIR, f"{log_type}_log_{datetime.now().strftime('%Y-%m-%d')}.log")
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
            file_date_str = log_file.split('_')[-1].replace(".log", "")
            try:
                file_date = datetime.strptime(file_date_str, "%Y-%m-%d")
                if file_date < cutoff_date:
                    os.remove(log_path)
                    log(f"Removed old log file: {log_file}")
            except ValueError:
                pass  # Ignore files that don't match the date pattern

def terminate_existing_comfyui():
    """Terminate any running instance of ComfyUI using the specified port."""
    for process in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            if 'python' in process.name().lower() and 'main.py' in ' '.join(process.cmdline()):
                log(f"Found existing ComfyUI process (PID: {process.pid}). Terminating it...")
                process.terminate()
                process.wait(timeout=10)
                log(f"Terminated ComfyUI process (PID: {process.pid}).")
        except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
            log(f"Error while terminating process: {e}")

def launch_comfyui():
    """Launch ComfyUI as a subprocess and direct its output to a dated log file."""
    comfyui_log_file = os.path.join(LOG_DIR, f"comfyui_log_{datetime.now().strftime('%Y-%m-%d')}.log")
    args = [
        "python", os.path.join(COMFYUI_DIR, "main.py"), f"--port={SERVER_PORT}"
    ]

    # Add custom parameters from .env if specified
    if CUSTOM_PARAMETERS:
        args += CUSTOM_PARAMETERS.split()

    # Add custom paths if enabled
    if USE_CUSTOM_PATHS:
        args += [
            f"--input-directory={INPUT_DIR}",
            f"--output-directory={OUTPUT_DIR}",
            f"--temp-directory={TEMP_DIR}"
        ]

    log(f"Launching ComfyUI with args: {' '.join(args)}")
    log(f"ComfyUI output will be logged to: {comfyui_log_file}")

    with open(comfyui_log_file, "a") as log_file:
        return subprocess.Popen(args, stdout=log_file, stderr=log_file)

def is_server_responding():
    """Check if the server is responding at the specified port."""
    try:
        response = requests.get(f"http://127.0.0.1:{SERVER_PORT}")
        return response.status_code == 200
    except requests.ConnectionError:
        return False

def main():
    script_log_filename = setup_logger("script")
    log("Starting ComfyUI management script...")
    log(f"Logs are being written to: {script_log_filename}")

    # Clean up old logs
    clean_old_logs()

    # Ensure any existing ComfyUI instances are terminated before starting a new one
    terminate_existing_comfyui()
    time.sleep(2)  # Brief pause to ensure the process is fully terminated

    # Launch ComfyUI initially
    process = launch_comfyui()
    time.sleep(BOOT_WAIT_TIME)

    while True:
        # Check if the process has exited or the server is not responding
        if process.poll() is not None:
            log("ComfyUI process has exited. Restarting...")
            terminate_existing_comfyui()
            process = launch_comfyui()
            time.sleep(BOOT_WAIT_TIME)
        elif not is_server_responding():
            log("Server not responding. Restarting ComfyUI...")
            terminate_existing_comfyui()
            process = launch_comfyui()
            time.sleep(BOOT_WAIT_TIME)

        # Clean up old logs during each check cycle
        clean_old_logs()

        # Wait before the next check
        time.sleep(MONITOR_INTERVAL)

if __name__ == "__main__":
    main()
