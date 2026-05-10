#!/usr/bin/env bash

set -euo pipefail

has_command() {
	type -P -- "$1" >/dev/null 2>&1
}

command_path() {
	type -P -- "$1"
}

custom_runtime_paths_allowed() {
	case "${INITIALPROJECT_ALLOW_CUSTOM_RUNTIME_PATH:-0}" in
	1 | true | yes | on) return 0 ;;
	*) return 1 ;;
	esac
}

runtime_command_path() {
	local cmd="$1"
	local path

	path="$(system_command "$cmd" || true)"
	if [[ -n "$path" ]]; then
		printf '%s\n' "$path"
		return
	fi

	if custom_runtime_paths_allowed; then
		path="$(command_path "$cmd" || true)"
		if [[ -n "$path" ]]; then
			printf '%s\n' "$path"
			return
		fi
	fi

	return 1
}

has_runtime_command() {
	runtime_command_path "$1" >/dev/null 2>&1
}

system_command() {
	local cmd="$1"
	local dir

	[[ -n "$cmd" && "$cmd" != */* ]] || return 1
	for dir in /usr/bin /bin /usr/sbin /sbin; do
		if [[ -x "$dir/$cmd" ]]; then
			printf '%s\n' "$dir/$cmd"
			return
		fi
	done

	return 1
}

log() {
	printf '[INFO] %s\n' "$*"
}

warn() {
	printf '[WARN] %s\n' "$*" >&2
}

die() {
	printf '[ERROR] %s\n' "$*" >&2
	exit 1
}

resolve_root_dir() {
	local candidate="$1"
	if [[ -d "$candidate" ]]; then
		(cd -- "$candidate" && pwd)
		return
	fi
	die "Path does not exist: $candidate"
}

require_file() {
	local path="$1"
	[[ -f "$path" ]] || die "Required file not found: $path"
}

prefer_system_path() {
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"
	export PATH
}

host_os() {
	uname -s 2>/dev/null || printf 'unknown\n'
}

host_arch() {
	uname -m 2>/dev/null || printf 'unknown\n'
}

require_linux_host() {
	local os
	os="$(host_os)"
	[[ "$os" == "Linux" ]] || die "This launcher must be run on Linux; detected $os"
}

warn_if_unsupported_arch() {
	local arch
	arch="$(host_arch)"
	case "$arch" in
	x86_64 | amd64) ;;
	*) warn "This Windows game is expected to work best on x86_64 Linux; detected $arch" ;;
	esac
}

warn_if_vulkan_unavailable() {
	local vulkaninfo_cmd
	vulkaninfo_cmd="$(runtime_command_path vulkaninfo || true)"
	if [[ -z "$vulkaninfo_cmd" ]]; then
		warn "Cannot verify Vulkan because vulkaninfo is not installed. DXVK/VKD3D still require working Vulkan drivers."
		return
	fi

	if ! "$vulkaninfo_cmd" >/dev/null 2>&1; then
		warn "Vulkan check failed. DXVK/VKD3D need working Vulkan drivers; install or update your GPU driver (NVIDIA proprietary driver or Mesa Vulkan drivers)."
	fi
}

shell_quote() {
	printf '%q' "$1"
}

desktop_field_value() {
	local value="$1"
	value="${value//$'\r'/ }"
	value="${value//$'\n'/ }"
	printf '%s' "$value"
}

desktop_exec_quote() {
	local value
	value="$(desktop_field_value "$1")"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//\$/\\$}"
	value="${value//\`/\\\`}"
	value="${value//%/%%}"
	printf '"%s"' "$value"
}

validate_game_exe() {
	local game_exe="$1"

	case "$game_exe" in
	"" | -* | . | .. | */* | *\\* | *$'\n'* | *$'\r'*)
		die "Game executable must be a file name only, such as InitialProject.exe"
		;;
	esac
}

resolve_game_dir() {
	local requested_dir="$1"
	local game_exe="$2"
	shift 2
	local candidate resolved

	validate_game_exe "$game_exe"

	if [[ -n "$requested_dir" ]]; then
		resolved="$(resolve_root_dir "$requested_dir")"
		require_file "$resolved/$game_exe"
		printf '%s\n' "$resolved"
		return
	fi

	for candidate in "$@"; do
		[[ -n "$candidate" && -d "$candidate" ]] || continue
		if [[ -f "$candidate/$game_exe" ]]; then
			resolve_root_dir "$candidate"
			return
		fi
	done

	die "Could not find $game_exe. This launcher repo does not include game binaries; pass --game-dir /path/to/Windows or set INITIALPROJECT_GAME_DIR."
}

detect_package_manager() {
	if system_command pacman >/dev/null; then
		printf 'pacman\n'
	elif system_command apt-get >/dev/null; then
		printf 'apt\n'
	elif system_command dnf >/dev/null; then
		printf 'dnf\n'
	elif system_command zypper >/dev/null; then
		printf 'zypper\n'
	else
		printf 'unknown\n'
	fi
}

package_manager_command() {
	case "$1" in
	pacman) system_command pacman ;;
	apt) system_command apt-get ;;
	dnf) system_command dnf ;;
	zypper) system_command zypper ;;
	*) return 1 ;;
	esac
}

run_as_root() {
	local sudo_cmd

	if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
		"$@"
		return
	fi

	sudo_cmd="$(system_command sudo || true)"
	if [[ -z "$sudo_cmd" ]]; then
		warn "Need root privileges but sudo is not installed"
		return 1
	fi

	"$sudo_cmd" "$@"
}
