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
GAME_EXE="InitialProject.exe"
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
  --prefix PATH       Custom Wine prefix path
  --launcher PATH     Custom launcher script path
  -h, --help          Show this help
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--check-only) CHECK_ONLY=1 ;;
	--dx11) RENDERER="-dx11" ;;
	--dx12) RENDERER="-dx12" ;;
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

ROOT_DIR="$(resolve_root_dir "$SCRIPT_DIR")"
GAME_PATH="$ROOT_DIR/$GAME_EXE"
require_file "$GAME_PATH"

PM="$(detect_package_manager)"
if [[ "$PM" == "unknown" ]]; then
	die "No supported package manager found (pacman, apt, dnf, zypper)"
fi

log "Detected package manager: $PM"
install_missing_packages "$PM" "$CHECK_ONLY"

if [[ "$CHECK_ONLY" == "1" ]]; then
	log "Check complete"
	exit 0
fi

ensure_wine_prefix "$PREFIX_PATH"
install_winetricks_basics "$PREFIX_PATH"

write_launcher_script "$LAUNCHER_PATH" "$ROOT_DIR" "$GAME_EXE" "$PREFIX_PATH" "$RENDERER"
chmod +x "$LAUNCHER_PATH"

install_shortcuts "$LAUNCHER_PATH" "$ROOT_DIR" "$APP_NAME" "$APP_SLUG"

log "Launching game with $RENDERER"
exec "$LAUNCHER_PATH"
