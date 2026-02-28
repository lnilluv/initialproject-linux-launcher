# InitialProject Linux Launcher

Portable installer/launcher for running this packaged Windows Unreal game on Linux with Wine.

## What It Does

- Detects distro package manager (`pacman`, `apt`, `dnf`, `zypper`)
- Installs missing dependencies (`wine`, `winetricks`, `vulkan-tools`, `desktop-file-utils`)
- Creates dedicated Wine prefix
- Installs required winetricks components: `vcrun2022 corefonts dxvk vkd3d`
- Generates a reusable launcher script and desktop shortcuts
- Launches game in DX12 by default

## Quick Start

From this `Windows` folder:

```bash
chmod +x setup-and-run.sh
./setup-and-run.sh
```

## Options

```bash
./setup-and-run.sh --check-only
./setup-and-run.sh --dx11
./setup-and-run.sh --dx12
./setup-and-run.sh --prefix "$HOME/Games/initialproject-prefix"
./setup-and-run.sh --launcher "$HOME/Games/launch-initialproject.sh"
```

## Optional GPU Selection

If you have multiple GPUs and want to force one, set this before launch:

```bash
export GPU_FILTER_DEVICE_NAME="AMD Radeon RX 7900 XTX"
```

The generated launcher reads this variable and applies it to DXVK/VKD3D filters.

## Outputs

- Launcher script: `$HOME/Games/launch-initialproject.sh`
- App menu shortcut: `$HOME/.local/share/applications/initialproject.desktop`
- Desktop shortcut: `$HOME/Desktop/Initial Project.desktop` (if Desktop exists)

## Notes

- This script does not install or manage GPU drivers.
- DX12 is default. Use `--dx11` if needed.

## Validation

Run the lightweight tests:

```bash
bash tests/test_setup.sh
```
