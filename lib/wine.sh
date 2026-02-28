#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_wine_prefix() {
	local prefix="$1"
	mkdir -p "$prefix"
	log "Initializing Wine prefix: $prefix"
	WINEPREFIX="$prefix" WINEARCH=win64 wineboot -u >/dev/null
}

install_winetricks_basics() {
	local prefix="$1"
	log "Installing winetricks components (vcrun2022, corefonts, dxvk, vkd3d)"
	WINEPREFIX="$prefix" winetricks -q vcrun2022 corefonts dxvk vkd3d
}

write_launcher_script() {
	local launcher_path="$1"
	local game_dir="$2"
	local game_exe="$3"
	local prefix="$4"
	local renderer="$5"

	mkdir -p "$(dirname "$launcher_path")"
	cat >"$launcher_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export WINEPREFIX="$prefix"
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1

if [[ -n "\${GPU_FILTER_DEVICE_NAME:-}" ]]; then
  export DXVK_FILTER_DEVICE_NAME="\${GPU_FILTER_DEVICE_NAME}"
  export VKD3D_FILTER_DEVICE_NAME="\${GPU_FILTER_DEVICE_NAME}"
fi

cd "$game_dir"
exec wine "$game_exe" "$renderer"
EOF
}

create_desktop_entry() {
	local desktop_file="$1"
	local launcher_path="$2"
	local game_dir="$3"
	local app_name="$4"

	cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$app_name
Comment=Launch $app_name via Wine
Exec=$launcher_path
Path=$game_dir
Icon=wine
Terminal=false
Categories=Game;
StartupNotify=true
EOF
}

install_shortcuts() {
	local launcher_path="$1"
	local game_dir="$2"
	local app_name="$3"
	local app_slug="$4"
	local app_menu_file desktop_shortcut

	app_menu_file="$HOME/.local/share/applications/${app_slug}.desktop"
	mkdir -p "$HOME/.local/share/applications"
	create_desktop_entry "$app_menu_file" "$launcher_path" "$game_dir" "$app_name"

	if [[ -d "$HOME/Desktop" ]]; then
		desktop_shortcut="$HOME/Desktop/${app_name}.desktop"
		create_desktop_entry "$desktop_shortcut" "$launcher_path" "$game_dir" "$app_name"
		chmod +x "$desktop_shortcut"
	fi

	if has_command update-desktop-database; then
		update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
	fi
}
