
# ComfyUI Installation and Launcher for Windows
![Header](readme_assets/header.png)

This guide provides detailed instructions for setting up and running ComfyUI on Windows using Miniconda. The goal is to simplify the installation process, integrate essential plugins for enhanced usability, and enable error correction with automatic relaunching of the server when needed. Additionally, it allows storing cache and models on separate drives, such as NAS or DAS storage, for optimized performance and storage management.

## Prerequisites

Before running the installer, ensure that your system meets the following requirements:

1. **Latest NVIDIA Driver**
   - Download and install the latest NVIDIA drivers for your GPU from the [NVIDIA Driver Download page](https://www.nvidia.com/Download/index.aspx).
   
2. **Microsoft Visual C++ Build Tools**
   - Install the Microsoft C++ Build Tools, which are necessary for compiling certain Python packages:
     - [Download Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   
3. **Miniconda**
   - Install Miniconda for managing the Python environment. You can download Miniconda from the link below:
     - [Download Miniconda](https://docs.conda.io/en/latest/miniconda.html)
   
   After installing Miniconda, ensure you run the following command in your terminal or Command Prompt to initialize Conda for your shell:
   
   ```bash
   conda init --all --system
   ```

4. **Git**
   - Install Git for cloning the ComfyUI repository and plugins:
     - [Download Git](https://git-scm.com/downloads)

## Installation

1. **Clone this repository** or download the provided scripts:
   - Make sure `install_comfy_windows.bat` and `launch_comfyui.bat` are in the same directory.

2. **Edit the .env File**:
   - Before running the installer, edit the `.env` file to set your custom paths, environment options, and other variables like model paths or directories. This file allows you to specify the location of models, cache, and other configurations to use external drives like NAS or DAS for storage.

3. **Run the Installer**:
   - Open a terminal or Command Prompt and run:

     ```bash
     install_comfy_windows.bat
     ```

   - This will set up a new Conda environment with the required dependencies, clone ComfyUI and plugins, and configure paths.

## Model Installation

After installing ComfyUI, use the `install_models.bat` script to install or update models. The script uses configurations to specify model types (unet, vae, clip) and Hugging Face repositories.

### How to configure models:

- Models are organized under folders like `unet`, `vae`, and `clip`.
- In the `.env` file or config file, specify the repositories and any filtering needed for files or folders.

For example:

```bash
[unet]
repo=https://huggingface.co/mikeyandfriends/PixelWave_FLUX.1-schnell_01

[vae]
repo=https://huggingface.co/black-forest-labs/FLUX.1-schnell
include_folder=vae

[clip]
repo=https://huggingface.co/comfyanonymous/flux_text_encoders
exclude_file=t5xxl_fp16.safetensors
```

The script supports sparse checkouts to include/exclude specific files or directories for efficient cloning.

### Cloning with Git LFS:

The model installer uses Git LFS for handling large files. If the model repository uses LFS, the installer automatically initializes Git LFS and pulls the required files.

## Sample Workflow JSONs

Two sample workflow JSON files are included in this repository, which can be loaded directly into ComfyUI to demonstrate example use cases and configurations.

## Launching ComfyUI

1. **Run the Launcher**:
   - After installation is complete, run:

     ```bash
     launch_comfyui.bat
     ```

   - This will activate the Conda environment, set the necessary environment variables, and start the ComfyUI server.

2. **Access the Web Interface**:
   - Once the server is running, open a web browser and navigate to:

     ```
     http://127.0.0.1:8188
     ```

## Uninstallation

To remove the ComfyUI environment and all installed plugins:

1. Open a terminal or Command Prompt.
2. Run the following command to remove the Conda environment:

   ```bash
   conda env remove -n ComfyUI
   ```

3. Run the uninstallation script provided:

   ```bash
   uninstall_comfyui.bat
   ```

   This will clean up the installed files and directories.

## Updating ComfyUI

To update ComfyUI and all installed plugins, run:

```bash
update_comfyui.bat
```

This script pulls the latest changes from the repositories for both ComfyUI and its plugins.

### Schedule Automatic Updates

To automate updates, you can schedule a task to run the update script every Sunday at 12:00 AM GMT. This task will stop the running ComfyUI service, run the update, and restart the service. Follow these steps:

1. Open PowerShell as an Administrator.
2. Run the following command to create a scheduled task:

   ```powershell
   schtasks /create /tn "UpdateComfyUI" /tr "powershell -Command "Stop-Service ComfyUI; Start-Process 'C:\path\to\update_comfyui.bat' -Wait; Start-Service ComfyUI"" /sc weekly /d SUN /st 00:00
   ```

   Replace `C:\path\to\` with the actual path where `update_comfyui.bat` is located. This will schedule the update to run every Sunday at midnight GMT.

## Running as a Service with NSSM

To run ComfyUI as a service using `nssm.exe`, follow these steps:

1. **Download NSSM**:
   - Get the NSSM executable from [nssm.cc](https://nssm.cc/download).
   
2. **Install ComfyUI as a Service**:
   - Run the following commands in a terminal:

     ```bash
     nssm install ComfyUI
     ```

   - In the NSSM setup window, configure the path to `launch_comfyui.bat` as the application start file.
   - Set the service to run as the user account instead of the local service account for proper file access.

3. **Start the Service**:
   - Start the service using:

     ```bash
     nssm start ComfyUI
     ```

   - ComfyUI will now run as a background service, automatically starting with Windows and restarting if it encounters errors.

## Acknowledgments

- **ComfyUI**: Developed by [ComfyUI's creator](https://github.com/comfyanonymous/ComfyUI). This tool provides a highly flexible user interface for interacting with diffusion models.
- **Plugin Developers**:
  - [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)
  - [rgthree-comfy](https://github.com/rgthree/rgthree-comfy)
  - [comfyui-reactor-node](https://github.com/Gourieff/comfyui-reactor-node)
  - [ComfyUI-Inspire-Pack](https://github.com/ltdrdata/ComfyUI-Inspire-Pack)
  - [ComfyUI-UX-Nodes](https://github.com/Anibaaal/ComfyUI-UX-Nodes)
  - [ComfyUI Extra Models](https://github.com/city96/ComfyUI_ExtraModels)

Please make sure to support and credit these developers for their work in enhancing the functionality of ComfyUI.

## License

This setup script is provided under the [MIT License](https://opensource.org/licenses/MIT). Feel free to modify and distribute it as needed.
