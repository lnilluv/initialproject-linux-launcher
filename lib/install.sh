#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

package_installed() {
	local pm="$1"
	local pkg="$2"
	case "$pm" in
	pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
	apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
	dnf | zypper) rpm -q "$pkg" >/dev/null 2>&1 ;;
	*) return 1 ;;
	esac
}

dependencies_for_pm() {
	local pm="$1"
	case "$pm" in
	pacman) printf 'wine winetricks vulkan-tools desktop-file-utils\n' ;;
	apt) printf 'wine64 winetricks vulkan-tools desktop-file-utils\n' ;;
	dnf) printf 'wine winetricks vulkan-tools desktop-file-utils\n' ;;
	zypper) printf 'wine winetricks vulkan-tools desktop-file-utils\n' ;;
	*) printf '\n' ;;
	esac
}

print_manual_instructions() {
	local pm="$1"
	local packages="$2"
	warn "Could not auto-install dependencies. Install these manually: $packages"
	case "$pm" in
	pacman) warn "Command: sudo pacman -S --needed $packages" ;;
	apt) warn "Command: sudo apt-get update && sudo apt-get install -y $packages" ;;
	dnf) warn "Command: sudo dnf install -y $packages" ;;
	zypper) warn "Command: sudo zypper install -y $packages" ;;
	*) warn "Unsupported package manager. Install Wine, winetricks, vulkan-tools, desktop-file-utils manually." ;;
	esac
}

install_missing_packages() {
	local pm="$1"
	local check_only="$2"
	local packages missing sudo_cmd
	packages="$(dependencies_for_pm "$pm")"
	[[ -n "$packages" ]] || die "Unsupported package manager. Aborting auto-install."

	missing=()
	for pkg in $packages; do
		if ! package_installed "$pm" "$pkg"; then
			missing+=("$pkg")
		fi
	done

	if [[ "${#missing[@]}" -eq 0 ]]; then
		log "All dependencies are already installed"
		return
	fi

	warn "Missing packages: ${missing[*]}"
	if [[ "$check_only" == "1" ]]; then
		print_manual_instructions "$pm" "${missing[*]}"
		return
	fi

	sudo_cmd="$(sudo_prefix)"
	case "$pm" in
	pacman)
		$sudo_cmd pacman -S --needed --noconfirm "${missing[@]}" || {
			print_manual_instructions "$pm" "${missing[*]}"
			die "Package installation failed"
		}
		;;
	apt)
		$sudo_cmd apt-get update
		$sudo_cmd apt-get install -y "${missing[@]}" || {
			print_manual_instructions "$pm" "${missing[*]}"
			die "Package installation failed"
		}
		;;
	dnf)
		$sudo_cmd dnf install -y "${missing[@]}" || {
			print_manual_instructions "$pm" "${missing[*]}"
			die "Package installation failed"
		}
		;;
	zypper)
		$sudo_cmd zypper install -y "${missing[@]}" || {
			print_manual_instructions "$pm" "${missing[*]}"
			die "Package installation failed"
		}
		;;
	*) die "Unsupported package manager: $pm" ;;
	esac
}
