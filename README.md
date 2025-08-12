# ComfyUI for Windows (Installer + Launcher)

![Header](readme_assets/header.png)

Fast, repeatable ComfyUI setup for Windows 11 with CUDA 12.8. This repo installs a clean Conda environment, the right PyTorch build for your GPU, and a lightweight supervisor that launches ComfyUI headlessly and shuts it down cleanly when you close the window.

Highlights

- Windows 11 tested end-to-end
- Conda env: Python 3.12.11 (falls back to latest 3.12.x if needed)
- PyTorch CUDA 12.8 wheels (fallback to CUDA 12.6 if 12.8 is unavailable)
- Foreground launcher: Ctrl+C or closing the window kills all subprocesses
- Log-based watcher (no HTTP probes), gentler restarts, rotating logs

> Status (2025-08-12)
>
> ComfyUI Desktop exists, but this installer is still maintained for users who want to host or run ComfyUI as a service/foreground process on Windows. The scripts and CUDA 12.8/Python 3.12.11 stack are up to date and ready.

## Prerequisites

Make sure you have:

- NVIDIA GPU drivers (latest) — <https://www.nvidia.com/Download/index.aspx>
- Git — <https://git-scm.com/downloads> (Git LFS recommended)
- Miniconda — <https://docs.conda.io/en/latest/miniconda.html>

   After install, in an elevated Conda prompt run:

   ```bat
   conda init --all --system
   ```

- (Optional) Microsoft Visual C++ Build Tools — some nodes may need it: <https://visualstudio.microsoft.com/visual-cpp-build-tools/>

## Install or Update

1) Clone or download this repository.
2) Run the installer:

   ```bat
   install_update_comfyui.bat
   ```

What it does

- Creates/uses Conda env "ComfyUI" with Python 3.12.11
- Installs PyTorch + CUDA 12.8 (falls back to 12.6 if needed)
- Installs onnxruntime-gpu (falls back to CPU)
- Clones/updates ComfyUI into `%USERPROFILE%\ComfyUI`
- Adds a few helpful custom nodes (see below)
- Verifies versions and cleans pip cache

## Models

Use the helper to fetch models defined in `model_config.yaml`:

```bat
install_models.bat
```

`model_config.yaml` example:

```yaml
unet:
   my_model:
      repo_url: "https://huggingface.co/..."
      include_files:
         - example.safetensors

vae:
   another:
      repo_url: "https://huggingface.co/..."
      include_folder: vae
```

## Launch

Start ComfyUI:

```bat
launch_comfyui.bat
```

- Opens at: <http://127.0.0.1:8188> (default)
- Foreground by default — close the window to stop everything
- Logs live under `logs/` (rotated)

Quiet output

- Set `HEADLESS=1` before launching to suppress the environment summary prints (process still runs foreground):

   ```bat
   set HEADLESS=1 && launch_comfyui.bat
   ```

## Configuration (.env is optional)

You don’t need a `.env` file. Defaults work out of the box. If you want to customize paths/port/flags:


- HEADLESS: Quiet mode for launcher prints (1=quiet, 0=show env summary)
- COMFYUI_ENV_NAME: Conda environment name (default: ComfyUI)

Watcher tuning (advanced)

- ENABLE_NO_OUTPUT_RESTART=1
- NO_OUTPUT_RESTART_SECS=600
- QUIET_CPU_THRESHOLD=2.0
- QUIET_CPU_WINDOW_SECS=300
- BOOT_WAIT_TIME=1600
- MONITOR_INTERVAL=10

## Included Custom Nodes

The installer clones/updates these by default:

- ComfyUI-Manager — <https://github.com/ltdrdata/ComfyUI-Manager>
- rgthree-comfy — <https://github.com/rgthree/rgthree-comfy>
- ComfyUI_ExtraModels — <https://github.com/city96/ComfyUI_ExtraModels>
- ComfyUI-GGUF — <https://github.com/city96/ComfyUI-GGUF>

You can add more by cloning into `ComfyUI/custom_nodes/`.

## Service mode (optional)

If you prefer running as a background service, tools like NSSM work well. Point the service to `launch_comfyui.bat` and set a working directory for logs. Note that Ctrl+C behavior doesn’t apply to services.

## Update / Uninstall

- Update: re-run `install_update_comfyui.bat`
- Uninstall: remove `%USERPROFILE%\ComfyUI` and the Conda env `ComfyUI` (e.g., `conda remove -n ComfyUI --all`)

## Tech notes

- Environment: Conda `ComfyUI`, Python 3.12.11 (or latest 3.12.x)
- PyTorch: CUDA 12.8 wheels by default, CUDA 12.6 fallback
- Supervisor: no HTTP/TCP health checks; uses logs + CPU quiet periods
- Clean shutdown: Ctrl+C or closing the console terminates the whole process tree

## License

MIT. See LICENSE.

## Credits

- ComfyUI by <https://github.com/comfyanonymous/ComfyUI>
- The authors of the included custom nodes
