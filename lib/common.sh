#!/usr/bin/env bash

set -euo pipefail

has_command() {
	command -v "$1" >/dev/null 2>&1
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
		(cd "$candidate" && pwd)
		return
	fi
	die "Path does not exist: $candidate"
}

require_file() {
	local path="$1"
	[[ -f "$path" ]] || die "Required file not found: $path"
}

detect_package_manager() {
	if has_command pacman; then
		printf 'pacman\n'
	elif has_command apt-get; then
		printf 'apt\n'
	elif has_command dnf; then
		printf 'dnf\n'
	elif has_command zypper; then
		printf 'zypper\n'
	else
		printf 'unknown\n'
	fi
}

sudo_prefix() {
	if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
		printf ''
	elif has_command sudo; then
		printf 'sudo'
	else
		die "Need root privileges but sudo is not installed"
	fi
}
