#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

required_runtime_commands() {
	printf 'wine\nwineboot\nwinetricks\n'
}

recommended_runtime_commands() {
	printf 'vulkaninfo\nupdate-desktop-database\n'
}

one_line() {
	local value="$1"
	value="${value//$'\n'/ }"
	printf '%s' "$value"
}

missing_commands() {
	local cmd
	for cmd in "$@"; do
		if ! has_runtime_command "$cmd"; then
			printf '%s\n' "$cmd"
		fi
	done
}

append_word_unique() {
	local list="$1"
	local word="$2"
	case " $list " in
	*" $word "*) printf '%s' "$list" ;;
	*) printf '%s%s%s' "$list" "${list:+ }" "$word" ;;
	esac
}

package_for_command() {
	local pm="$1"
	local cmd="$2"

	case "$pm:$cmd" in
	pacman:wine | pacman:wineboot) printf 'wine\n' ;;
	pacman:winetricks) printf 'winetricks\n' ;;
	pacman:vulkaninfo) printf 'vulkan-tools\n' ;;
	pacman:update-desktop-database) printf 'desktop-file-utils\n' ;;
	apt:wine | apt:wineboot) printf 'wine\n' ;;
	apt:winetricks) printf 'winetricks\n' ;;
	apt:vulkaninfo) printf 'vulkan-tools\n' ;;
	apt:update-desktop-database) printf 'desktop-file-utils\n' ;;
	dnf:wine | dnf:wineboot) printf 'wine\n' ;;
	dnf:winetricks) printf 'winetricks\n' ;;
	dnf:vulkaninfo) printf 'vulkan-tools\n' ;;
	dnf:update-desktop-database) printf 'desktop-file-utils\n' ;;
	zypper:wine | zypper:wineboot) printf 'wine\n' ;;
	zypper:winetricks) printf 'winetricks\n' ;;
	zypper:vulkaninfo) printf 'vulkan-tools\n' ;;
	zypper:update-desktop-database) printf 'desktop-file-utils\n' ;;
	*) return 1 ;;
	esac
}

packages_for_commands() {
	local pm="$1"
	shift
	local packages=""
	local cmd pkg

	for cmd in "$@"; do
		pkg="$(package_for_command "$pm" "$cmd" || true)"
		if [[ -n "$pkg" ]]; then
			packages="$(append_word_unique "$packages" "$pkg")"
		fi
	done

	printf '%s\n' "$packages"
}

print_manual_instructions() {
	local pm="$1"
	local commands="$2"
	local packages="$3"
	local command_list
	command_list="$(one_line "$commands")"

	warn "Missing commands: $command_list"
	if [[ -z "$packages" ]]; then
		warn "Install Wine, winetricks, Vulkan tools/drivers, and desktop-file-utils with your distribution's package manager."
		return
	fi

	case "$pm" in
	pacman) warn "Command: sudo pacman -S --needed $packages" ;;
	apt) warn "Command: sudo apt-get update && sudo apt-get install -y $packages" ;;
	dnf) warn "Command: sudo dnf install -y $packages" ;;
	zypper) warn "Command: sudo zypper install -y $packages" ;;
	*) warn "Install these packages with your distribution's package manager: $packages" ;;
	esac
}

install_packages() {
	local pm="$1"
	shift
	local pm_cmd

	[[ "$#" -gt 0 ]] || return 0
	pm_cmd="$(package_manager_command "$pm" || true)"
	[[ -n "$pm_cmd" ]] || return 1

	case "$pm" in
	pacman)
		run_as_root "$pm_cmd" -S --needed --noconfirm "$@"
		;;
	apt)
		run_as_root "$pm_cmd" update || {
			warn "apt-get update failed"
			return 1
		}
		run_as_root "$pm_cmd" install -y "$@"
		;;
	dnf)
		run_as_root "$pm_cmd" install -y "$@"
		;;
	zypper)
		run_as_root "$pm_cmd" install -y "$@"
		;;
	*) return 1 ;;
	esac
}

try_install_recommended_packages() {
	local pm="$1"
	local missing_recommended="$2"
	local packages

	[[ -n "$missing_recommended" ]] || return 0
	packages="$(packages_for_commands "$pm" $missing_recommended)"
	if [[ "$pm" == "unknown" || -z "$packages" ]]; then
		print_manual_instructions "$pm" "$missing_recommended" "$packages"
		warn "Recommended commands are missing, but the launcher can continue."
		return 0
	fi

	install_packages "$pm" $packages || {
		print_manual_instructions "$pm" "$missing_recommended" "$packages"
		warn "Could not auto-install recommended commands; continuing."
		return 0
	}
}

install_missing_packages() {
	local pm="$1"
	local check_only="$2"
	local required recommended missing_required missing_recommended packages_required all_missing all_packages

	required="$(required_runtime_commands)"
	recommended="$(recommended_runtime_commands)"
	missing_required="$(missing_commands $required)"
	missing_recommended="$(missing_commands $recommended)"

	if [[ -z "$missing_required" && -z "$missing_recommended" ]]; then
		log "All runtime commands are already installed"
		return
	fi

	if [[ -n "$missing_required" ]]; then
		warn "Missing required runtime commands: $(one_line "$missing_required")"
	fi
	if [[ -n "$missing_recommended" ]]; then
		warn "Missing recommended commands: $(one_line "$missing_recommended")"
	fi

	packages_required="$(packages_for_commands "$pm" $missing_required)"
	all_missing="$missing_required"
	if [[ -n "$missing_recommended" ]]; then
		all_missing="${all_missing}${all_missing:+$'\n'}$missing_recommended"
	fi
	all_packages="$(packages_for_commands "$pm" $all_missing)"

	if [[ "$check_only" == "1" ]]; then
		print_manual_instructions "$pm" "$all_missing" "$all_packages"
		if [[ -n "$missing_required" ]]; then
			die "Required runtime commands are missing"
		fi
		return
	fi

	if [[ -n "$missing_required" ]]; then
		if [[ "$pm" == "unknown" || -z "$packages_required" ]]; then
			print_manual_instructions "$pm" "$missing_required" "$packages_required"
			die "Cannot auto-install required runtime commands"
		fi

		install_packages "$pm" $packages_required || {
			print_manual_instructions "$pm" "$missing_required" "$packages_required"
			die "Package installation failed"
		}

		missing_required="$(missing_commands $required)"
		if [[ -n "$missing_required" ]]; then
			print_manual_instructions "$pm" "$missing_required" "$(packages_for_commands "$pm" $missing_required)"
			die "Required runtime commands are still missing after package installation"
		fi
	fi

	missing_recommended="$(missing_commands $recommended)"
	try_install_recommended_packages "$pm" "$missing_recommended"

	missing_recommended="$(missing_commands $recommended)"
	if [[ -n "$missing_recommended" ]]; then
		warn "Recommended commands are still missing: $(one_line "$missing_recommended")"
		warn "The launcher can continue, but Vulkan diagnostics and desktop menu refresh may be limited."
	fi
}
