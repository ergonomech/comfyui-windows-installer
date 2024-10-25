import os
import shutil
import subprocess
import git
from git.exc import InvalidGitRepositoryError, NoSuchPathError, GitCommandError
from dotenv import load_dotenv
import yaml
from tqdm import tqdm
import stat

# Load environment variables
load_dotenv()

# Determine the paths from the environment variables or set default values
COMFYUI_DIR = os.getenv("COMFYUI_DIR", os.path.join(os.getenv("USERPROFILE"), "ComfyUI"))
MODEL_BASE_PATH = os.getenv("MODEL_BASE_PATH", os.path.join(COMFYUI_DIR, "models"))

# Configuration file for model repositories
MODEL_CONFIG_FILE = "model_config.yaml"

def setup_git_lfs():
    """Ensure Git LFS is installed and set up."""
    try:
        subprocess.run(["git", "lfs", "install"], check=True)
        print("Git LFS installed successfully.")
    except subprocess.CalledProcessError:
        print("Error: Git LFS installation failed. Please ensure Git LFS is available on your system.")
        exit(1)

def on_rm_error(func, path, exc_info):
    """Handle errors when attempting to delete read-only files."""
    os.chmod(path, stat.S_IWRITE)
    func(path)

def sparse_checkout(repo_url, model_dest_path, include_files):
    """Clone a repository with a sparse checkout for specific files."""
    os.makedirs(model_dest_path, exist_ok=True)
    print(f"Performing sparse checkout for {repo_url} into {model_dest_path}...")

    # Initialize a new git repository
    subprocess.run(["git", "init"], cwd=model_dest_path, check=True)
    subprocess.run(["git", "remote", "add", "origin", repo_url], cwd=model_dest_path, check=True)
    subprocess.run(["git", "config", "core.sparseCheckout", "true"], cwd=model_dest_path, check=True)

    # Write the files to be included in the sparse checkout
    sparse_checkout_path = os.path.join(model_dest_path, ".git", "info", "sparse-checkout")
    if include_files:
        with open(sparse_checkout_path, "w") as f:
            for include_file in include_files:
                f.write(f"{include_file}\n")
    else:
        print(f"No specific files provided for sparse checkout; proceeding with full repository pull.")

    # Perform the sparse checkout
    subprocess.run(["git", "pull", "origin", "main"], cwd=model_dest_path, check=True)
    print(f"Sparse checkout complete for {model_dest_path}.")

def update_repository(repo_url, model_dest_path, include_files=None):
    """Update the repository using git pull, applying sparse checkout if needed."""
    try:
        repo = git.Repo(model_dest_path)
        origin = repo.remotes.origin
        print(f"Attempting to update repository at {model_dest_path}...")
        
        # Apply sparse-checkout if specific files are defined
        if include_files:
            sparse_checkout(repo_url, model_dest_path, include_files)
        else:
            origin.pull()
            print(f"Repository at {model_dest_path} updated with git pull.")
    except InvalidGitRepositoryError:
        print(f"{model_dest_path} is not a valid Git repository. Attempting to fix...")
        # If .git exists but is corrupted, remove it and retry
        git_folder_path = os.path.join(model_dest_path, ".git")
        if os.path.exists(git_folder_path):
            shutil.rmtree(git_folder_path, onerror=on_rm_error)
            print(f"Removed corrupted .git directory at {git_folder_path}. Reinitializing repository...")
            sparse_checkout(repo_url, model_dest_path, include_files)
        else:
            print(f"Reinitializing the repository at {model_dest_path}...")
            sparse_checkout(repo_url, model_dest_path, include_files)
    except NoSuchPathError:
        print(f"Path {model_dest_path} does not exist. Attempting to clone...")
        sparse_checkout(repo_url, model_dest_path, include_files)
    except GitCommandError as e:
        print(f"Git command error at {model_dest_path}: {str(e)}")
        print("Attempting to reset repository and retry...")
        try:
            repo.git.reset("--hard")
            repo.git.clean("-xdf")
            origin.pull()
            print(f"Repository at {model_dest_path} updated after reset and clean.")
        except Exception as e2:
            print(f"Failed to reset and update repository at {model_dest_path}: {str(e2)}")

def clone_or_update_repository(repo_url, model_type_folder, model_name, include_folder=None, include_files=None):
    """Clone a repository or update if it exists."""
    model_dest_path = os.path.join(MODEL_BASE_PATH, model_type_folder, model_name)
    print(f"Processing {model_name} in {model_type_folder}...")

    # Clone or update the repository
    if os.path.exists(model_dest_path):
        print(f"Repository already exists at {model_dest_path}. Attempting to update...")
        update_repository(repo_url, model_dest_path, include_files)
    else:
        os.makedirs(model_dest_path, exist_ok=True)
        if include_files:
            sparse_checkout(repo_url, model_dest_path, include_files)
        else:
            try:
                with tqdm(total=100, desc=f"Cloning {model_name}", unit="files") as pbar:
                    def update_progress(op_code, cur_count, max_count=None, message=""):
                        if max_count:
                            percentage = (cur_count / max_count) * 100
                            pbar.update(percentage - pbar.n)

                    git.Repo.clone_from(repo_url, model_dest_path, progress=update_progress)
                print(f"Repository cloned into {model_dest_path}.")
            except Exception as e:
                print(f"Failed to clone {model_name}: {str(e)}")
                return

    # Include only a specific folder if specified
    if include_folder:
        included_path = os.path.join(model_dest_path, include_folder)
        for item in os.listdir(model_dest_path):
            item_path = os.path.join(model_dest_path, item)
            if item_path != included_path:
                if os.path.isdir(item_path):
                    shutil.rmtree(item_path, onerror=on_rm_error)
                else:
                    os.remove(item_path)
        print(f"Including only {include_folder} in {model_name}.")

def load_model_config():
    """Load model configuration from YAML file."""
    if not os.path.exists(MODEL_CONFIG_FILE):
        print(f"Configuration file {MODEL_CONFIG_FILE} not found. Please create it with the required model setup.")
        exit(1)
    
    with open(MODEL_CONFIG_FILE, "r") as config_file:
        return yaml.safe_load(config_file)

def main():
    print("Starting model installation...")

    # Ensure Git LFS is installed
    setup_git_lfs()

    # Load model configuration
    model_config = load_model_config()

    # Process each model configuration
    for model_type, models in model_config.items():
        for model_name, settings in models.items():
            repo_url = settings.get("repo_url")
            include_folder = settings.get("include_folder")
            include_files = settings.get("include_files")

            if repo_url:
                clone_or_update_repository(repo_url, model_type, model_name, include_folder, include_files)
            else:
                print(f"Invalid configuration for {model_name} under {model_type}. Skipping...")

    print("Model installation complete.")

if __name__ == "__main__":
    main()
