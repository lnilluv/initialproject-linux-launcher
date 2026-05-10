#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_wine_prefix() {
	local prefix="$1"
	local wineboot_cmd="${2:-wineboot}"
	mkdir -p "$prefix"
	log "Initializing Wine prefix: $prefix"
	WINEPREFIX="$prefix" WINEARCH=win64 "$wineboot_cmd" -u >/dev/null
}

install_winetricks_basics() {
	local prefix="$1"
	local winetricks_cmd="${2:-winetricks}"
	log "Installing winetricks components (vcrun2022, corefonts, dxvk, vkd3d)"
	WINEPREFIX="$prefix" "$winetricks_cmd" -q vcrun2022 corefonts dxvk vkd3d
}

write_launcher_script() {
	local launcher_path="$1"
	local game_dir="$2"
	local game_exe="$3"
	local prefix="$4"
	local renderer="$5"
	local wine_cmd="${6:-wine}"
	local quoted_game_dir quoted_game_exe quoted_prefix quoted_renderer quoted_wine_cmd

	quoted_game_dir="$(shell_quote "$game_dir")"
	quoted_game_exe="$(shell_quote "$game_exe")"
	quoted_prefix="$(shell_quote "$prefix")"
	quoted_renderer="$(shell_quote "$renderer")"
	quoted_wine_cmd="$(shell_quote "$wine_cmd")"

	mkdir -p "$(dirname "$launcher_path")"
	cat >"$launcher_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export WINEPREFIX=$quoted_prefix
export WINEDEBUG=-all
export WINEESYNC=1
export WINEFSYNC=1

if [[ -n "\${GPU_FILTER_DEVICE_NAME:-}" ]]; then
  export DXVK_FILTER_DEVICE_NAME="\${GPU_FILTER_DEVICE_NAME}"
  export VKD3D_FILTER_DEVICE_NAME="\${GPU_FILTER_DEVICE_NAME}"
fi

case "\${INITIALPROJECT_NVIDIA_OFFLOAD:-0}" in
  1|true|yes|on)
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    ;;
esac

cd $quoted_game_dir
exec $quoted_wine_cmd $quoted_game_exe $quoted_renderer
EOF
}

create_desktop_entry() {
	local desktop_file="$1"
	local launcher_path="$2"
	local game_dir="$3"
	local app_name="$4"
	local exec_value path_value name_value

	exec_value="$(desktop_exec_quote "$launcher_path")"
	path_value="$(desktop_field_value "$game_dir")"
	name_value="$(desktop_field_value "$app_name")"

	cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=$name_value
Comment=Launch $name_value via Wine
Exec=$exec_value
Path=$path_value
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
	local data_home app_menu_dir app_menu_file desktop_dir desktop_shortcut xdg_user_dir_cmd update_desktop_database_cmd

	data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
	app_menu_dir="$data_home/applications"
	app_menu_file="$app_menu_dir/${app_slug}.desktop"
	mkdir -p "$app_menu_dir"
	create_desktop_entry "$app_menu_file" "$launcher_path" "$game_dir" "$app_name"

	desktop_dir=""
	xdg_user_dir_cmd="$(runtime_command_path xdg-user-dir || true)"
	if [[ -n "$xdg_user_dir_cmd" ]]; then
		desktop_dir="$($xdg_user_dir_cmd DESKTOP 2>/dev/null || true)"
	fi
	if [[ -z "$desktop_dir" || "$desktop_dir" == "$HOME" ]]; then
		desktop_dir="$HOME/Desktop"
	fi
	if [[ -d "$desktop_dir" ]]; then
		desktop_shortcut="$desktop_dir/${app_name}.desktop"
		create_desktop_entry "$desktop_shortcut" "$launcher_path" "$game_dir" "$app_name"
		chmod +x "$desktop_shortcut"
	fi

	update_desktop_database_cmd="$(runtime_command_path update-desktop-database || true)"
	if [[ -n "$update_desktop_database_cmd" ]]; then
		"$update_desktop_database_cmd" "$app_menu_dir" >/dev/null 2>&1 || true
	fi
}
