#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/install.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wine.sh"

CHECK_ONLY=0
RENDERER="-dx12"
GAME_DIR="${INITIALPROJECT_GAME_DIR:-}"
GAME_EXE="${INITIALPROJECT_GAME_EXE:-InitialProject.exe}"
APP_NAME="Initial Project"
APP_SLUG="initialproject"
PREFIX_PATH="$HOME/Games/initialproject-prefix"
LAUNCHER_PATH="$HOME/Games/launch-initialproject.sh"

usage() {
	cat <<'EOF'
Usage: ./setup-and-run.sh [options]

Options:
  --check-only        Check dependencies only, do not install or run
  --dx11              Use DirectX 11 launch argument
  --dx12              Use DirectX 12 launch argument (default)
  --game-dir PATH     Directory containing InitialProject.exe
  --game-exe NAME     Game executable name (default: InitialProject.exe)
  --prefix PATH       Custom Wine prefix path
  --launcher PATH     Custom launcher script path
  -h, --help          Show this help

Environment:
  INITIALPROJECT_GAME_DIR   Default game directory
  INITIALPROJECT_GAME_EXE   Default game executable name
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--check-only) CHECK_ONLY=1 ;;
	--dx11) RENDERER="-dx11" ;;
	--dx12) RENDERER="-dx12" ;;
	--game-dir)
		shift
		[[ "${1:-}" ]] || die "Missing value for --game-dir"
		GAME_DIR="$1"
		;;
	--game-exe)
		shift
		[[ "${1:-}" ]] || die "Missing value for --game-exe"
		GAME_EXE="$1"
		;;
	--prefix)
		shift
		[[ "${1:-}" ]] || die "Missing value for --prefix"
		PREFIX_PATH="$1"
		;;
	--launcher)
		shift
		[[ "${1:-}" ]] || die "Missing value for --launcher"
		LAUNCHER_PATH="$1"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "Unknown argument: $1" ;;
	esac
	shift
done

validate_game_exe "$GAME_EXE"
require_linux_host
warn_if_unsupported_arch
prefer_system_path

if [[ "$CHECK_ONLY" != "1" ]]; then
	ROOT_DIR="$(resolve_game_dir "$GAME_DIR" "$GAME_EXE" "$SCRIPT_DIR" "$SCRIPT_DIR/Windows" "$SCRIPT_DIR/../Windows")"
	GAME_PATH="$ROOT_DIR/$GAME_EXE"
	require_file "$GAME_PATH"
fi

PM="$(detect_package_manager)"
if [[ "$PM" == "unknown" ]]; then
	warn "No supported package manager found; installed commands will be checked directly"
else
	log "Detected package manager: $PM"
fi
install_missing_packages "$PM" "$CHECK_ONLY"

if [[ "$CHECK_ONLY" == "1" ]]; then
	log "Dependency check complete"
	exit 0
fi

warn_if_vulkan_unavailable

WINE_CMD="$(runtime_command_path wine || true)"
WINEBOOT_CMD="$(runtime_command_path wineboot || true)"
WINETRICKS_CMD="$(runtime_command_path winetricks || true)"
[[ -n "$WINE_CMD" ]] || die "wine command not found after dependency installation"
[[ -n "$WINEBOOT_CMD" ]] || die "wineboot command not found after dependency installation"
[[ -n "$WINETRICKS_CMD" ]] || die "winetricks command not found after dependency installation"

ensure_wine_prefix "$PREFIX_PATH" "$WINEBOOT_CMD"
install_winetricks_basics "$PREFIX_PATH" "$WINETRICKS_CMD"

write_launcher_script "$LAUNCHER_PATH" "$ROOT_DIR" "$GAME_EXE" "$PREFIX_PATH" "$RENDERER" "$WINE_CMD"
chmod +x "$LAUNCHER_PATH"

install_shortcuts "$LAUNCHER_PATH" "$ROOT_DIR" "$APP_NAME" "$APP_SLUG"

log "Launching game with $RENDERER"
exec "$LAUNCHER_PATH"
