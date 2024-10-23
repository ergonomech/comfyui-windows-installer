
# ComfyUI Installation and Launcher for Windows

This guide provides detailed instructions for setting up and running ComfyUI on Windows using Miniconda. Follow the steps below to ensure a successful installation.

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
   conda init
   ```

4. **Git**
   - Install Git for cloning the ComfyUI repository and plugins:
     - [Download Git](https://git-scm.com/downloads)

## Installation

1. **Clone this repository** or download the provided scripts:
   - Make sure `install_comfy_windows.bat` and `launch_comfyui.bat` are in the same directory.

2. **Run the Installer**:
   - Open a terminal or Command Prompt and run:

     ```bash
     install_comfy_windows.bat
     ```

   - This will set up a new Conda environment with the required dependencies, clone ComfyUI and plugins, and configure paths.

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

## Customization

- **Model Paths**: The script will automatically create or update an `extra_model_paths.yaml` file in the ComfyUI directory. You can manually edit this file to change model paths as needed.
- **Input, Output, and Temp Directories**: Modify the `launch_comfyui.bat` script to change the paths for `--input-directory`, `--output-directory`, and `--temp-directory`.

## Environment Variables

The following environment variables are set during the launch process to optimize performance:

- `PYTORCH_CUDA_ALLOC_CONF`: Configured for expandable segments to manage CUDA memory.
- `CUDA_LAUNCH_BLOCKING`: Ensures CUDA operations are synchronous.
- `TORCH_USE_CUDA_DSA`: Enables CUDA Dynamic Shape Allocation for better memory handling.

Feel free to adjust these settings in `launch_comfyui.bat` if needed.

## Uninstallation

To remove the ComfyUI environment and all installed plugins:

1. Open a terminal or Command Prompt.
2. Run the following command to remove the Conda environment:

   ```bash
   conda env remove -n ComfyUI
   ```

3. Delete the `ComfyUI` directory manually:

   ```bash
   rmdir /S /Q %USERPROFILE%\ComfyUI
   ```

## Troubleshooting

- **`conda init` Error**: If you see an error about needing to run `conda init`, ensure you close and reopen your terminal after running `conda init` as instructed in the prerequisites.
- **Missing `onnxruntime-gpu`**: If `onnxruntime-gpu` fails to install, ensure that you have a compatible version of the NVIDIA driver and CUDA installed.

## Acknowledgments

- **ComfyUI**: Developed by [ComfyUI's creator](https://github.com/comfyanonymous/ComfyUI). This tool provides a highly flexible user interface for interacting with diffusion models.
- **Plugin Developers**:
  - [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)
  - [rgthree-comfy](https://github.com/rgthree/rgthree-comfy)
  - [comfyui-reactor-node](https://github.com/Gourieff/comfyui-reactor-node)
  - [was-node-suite-comfyui](https://github.com/WASasquatch/was-node-suite-comfyui)
  - [ComfyUI-Inspire-Pack](https://github.com/ltdrdata/ComfyUI-Inspire-Pack)
  - [ComfyUI-UX-Nodes](https://github.com/Anibaaal/ComfyUI-UX-Nodes)
  - [ComfyUI Extra Models](https://github.com/city96/ComfyUI_ExtraModels)

Please make sure to support and credit these developers for their work in enhancing the functionality of ComfyUI.

## License

This setup script is provided under the [MIT License](https://opensource.org/licenses/MIT). Feel free to modify and distribute it as needed.
