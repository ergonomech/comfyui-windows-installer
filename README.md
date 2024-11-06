# ComfyUI Installation and Launcher for Windows
![Header](readme_assets/header.png)

This guide provides detailed instructions for setting up and running ComfyUI on Windows using Miniconda. The goal is to simplify the installation process, integrate essential plugins for enhanced usability, and enable error correction with automatic relaunching of the server when needed. Additionally, it allows storing cache and models on separate drives, such as NAS or DAS storage, for optimized performance and storage management.

## Prerequisites

Before running the installer, ensure that your system meets the following requirements:

1. **Latest NVIDIA Driver**
   - Download and install the latest NVIDIA drivers for your GPU from the [NVIDIA Driver Download page](https://www.nvidia.com/Download/index.aspx)
   
2. **Microsoft Visual C++ Build Tools**
   - Install the Microsoft C++ Build Tools, which are necessary for compiling certain Python packages
   - [Download Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   
3. **Miniconda**
   - Install Miniconda for managing the Python environment
   - [Download Miniconda](https://docs.conda.io/en/latest/miniconda.html)
   - After installing Miniconda, initialize Conda by running the conda created console as Administrator:
     ```bash
     conda init --all --system
     ```

4. **Git**
   - Install Git for cloning repositories and model management
   - [Download Git](https://git-scm.com/downloads)
   - Ensure Git LFS is installed for large file handling

## Installation

1. **Get the Installation Files**
   - Clone this repository or download the provided scripts
   - Ensure all batch files are in the same directory

2. **Configure Environment Settings**
   - Edit the `.env` file to customize your installation:
     - Set model paths for external storage
     - Configure cache locations
     - Adjust environment variables
     - Set custom directories for input/output

3. **Run the Installation**
   ```bash
   install_comfy_windows.bat
   ```
   This will:
   - Create a new Conda environment
   - Install all required dependencies
   - Clone ComfyUI and essential plugins
   - Configure your specified paths

## Model Installation

Use `install_models.bat` to manage your model installation:
```bash
install_models.bat
```

Models are configured in `model_config.yaml` with the following structure:
```yaml
unet:
  model_name:
    repo_url: "https://huggingface.co/..."
    include_files:
      - specific_file.safetensors
    
vae:
  model_name:
    repo_url: "https://huggingface.co/..."
    include_folder: vae
```

## Launching ComfyUI

### Standard Launch
Start ComfyUI using the launcher script:
```bash
launch_comfyui.bat
```
Access the web interface at: `http://127.0.0.1:8188`

### Running as a Windows Service

For a more robust setup, you can run ComfyUI as a Windows service using NSSM:

1. **Install NSSM**
   - Download NSSM from [nssm.cc](https://nssm.cc/download)
   - Extract nssm.exe to a permanent location
   - Add the NSSM directory to your system PATH

2. **Create the Service**
   ```bash
   nssm install ComfyUI
   ```

3. **Configure Service Settings**
   In the NSSM configuration window:
   - Application Path: Full path to `launch_comfyui.bat`
   - Start Directory: Your ComfyUI installation directory
   - Service Name: ComfyUI
   - Log on Tab: Select 'This Account' and use your Windows account
   - I/O Tab: Set output and error logs paths

4. **Start the Service**
   ```bash
   nssm start ComfyUI
   ```

5. **Additional Service Management**
   ```bash
   nssm stop ComfyUI            # Stop the service
   nssm restart ComfyUI         # Restart the service
   nssm remove ComfyUI confirm  # Remove the service
   nssm edit ComfyUI           # Edit service configuration
   ```

## Maintaining Your Installation

### Updates
Update your installation with:
```bash
install_update_comfyui.bat
```

### Uninstallation
Remove the installation with:
```bash
uninstall_comfyui.bat
```

## Included Custom Nodes
- ComfyUI-Manager: Management interface
- rgthree-comfy: Enhanced node collection
- ComfyUI_IPAdapter_plus: IP-Adapter integration
- ComfyUI-Impact-Pack: Advanced processing nodes
- ComfyUI-Inspire-Pack: Creative workflow nodes
- ComfyUI_ExtraModels: Additional model support
- ComfyUI-GGUF: GGUF model support
- comfyui-reactor-node: Face processing tools
- ComfyUI-Adaptive-Guidance: Enhanced sampling controls

## License
This project is released under the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments
- ComfyUI by [comfyanonymous](https://github.com/comfyanonymous/ComfyUI)
- All custom node developers listed in the included nodes section

For issues, updates, and contributions, please visit the project repository.