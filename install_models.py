import os
import sys
import yaml
import logging
import hashlib
import threading
import shutil
from pathlib import Path
from typing import Optional, Dict, List, Set
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
from huggingface_hub import (
    HfApi, 
    hf_hub_download, 
    snapshot_download,
    create_repo, 
    HfFolder,
    CommitOperationAdd
)
from dotenv import load_dotenv

class ModelInstaller:
    def __init__(self):
        # Get script directory
        self.script_dir = Path(__file__).parent.resolve()
        
        # Load environment variables from script directory
        env_file = self.script_dir / '.env'
        if env_file.exists():
            load_dotenv(env_file)
        
        # Setup paths
        self.user_home = Path(os.environ["USERPROFILE"])
        self.comfyui_dir = Path(os.getenv("COMFYUI_DIR", self.user_home / "ComfyUI"))
        self.model_dir = Path(os.getenv("MODEL_BASE_PATH", self.comfyui_dir / "models")).resolve()
        
        # Initialize logging
        self.setup_logging()
        
        # Log paths for debugging
        self.logger.info(f"Script directory: {self.script_dir}")
        self.logger.info(f"Model directory: {self.model_dir}")
        
        # Setup HF client
        self.api = HfApi()
        self.token = os.getenv("HF_TOKEN")
        if self.token:
            HfFolder.save_token(self.token)
            self.logger.info("Hugging Face token configured")
        else:
            self.logger.info("No Hugging Face token found, will use anonymous access")
        
        # Define folder structure
        self.folder_structure = {
            'checkpoints': 'checkpoints',
            'clip': 'clip',
            'clip_vision': 'clip_vision',
            'configs': 'configs',
            'controlnet': 'controlnet',
            'diffusion_models': 'diffusion_models',
            'unet': 'unet',
            'embeddings': 'embeddings',
            'loras': 'loras',
            'text_encoders': 'text_encoders',
            'upscale_models': 'upscale_models',
            'vae': 'vae'
        }
        
        # Create model directory structure
        self.setup_folder_structure()
        
        # Initialize download tracking
        self.downloaded_files: Set[Path] = set()
        self.download_lock = threading.Lock()
    
    def setup_logging(self):
        """Configure logging with timestamps and proper formatting."""
        log_dir = self.script_dir / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = log_dir / f"model_install_{timestamp}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s | %(levelname)s | %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        
        self.logger = logging.getLogger("ModelInstaller")
    
    def setup_folder_structure(self):
        """Create necessary folder structure for models."""
        try:
            self.model_dir.mkdir(parents=True, exist_ok=True)
            
            for folder in self.folder_structure.values():
                folder_path = self.model_dir / folder
                folder_path.mkdir(parents=True, exist_ok=True)
                self.logger.info(f"Created/verified folder: {folder_path}")
            
        except Exception as e:
            self.logger.error(f"Error creating folder structure: {e}")
            raise
    
    def verify_file_integrity(self, file_path: Path, repo_id: str, filename: str) -> bool:
        """Verify if a file exists and matches the remote hash."""
        if not file_path.exists():
            return False
        
        try:
            # Get remote file info
            try:
                info = self.api.model_info(repo_id, files_metadata=True)
            except Exception as e:
                if self.token:
                    info = self.api.model_info(repo_id, files_metadata=True, token=self.token)
                else:
                    self.logger.error(f"Could not access repository {repo_id}: {e}")
                    return False
            
            # Find file info and verify hash
            for file_info in info.siblings:
                if file_info.rfilename == filename:
                    sha256_hash = hashlib.sha256()
                    with open(file_path, "rb") as f:
                        for byte_block in iter(lambda: f.read(4096), b""):
                            sha256_hash.update(byte_block)
                    
                    if sha256_hash.hexdigest() == file_info.sha256:
                        return True
                    else:
                        self.logger.warning(f"Hash mismatch for {filename}")
                        return False
            
            self.logger.warning(f"File {filename} not found in repository metadata")
            return False
            
        except Exception as e:
            self.logger.error(f"Error verifying {filename}: {e}")
            return False
    
    def download_file(self, 
                     repo_id: str, 
                     filename: str, 
                     model_type: str,
                     subfolder: Optional[str] = None,
                     force: bool = False) -> Optional[Path]:
        """Download a specific file from a repository."""
        try:
            if model_type == 'clip':
                model_type = 'text_encoders'
            
            type_dir = self.model_dir / model_type
            dest_dir = type_dir / repo_id.split('/')[-1]
            if subfolder:
                dest_dir = dest_dir / subfolder
            
            file_path = dest_dir / filename
            
            # Check if file exists and is valid
            if not force and file_path.exists():
                if self.verify_file_integrity(file_path, repo_id, filename):
                    self.logger.info(f"File already exists and is valid: {filename}")
                    with self.download_lock:
                        self.downloaded_files.add(file_path)
                    return file_path
                else:
                    self.logger.warning(f"File exists but is invalid, re-downloading: {filename}")
            
            # Create directory if needed
            dest_dir.mkdir(parents=True, exist_ok=True)
            
            # Try download without token first
            try:
                local_file = hf_hub_download(
                    repo_id=repo_id,
                    filename=filename,
                    local_dir=dest_dir,
                    local_dir_use_symlinks=False,
                    force_download=True
                )
            except Exception as e:
                if self.token:
                    local_file = hf_hub_download(
                        repo_id=repo_id,
                        filename=filename,
                        local_dir=dest_dir,
                        local_dir_use_symlinks=False,
                        token=self.token,
                        force_download=True
                    )
                else:
                    raise e
            
            downloaded_path = Path(local_file)
            with self.download_lock:
                self.downloaded_files.add(downloaded_path)
            
            return downloaded_path
            
        except Exception as e:
            self.logger.error(f"Error downloading {filename} from {repo_id}: {e}")
            return None
    
    def download_repository(self, 
                          repo_id: str,
                          model_type: str,
                          include_files: Optional[List[str]] = None,
                          exclude_files: Optional[List[str]] = None,
                          include_folder: Optional[str] = None,
                          force: bool = False) -> bool:
        """Download repository with proper folder structure."""
        try:
            if model_type == 'clip':
                model_type = 'text_encoders'
            
            type_dir = self.model_dir / model_type
            dest_dir = type_dir / repo_id.split('/')[-1]
            
            self.logger.info(f"Processing repository: {repo_id} -> {dest_dir}")
            
            if include_files:
                success = True
                with ThreadPoolExecutor(max_workers=4) as executor:
                    futures = []
                    for filename in include_files:
                        future = executor.submit(
                            self.download_file,
                            repo_id,
                            filename,
                            model_type,
                            include_folder,
                            force
                        )
                        futures.append((future, filename))
                    
                    with tqdm(total=len(futures), desc=f"Downloading {repo_id}") as pbar:
                        for future, filename in futures:
                            try:
                                result = future.result()
                                if not result:
                                    success = False
                                pbar.update(1)
                            except Exception as e:
                                self.logger.error(f"Error downloading {filename}: {e}")
                                success = False
                                pbar.update(1)
                
                return success
            
            else:
                if not force and dest_dir.exists() and any(dest_dir.iterdir()):
                    if all(self.verify_file_integrity(f, repo_id, f.name) 
                          for f in dest_dir.rglob("*") if f.is_file()):
                        self.logger.info(f"Repository already exists and is valid: {repo_id}")
                        return True
                    else:
                        self.logger.warning(f"Repository exists but has invalid files: {repo_id}")
                
                # Download entire repository or folder
                allow_patterns = None
                if include_folder:
                    allow_patterns = [f"{include_folder}/*"]
                
                ignore_patterns = None
                if exclude_files:
                    ignore_patterns = [f"*/{f}" for f in exclude_files]
                
                try:
                    snapshot_download(
                        repo_id=repo_id,
                        local_dir=dest_dir,
                        local_dir_use_symlinks=False,
                        allow_patterns=allow_patterns,
                        ignore_patterns=ignore_patterns,
                        force_download=force
                    )
                except Exception as e:
                    if self.token:
                        snapshot_download(
                            repo_id=repo_id,
                            local_dir=dest_dir,
                            local_dir_use_symlinks=False,
                            token=self.token,
                            allow_patterns=allow_patterns,
                            ignore_patterns=ignore_patterns,
                            force_download=force
                        )
                    else:
                        raise e
                
                return True
        
        except Exception as e:
            self.logger.error(f"Error downloading repository {repo_id}: {e}")
            return False
    
    def cleanup_partial_downloads(self):
        """Clean up any partially downloaded files."""
        try:
            for root, dirs, files in os.walk(self.model_dir):
                for name in files:
                    file_path = Path(root) / name
                    if file_path.suffix == '.temp' or file_path.name.endswith('.download'):
                        try:
                            file_path.unlink()
                            self.logger.info(f"Removed partial download: {file_path}")
                        except Exception as e:
                            self.logger.error(f"Error removing partial download {file_path}: {e}")
        except Exception as e:
            self.logger.error(f"Error during cleanup: {e}")
    
    def process_model_config(self) -> None:
        """Process the model configuration file and download models."""
        config_file = self.script_dir / "model_config.yaml"
        
        if not config_file.exists():
            self.logger.error(f"Configuration file not found: {config_file}")
            return
        
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            
            total_models = sum(len(models) for models in config.values())
            processed = 0
            
            for model_type, models in config.items():
                self.logger.info(f"\nProcessing {model_type} models...")
                
                for model_name, settings in models.items():
                    processed += 1
                    repo_url = settings.get('repo_url')
                    if not repo_url:
                        continue
                    
                    # Extract repo ID from URL
                    repo_id = '/'.join(repo_url.split('/')[-2:])
                    
                    self.logger.info(f"[{processed}/{total_models}] Processing {model_name}...")
                    
                    success = self.download_repository(
                        repo_id=repo_id,
                        model_type=model_type,
                        include_files=settings.get('include_files'),
                        exclude_files=settings.get('exclude_files'),
                        include_folder=settings.get('include_folder'),
                        force=False
                    )
                    
                    if success:
                        self.logger.info(f"Successfully processed {model_name}")
                    else:
                        self.logger.error(f"Failed to process {model_name}")
            
            # Final cleanup
            self.cleanup_partial_downloads()
            
            self.logger.info("\nModel installation complete!")
            
        except Exception as e:
            self.logger.error(f"Error processing model config: {e}")
            raise

def main():
    try:
        installer = ModelInstaller()
        installer.process_model_config()
    except KeyboardInterrupt:
        print("\nInstallation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Critical error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()