import os
import sys
import time
import uuid
import subprocess
import requests
import logging
import logging.handlers
import psutil
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional
from dotenv import load_dotenv

class ComfyUILogger:
    """Handles logging with date, UUID, and PID in filename."""
    
    def __init__(self):
        # Get script directory for logs
        self.script_dir = Path(__file__).parent.resolve()
        self.log_dir = self.script_dir / "logs"
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate unique identifiers
        self.session_id = str(uuid.uuid4())[:8]
        self.pid = os.getpid()
        
        # Create log filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_filename = f"comfyui_{timestamp}_{self.session_id}_{self.pid}.log"
        self.log_file = self.log_dir / log_filename
        
        # Configure logger
        self.logger = logging.getLogger("ComfyUIManager")
        self.logger.setLevel(logging.INFO)
        
        # Remove any existing handlers
        self.logger.handlers = []
        
        # Create file handler
        file_handler = logging.FileHandler(self.log_file, encoding='utf-8')
        file_handler.setLevel(logging.INFO)
        
        # Create formatter
        formatter = logging.Formatter(
            '%(asctime)s | %(levelname)s | %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(formatter)
        
        # Add handler to logger
        self.logger.addHandler(file_handler)
        
        # Log initial message
        self.logger.info(f"=== Starting new ComfyUI session ===")
        self.logger.info(f"Session ID: {self.session_id}")
        self.logger.info(f"PID: {self.pid}")
        self.logger.info(f"Log file: {self.log_file}")

    def clean_old_logs(self, days: int = 7):
        try:
            cutoff = datetime.now() - timedelta(days=days)
            for log_file in self.log_dir.glob("comfyui_*.log"):
                file_time = datetime.fromtimestamp(log_file.stat().st_mtime)
                if file_time < cutoff:
                    try:
                        log_file.unlink()
                        self.logger.info(f"Removed old log file: {log_file.name}")
                    except OSError as e:
                        self.logger.error(f"Failed to remove old log {log_file.name}: {e}")
        except Exception as e:
            self.logger.error(f"Error cleaning old logs: {e}")

class ComfyUILauncher:
    def __init__(self):
        # Initialize logger first
        self.logger = ComfyUILogger()
        
        # Load environment variables
        load_dotenv()
        
        # Set up paths
        self.user_home = Path(os.environ["USERPROFILE"])
        self.comfyui_dir = Path(os.getenv("COMFYUI_DIR", self.user_home / "ComfyUI"))
        self.model_base_path = os.getenv("MODEL_BASE_PATH")
        self.input_dir = os.getenv("INPUT_DIR")
        self.output_dir = os.getenv("OUTPUT_DIR")
        self.temp_dir = os.getenv("TEMP_DIR")
        self.server_port = os.getenv("SERVER_PORT", "8188")
        self.custom_parameters = os.getenv("CUSTOM_PARAMETERS", "").split()
        self.monitor_interval = int(os.getenv("MONITOR_INTERVAL", "10"))
        self.boot_wait_time = int(os.getenv("BOOT_WAIT_TIME", "30"))
    
    def _create_model_paths_yaml(self) -> None:
        """Create the extra_model_paths.yaml file if MODEL_BASE_PATH is set."""
        if self.model_base_path:
            yaml_content = f"""
comfyui:
  base_path: {self.model_base_path}
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
"""
            yaml_path = self.comfyui_dir / "extra_model_paths.yaml"
            yaml_path.write_text(yaml_content)
            self.logger.logger.info(f"Created model paths configuration at {yaml_path}")
    
    def _launch_comfyui(self) -> Optional[subprocess.Popen]:
        """Launch ComfyUI process with output redirection."""
        try:
            args = ["python", str(self.comfyui_dir / "main.py"), f"--port={self.server_port}"]
            args.extend(self.custom_parameters)
            
            if self.input_dir:
                args.append(f"--input-directory={self.input_dir}")
            if self.output_dir:
                args.append(f"--output-directory={self.output_dir}")
            if self.temp_dir:
                args.append(f"--temp-directory={self.temp_dir}")
            
            # Set up environment
            env = os.environ.copy()
            env.update({
                "KMP_DUPLICATE_LIB_OK": "TRUE",
                "PYTORCH_CUDA_ALLOC_CONF": "backend:cudaMallocAsync,expandable_segments:True",
                "CUDA_DEVICE_MAX_CONNECTIONS": "20",
                "PYTHONUNBUFFERED": "1"
            })
            
            self.logger.logger.info(f"Launching ComfyUI with arguments: {' '.join(args)}")
            
            def output_reader(pipe, log_func):
                try:
                    with pipe:
                        for line in iter(pipe.readline, ''):
                            log_func(line.strip())
                except Exception as e:
                    self.logger.logger.error(f"Error reading output: {e}")
            
            process = subprocess.Popen(
                args,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                env=env,
                cwd=str(self.comfyui_dir)
            )
            
            import threading
            threading.Thread(
                target=output_reader,
                args=(process.stdout, self.logger.logger.info),
                daemon=True
            ).start()
            threading.Thread(
                target=output_reader,
                args=(process.stderr, self.logger.logger.error),
                daemon=True
            ).start()
            
            return process
            
        except Exception as e:
            self.logger.logger.error(f"Failed to launch ComfyUI: {e}")
            return None
    
    def _is_server_responding(self) -> bool:
        """Check if the ComfyUI server is responding."""
        try:
            response = requests.get(f"http://127.0.0.1:{self.server_port}", timeout=5)
            return response.status_code == 200
        except requests.RequestException:
            return False
    
    def run(self):
        """Run ComfyUI with monitoring and auto-restart."""
        try:
            # Create model paths yaml if needed
            self._create_model_paths_yaml()
            
            while True:
                process = self._launch_comfyui()
                if not process:
                    self.logger.logger.error("Failed to start ComfyUI. Retrying in 10 seconds...")
                    time.sleep(10)
                    continue
                
                # Wait for server startup
                start_time = time.time()
                server_ready = False
                
                while time.time() - start_time < self.boot_wait_time:
                    if self._is_server_responding():
                        server_ready = True
                        self.logger.logger.info("ComfyUI server is ready")
                        break
                    time.sleep(1)
                
                if not server_ready:
                    self.logger.logger.error("Server failed to start within timeout")
                    process.terminate()
                    continue
                
                # Monitor loop
                try:
                    while True:
                        if process.poll() is not None:
                            self.logger.logger.error("ComfyUI process has terminated unexpectedly")
                            break
                        
                        if not self._is_server_responding():
                            self.logger.logger.error("Server not responding")
                            process.terminate()
                            break
                        
                        # Clean old logs periodically
                        self.logger.clean_old_logs()
                        
                        time.sleep(self.monitor_interval)
                        
                except KeyboardInterrupt:
                    raise
                except Exception as e:
                    self.logger.logger.error(f"Error in monitoring loop: {e}")
                    if process.poll() is None:
                        process.terminate()
                    time.sleep(5)
        
        except KeyboardInterrupt:
            self.logger.logger.info("Received shutdown signal")
            if 'process' in locals() and process.poll() is None:
                process.terminate()
        except Exception as e:
            self.logger.logger.error(f"Critical error: {e}")
        finally:
            self.logger.logger.info("ComfyUI launcher stopped")

if __name__ == "__main__":
    launcher = ComfyUILauncher()
    launcher.run()