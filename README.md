# InitialProject Linux Launcher

Portable installer/launcher for running the packaged Windows Unreal build of Initial Project on Linux with Wine.

## Support Scope

This is a native Linux helper script. It is designed for common x86_64 desktop Linux distros and should also work on other distros when the required runtime commands are already installed.

- Supported auto-install package managers: `pacman`, `apt-get`, `dnf`, `zypper`
- Required commands: `wine`, `wineboot`, `winetricks`
- Recommended commands: `vulkaninfo`, `update-desktop-database`
- GPU drivers are not installed or managed by this script. AMD and NVIDIA both require working Vulkan drivers.

The script checks what is already installed and only tries to install what is missing. Required packages are installed first; recommended package failures do not block launching. Missing required commands must be installed first.

Auto-install is best-effort. Unsupported, read-only, or unusual distros can still run the launcher after installing the required commands manually. Wine/winetricks versions, network access, and working Vulkan GPU drivers still matter.

By default, runtime tools are loaded from normal system locations such as `/usr/bin` and `/bin`. If your distro exposes Wine somewhere else, set `INITIALPROJECT_ALLOW_CUSTOM_RUNTIME_PATH=1` before running the setup script.

## Fresh Clone Quick Start

This repo does **not** include the game binaries. You need the game zip containing `InitialProject.exe`.

Recommended layout:

```text
initialproject-linux-launcher/
  setup-and-run.sh
  Windows/
    InitialProject.exe
    ...other game files...
```

Safest setup: unzip the game into a separate folder, then point the launcher at the folder that contains `InitialProject.exe`.

```bash
git clone https://github.com/lnilluv/initialproject-linux-launcher.git
mkdir -p "$HOME/Games/InitialProject-unpacked"
unzip /path/to/InitialProject.zip -d "$HOME/Games/InitialProject-unpacked"
find "$HOME/Games/InitialProject-unpacked" -name InitialProject.exe -print
cd initialproject-linux-launcher
chmod +x setup-and-run.sh
./setup-and-run.sh --game-dir /path/to/folder-containing-InitialProject.exe
```

If you want to run without `--game-dir`, copy or move the game files so the final path is exactly:

```text
initialproject-linux-launcher/Windows/InitialProject.exe
```

Do not unzip an untrusted game archive directly over the launcher repo root.

## What It Does

- Verifies it is running on Linux
- Validates the game executable path before making system changes
- Detects distro package manager (`pacman`, `apt-get`, `dnf`, `zypper`)
- Installs missing Wine/winetricks/Vulkan desktop helper packages when possible
- Creates a dedicated Wine prefix
- Installs required winetricks components: `vcrun2022 corefonts dxvk vkd3d`
- Generates a reusable launcher script and desktop shortcuts
- Launches the game in DX12 by default

## Options

```bash
./setup-and-run.sh --check-only
./setup-and-run.sh --dx11
./setup-and-run.sh --dx12
./setup-and-run.sh --game-dir /path/to/Windows
./setup-and-run.sh --game-exe InitialProject.exe
./setup-and-run.sh --prefix "$HOME/Games/initialproject-prefix"
./setup-and-run.sh --launcher "$HOME/Games/launch-initialproject.sh"
```

Environment defaults:

```bash
export INITIALPROJECT_GAME_DIR="/path/to/Windows"
export INITIALPROJECT_GAME_EXE="InitialProject.exe"
export INITIALPROJECT_ALLOW_CUSTOM_RUNTIME_PATH=1  # only needed for custom/Nix-style Wine paths
```

## GPU Notes

AMD and NVIDIA can both work. The important requirement is that Vulkan works on your Linux install:

```bash
vulkaninfo --summary
```

For a normal single-GPU desktop, no extra launcher config should be needed.

If you have multiple GPUs and want to force one, set this before launch:

```bash
export GPU_FILTER_DEVICE_NAME="NVIDIA GeForce"
# or: export GPU_FILTER_DEVICE_NAME="AMD Radeon"
```

On NVIDIA hybrid/Optimus laptops, also set:

```bash
export INITIALPROJECT_NVIDIA_OFFLOAD=1
```

The generated launcher reads these variables at launch time. If launching from the app menu, set the variables in your desktop environment or run the generated launcher from a terminal, for example:

```bash
INITIALPROJECT_NVIDIA_OFFLOAD=1 "$HOME/Games/launch-initialproject.sh"
```

## Outputs

- Launcher script: `$HOME/Games/launch-initialproject.sh`
- App menu shortcut: `${XDG_DATA_HOME:-$HOME/.local/share}/applications/initialproject.desktop`
- Desktop shortcut: your XDG desktop directory, if it exists

## Troubleshooting

Run a dependency check:

```bash
./setup-and-run.sh --check-only
```

If your distro is unsupported by the auto-installer, install the required commands with your package manager, then rerun the launcher. Make sure `vulkaninfo` works before troubleshooting DXVK/VKD3D rendering issues.

## Validation

Run the lightweight tests:

```bash
bash tests/test_setup.sh
```
