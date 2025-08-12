import os
import sys
import time
import uuid
import subprocess
import logging
import logging.handlers
import psutil
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional
from dotenv import load_dotenv
import threading
import signal

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
    # Class-level annotations to satisfy static analysis
    _readiness_event: threading.Event
    _last_output_lock: threading.Lock
    _last_output_ts: float
    no_output_restart_secs: int
    monitor_interval: int
    boot_wait_time: int
    server_port: str
    def __init__(self):
        # Initialize logger first
        self.logger = ComfyUILogger()

        # Load environment variables
        load_dotenv(override=True)

        # Set up paths
        self.user_home = Path(os.environ["USERPROFILE"])
        self.comfyui_dir = Path(os.getenv("COMFYUI_DIR", self.user_home / "ComfyUI"))
        self.model_base_path = os.getenv("MODEL_BASE_PATH")
        self.input_dir = os.getenv("INPUT_DIR")
        self.output_dir = os.getenv("OUTPUT_DIR")
        self.temp_dir = os.getenv("TEMP_DIR")
        self.server_port = os.getenv("SERVER_PORT", "8188")
        self.custom_parameters = os.getenv("CUSTOM_PARAMETERS", "").split()

        # Timings and monitoring thresholds
        self.monitor_interval = int(os.getenv("MONITOR_INTERVAL", "10"))
        self.boot_wait_time = int(os.getenv("BOOT_WAIT_TIME", "1600"))
        self.no_output_restart_secs = int(os.getenv("NO_OUTPUT_RESTART_SECS", "600"))
        self.enable_no_output_restart = os.getenv("ENABLE_NO_OUTPUT_RESTART", "1") not in ("0", "false", "False")
        self.quiet_cpu_threshold = float(os.getenv("QUIET_CPU_THRESHOLD", "2.0"))
        self.quiet_cpu_window_secs = int(os.getenv("QUIET_CPU_WINDOW_SECS", "300"))

        # Runtime state for monitoring
        self._readiness_event = threading.Event()
        self._last_output_lock = threading.Lock()
        self._last_output_ts = time.time()
    
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
        """Launch ComfyUI process with output redirection, headless by default."""
        try:
            # Prefer launching directly with the current Python (env already activated by the batch file)
            args = [sys.executable, "-B", "-s", "-u", str(self.comfyui_dir / "main.py"), f"--port={self.server_port}"]
            args.extend(self.custom_parameters)
            
            if self.input_dir:
                args.append(f"--input-directory={self.input_dir}")
            if self.output_dir:
                args.append(f"--output-directory={self.output_dir}")
            if self.temp_dir:
                args.append(f"--temp-directory={self.temp_dir}")
            
            # Set up environment
            env = os.environ.copy()
            
            self.logger.logger.info(f"Launching ComfyUI with arguments: {' '.join(args)}")
            
            def output_reader(pipe, log_func):
                try:
                    with pipe:
                        for line in iter(pipe.readline, ''):
                            line = line.strip()
                            log_func(line)
                            now = time.time()
                            # Update last output timestamp
                            with self._last_output_lock:
                                self._last_output_ts = now
                            # Detect readiness from known messages
                            lower = line.lower()
                            if (
                                "to see the gui" in lower
                                or "running on" in lower
                                or "started server" in lower
                                or "listening on" in lower
                            ):
                                self._readiness_event.set()
                except Exception as e:
                    self.logger.logger.error(f"Error reading output: {e}")
            
            # On Windows, ensure no new console window is created for the child process
            creationflags = 0
            startupinfo = None
            if os.name == "nt":
                creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
                try:
                    si = subprocess.STARTUPINFO()
                    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                    si.wShowWindow = 0  # SW_HIDE
                    startupinfo = si
                except Exception:
                    startupinfo = None

            process = subprocess.Popen(
                args,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                env=env,
                cwd=str(self.comfyui_dir),
                creationflags=creationflags,
                startupinfo=startupinfo
            )
            
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
    
    def _terminate_tree(self, proc: subprocess.Popen, timeout: int = 15):
        """Terminate a process and its children safely."""
        try:
            p = psutil.Process(proc.pid)
        except psutil.Error:
            return
        # Terminate children first
        try:
            for child in p.children(recursive=True):
                try:
                    child.terminate()
                except psutil.Error:
                    pass
        except psutil.Error:
            pass
        # Terminate main process
        try:
            p.terminate()
        except psutil.Error:
            pass
        try:
            proc.wait(timeout=timeout)
        except Exception:
            try:
                p.kill()
            except psutil.Error:
                pass
    
    def run(self):
        """Run ComfyUI with monitoring and auto-restart."""
        process: Optional[subprocess.Popen] = None
        shutdown_event = threading.Event()

        def handle_sig(signum, frame):
            try:
                self.logger.logger.info(f"Received signal {signum}; terminating subprocess tree...")
            except Exception:
                pass
            shutdown_event.set()
            try:
                if process and process.poll() is None:
                    self._terminate_tree(process)
            except Exception:
                pass

        # Register signal handlers for Ctrl+C / termination on Windows
        try:
            signal.signal(signal.SIGINT, handle_sig)
        except Exception:
            pass
        for sig_name in ("SIGTERM", "SIGBREAK"):
            if hasattr(signal, sig_name):
                try:
                    signal.signal(getattr(signal, sig_name), handle_sig)
                except Exception:
                    pass

        # On Windows, also handle console close/logoff/shutdown events
        if os.name == "nt":
            try:
                import ctypes
                from ctypes import wintypes

                kernel32 = ctypes.windll.kernel32
                HandlerRoutine = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.DWORD)

                def _win_ctrl_handler(ctrl_type):
                    # ctrl_type: 0=CTRL_C_EVENT, 1=CTRL_BREAK_EVENT, 2=CTRL_CLOSE_EVENT, 5=CTRL_LOGOFF_EVENT, 6=CTRL_SHUTDOWN_EVENT
                    try:
                        self.logger.logger.info(f"Received console control event {ctrl_type}; terminating subprocess tree...")
                    except Exception:
                        pass
                    try:
                        handle_sig(getattr(signal, "SIGBREAK", 21), None)
                    except Exception:
                        pass
                    return True

                # Keep a reference to avoid GC
                self._win_ctrl_handler_ref = HandlerRoutine(_win_ctrl_handler)
                kernel32.SetConsoleCtrlHandler(self._win_ctrl_handler_ref, True)
            except Exception as e:
                try:
                    self.logger.logger.warning(f"Could not register Windows console handler: {e}")
                except Exception:
                    pass
        try:
            # Create model paths yaml if needed
            self._create_model_paths_yaml()
            
            while not shutdown_event.is_set():
                process = self._launch_comfyui()
                if not process:
                    self.logger.logger.error("Failed to start ComfyUI. Retrying in 10 seconds...")
                    time.sleep(10)
                    continue
                
                # Reset readiness and last output timestamps
                self._readiness_event.clear()
                with self._last_output_lock:
                    self._last_output_ts = time.time()

                # Wait for server startup based on logs
                self.logger.logger.info("Waiting for ComfyUI to become ready (log-based)...")
                server_ready = self._readiness_event.wait(timeout=self.boot_wait_time)
                if shutdown_event.is_set():
                    if process and process.poll() is None:
                        self._terminate_tree(process)
                    break
                
                if not server_ready:
                    # Be lenient: continue monitoring instead of killing; many users suppress logs
                    self.logger.logger.warning("No explicit readiness logs within timeout; continuing to monitor")
                
                # Monitor loop
                try:
                    # Prime CPU percent for accurate readings
                    try:
                        parent_proc = psutil.Process(process.pid)
                        _ = parent_proc.cpu_percent(interval=None)
                    except psutil.Error:
                        parent_proc = None
                    quiet_cpu_accum = 0.0

                    while not shutdown_event.is_set():
                        if process.poll() is not None:
                            self.logger.logger.error("ComfyUI process has terminated unexpectedly")
                            break

                        # Check for prolonged silence from the process (less aggressive)
                        with self._last_output_lock:
                            last = self._last_output_ts
                        silent_secs = time.time() - last

                        # Compute CPU usage across process tree
                        cpu_total = 0.0
                        if parent_proc is not None:
                            try:
                                cpu_total += parent_proc.cpu_percent(interval=None)
                                for ch in parent_proc.children(recursive=True):
                                    try:
                                        cpu_total += ch.cpu_percent(interval=None)
                                    except psutil.Error:
                                        pass
                            except psutil.Error:
                                pass

                        if cpu_total < self.quiet_cpu_threshold:
                            quiet_cpu_accum += self.monitor_interval
                        else:
                            quiet_cpu_accum = 0.0

                        if self.enable_no_output_restart and silent_secs > self.no_output_restart_secs and quiet_cpu_accum >= self.quiet_cpu_window_secs:
                            self.logger.logger.error(
                                f"No output for {int(silent_secs)}s and CPU quiet for {int(quiet_cpu_accum)}s; restarting"
                            )
                            self._terminate_tree(process)
                            break
                        
                        # Clean old logs periodically
                        self.logger.clean_old_logs()
                        
                        time.sleep(self.monitor_interval)
                        
                except KeyboardInterrupt:
                    handle_sig(getattr(signal, "SIGINT", 2), None)
                except Exception as e:
                    self.logger.logger.error(f"Error in monitoring loop: {e}")
                    if process and process.poll() is None:
                        self._terminate_tree(process)
                    time.sleep(5)
            
        except KeyboardInterrupt:
            handle_sig(getattr(signal, "SIGINT", 2), None)
        except Exception as e:
            self.logger.logger.error(f"Critical error: {e}")
        finally:
            self.logger.logger.info("ComfyUI launcher stopped")

if __name__ == "__main__":
    launcher = ComfyUILauncher()
    launcher.run()