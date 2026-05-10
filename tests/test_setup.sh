#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/common.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/wine.sh"
# shellcheck source=/dev/null
source "$ROOT_DIR/lib/install.sh"

assert_eq() {
	local expected="$1"
	local actual="$2"
	local message="$3"
	if [[ "$expected" != "$actual" ]]; then
		printf 'FAIL: %s\nExpected: %s\nActual: %s\n' "$message" "$expected" "$actual"
		exit 1
	fi
}

assert_nonempty() {
	local value="$1"
	local message="$2"
	if [[ -z "$value" ]]; then
		printf 'FAIL: %s\n' "$message"
		exit 1
	fi
}

assert_contains() {
	local needle="$1"
	local haystack="$2"
	local message="$3"
	if [[ "$haystack" != *"$needle"* ]]; then
		printf 'FAIL: %s\nExpected to find: %s\n' "$message" "$needle"
		exit 1
	fi
}

assert_file_exists() {
	local path="$1"
	local message="$2"
	if [[ ! -f "$path" ]]; then
		printf 'FAIL: %s\nMissing file: %s\n' "$message" "$path"
		exit 1
	fi
}

test_detect_package_manager() {
	local pm
	pm="$(detect_package_manager)"
	assert_nonempty "$pm" "detect_package_manager should return a value"
}

test_has_command() {
	if has_command definitely_not_a_real_binary_123; then
		printf 'FAIL: has_command should return false for fake command\n'
		exit 1
	fi
}

test_system_command_ignores_path_entries() {
	local tmp
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/pacman"
	chmod +x "$tmp/pacman"

	if PATH="$tmp:$PATH" system_command pacman >/dev/null && [[ ! -x /usr/bin/pacman && ! -x /bin/pacman && ! -x /usr/sbin/pacman && ! -x /sbin/pacman ]]; then
		printf 'FAIL: system_command should ignore fake package managers in PATH\n'
		exit 1
	fi
	rm -rf "$tmp"
}

test_runtime_command_path_rejects_custom_path_by_default() {
	local tmp
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/definitely_fake_wine"
	chmod +x "$tmp/definitely_fake_wine"

	if PATH="$tmp:$PATH" runtime_command_path definitely_fake_wine >/dev/null; then
		printf 'FAIL: runtime_command_path should reject custom PATH commands by default\n'
		exit 1
	fi
	rm -rf "$tmp"
}

test_runtime_command_path_allows_custom_path_when_enabled() {
	local tmp resolved
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/custom-wine"
	chmod +x "$tmp/custom-wine"

	resolved="$(PATH="$tmp:$PATH" INITIALPROJECT_ALLOW_CUSTOM_RUNTIME_PATH=1 runtime_command_path custom-wine)"

	assert_eq "$tmp/custom-wine" "$resolved" "runtime_command_path should allow custom PATH commands when explicitly enabled"
	rm -rf "$tmp"
}

test_resolve_root_dir() {
	local resolved
	resolved="$(resolve_root_dir "$ROOT_DIR")"
	assert_eq "$ROOT_DIR" "$resolved" "resolve_root_dir should return provided path"
}

test_resolve_root_dir_handles_dash_prefixed_paths() {
	local tmp resolved
	tmp="$(mktemp -d)"
	mkdir -- "$tmp/-P"

	resolved="$(resolve_root_dir "$tmp/-P")"

	assert_eq "$tmp/-P" "$resolved" "resolve_root_dir should handle dash-prefixed paths"
	rm -rf "$tmp"
}

test_write_launcher_script_quotes_paths_with_spaces() {
	local tmp launcher game_dir prefix contents quoted_game_dir quoted_game_exe quoted_prefix
	tmp="$(mktemp -d)"
	launcher="$tmp/launch script.sh"
	game_dir="$tmp/Game Dir"
	prefix="$tmp/Wine Prefix"
	mkdir -p "$game_dir" "$prefix"

	write_launcher_script "$launcher" "$game_dir" "Initial Project.exe" "$prefix" "-dx12"
	contents="$(<"$launcher")"
	quoted_game_dir="$(shell_quote "$game_dir")"
	quoted_game_exe="$(shell_quote "Initial Project.exe")"
	quoted_prefix="$(shell_quote "$prefix")"

	assert_contains "export WINEPREFIX=$quoted_prefix" "$contents" "launcher should quote WINEPREFIX"
	assert_contains "cd $quoted_game_dir" "$contents" "launcher should quote game directory"
	assert_contains "exec wine $quoted_game_exe -dx12" "$contents" "launcher should quote executable name"
	rm -rf "$tmp"
}

test_write_launcher_script_embeds_resolved_wine_path() {
	local tmp launcher contents quoted_wine
	tmp="$(mktemp -d)"
	launcher="$tmp/launch.sh"
	quoted_wine="$(shell_quote "$tmp/custom wine/bin/wine")"

	write_launcher_script "$launcher" "$tmp" "InitialProject.exe" "$tmp/prefix" "-dx12" "$tmp/custom wine/bin/wine"
	contents="$(<"$launcher")"

	assert_contains "exec $quoted_wine InitialProject.exe -dx12" "$contents" "launcher should embed resolved Wine path"
	rm -rf "$tmp"
}

test_write_launcher_script_supports_nvidia_prime_offload() {
	local tmp launcher contents
	tmp="$(mktemp -d)"
	launcher="$tmp/launch.sh"

	write_launcher_script "$launcher" "$tmp" "InitialProject.exe" "$tmp/prefix" "-dx12"
	contents="$(<"$launcher")"

	assert_contains "INITIALPROJECT_NVIDIA_OFFLOAD" "$contents" "launcher should expose NVIDIA offload toggle"
	assert_contains "__NV_PRIME_RENDER_OFFLOAD=1" "$contents" "launcher should set NVIDIA PRIME offload"
	assert_contains "__GLX_VENDOR_LIBRARY_NAME=nvidia" "$contents" "launcher should set NVIDIA GLX vendor"
	assert_contains "__VK_LAYER_NV_optimus=NVIDIA_only" "$contents" "launcher should prefer NVIDIA Vulkan layer"
	rm -rf "$tmp"
}

test_warn_if_vulkan_unavailable_warns_when_vulkaninfo_fails() {
	local tmp output
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/vulkaninfo"
	chmod +x "$tmp/vulkaninfo"

	output="$( (runtime_command_path() { printf '%s\n' "$tmp/vulkaninfo"; }; warn_if_vulkan_unavailable) 2>&1)"

	assert_contains "Vulkan check failed" "$output" "Vulkan check should warn when vulkaninfo fails"
	assert_contains "NVIDIA proprietary driver" "$output" "Vulkan warning should mention NVIDIA driver"
	rm -rf "$tmp"
}

test_warn_if_vulkan_unavailable_warns_when_vulkaninfo_missing() {
	local output

	output="$( (runtime_command_path() { return 1; }; warn_if_vulkan_unavailable) 2>&1)"

	assert_contains "Cannot verify Vulkan" "$output" "Vulkan check should warn when vulkaninfo is missing"
}

test_resolve_game_dir_uses_explicit_directory() {
	local tmp game_dir resolved
	tmp="$(mktemp -d)"
	game_dir="$tmp/Game Build"
	mkdir -p "$game_dir"
	: >"$game_dir/InitialProject.exe"

	resolved="$(resolve_game_dir "$game_dir" "InitialProject.exe" "$tmp/missing")"

	assert_eq "$game_dir" "$resolved" "resolve_game_dir should prefer explicit game directory"
	rm -rf "$tmp"
}

test_resolve_game_dir_rejects_exe_paths() {
	local tmp game_dir output status
	tmp="$(mktemp -d)"
	game_dir="$tmp/Game Build"
	mkdir -p "$game_dir"

	set +e
	output="$(resolve_game_dir "$game_dir" "../InitialProject.exe" 2>&1)"
	status="$?"
	set -e

	if [[ "$status" -eq 0 ]]; then
		printf 'FAIL: resolve_game_dir should reject game exe path components\n'
		exit 1
	fi
	assert_contains "file name only" "$output" "resolve_game_dir should explain invalid executable name"
	rm -rf "$tmp"
}

test_install_missing_packages_allows_unknown_pm_when_commands_exist() {
	local tmp cmd
	tmp="$(mktemp -d)"
	for cmd in wine wineboot winetricks vulkaninfo update-desktop-database; do
		printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/$cmd"
		chmod +x "$tmp/$cmd"
	done

	(
		has_runtime_command() { [[ -x "$tmp/$1" ]]; }
		install_missing_packages unknown 1 >/dev/null 2>&1
	)

	rm -rf "$tmp"
}

test_install_missing_packages_continues_when_only_recommended_install_fails() {
	local tmp cmd
	tmp="$(mktemp -d)"
	for cmd in wine wineboot winetricks; do
		printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/$cmd"
		chmod +x "$tmp/$cmd"
	done

	(
		has_runtime_command() { [[ -x "$tmp/$1" ]]; }
		package_manager_command() { printf '%s\n' /nonexistent/fake-pacman; }
		run_as_root() { return 1; }
		install_missing_packages pacman 0 >/dev/null 2>&1
	)

	rm -rf "$tmp"
}

test_install_missing_packages_continues_when_only_recommended_missing_without_sudo() {
	local tmp cmd
	tmp="$(mktemp -d)"
	for cmd in wine wineboot winetricks; do
		printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/$cmd"
		chmod +x "$tmp/$cmd"
	done

	(
		has_runtime_command() { [[ -x "$tmp/$1" ]]; }
		package_manager_command() { printf '%s\n' /nonexistent/fake-pacman; }
		run_as_root() { return 1; }
		install_missing_packages pacman 0 >/dev/null 2>&1
	)

	rm -rf "$tmp"
}

test_install_missing_packages_installs_required_before_recommended() {
	local tmp bin fake_pm
	tmp="$(mktemp -d)"
	bin="$tmp/bin"
	mkdir -p "$bin"
	fake_pm="$tmp/pacman"
	cat >"$fake_pm" <<'EOF_FAKE_PM'
#!/usr/bin/env bash
for arg in "$@"; do
	if [[ "$arg" == "vulkan-tools" || "$arg" == "desktop-file-utils" ]]; then
		exit 1
	fi
done
for cmd in wine wineboot winetricks; do
	printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_BIN/$cmd"
	chmod +x "$TEST_BIN/$cmd"
done
exit 0
EOF_FAKE_PM
	chmod +x "$fake_pm"

	(
		has_runtime_command() { [[ -x "$bin/$1" ]]; }
		package_manager_command() { printf '%s\n' "$fake_pm"; }
		run_as_root() { "$@"; }
		TEST_BIN="$bin" install_missing_packages pacman 0 >/dev/null 2>&1
	)

	assert_file_exists "$bin/wine" "required wine command should be installed before recommended packages"
	assert_file_exists "$bin/winetricks" "required winetricks command should be installed before recommended packages"
	rm -rf "$tmp"
}

test_require_linux_host_accepts_linux() {
	local tmp
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nprintf "Linux\\n"\n' >"$tmp/uname"
	chmod +x "$tmp/uname"

	(PATH="$tmp:$PATH" require_linux_host)

	rm -rf "$tmp"
}

test_create_desktop_entry_quotes_exec_path_with_spaces() {
	local tmp desktop_file contents
	tmp="$(mktemp -d)"
	desktop_file="$tmp/Initial Project.desktop"

	create_desktop_entry "$desktop_file" "$tmp/Launch Script.sh" "$tmp/Game Dir" "Initial Project"
	contents="$(<"$desktop_file")"

	assert_contains "Exec=\"$tmp/Launch Script.sh\"" "$contents" "desktop Exec should quote launcher path"
	assert_contains "Path=$tmp/Game Dir" "$contents" "desktop Path should preserve spaces"
	rm -rf "$tmp"
}

test_desktop_exec_quote_escapes_percent_signs() {
	local quoted
	quoted="$(desktop_exec_quote "/tmp/Launch % Script.sh")"
	assert_eq '"/tmp/Launch %% Script.sh"' "$quoted" "desktop Exec should escape percent signs"
}

test_create_desktop_entry_sanitizes_path_newlines() {
	local tmp desktop_file contents unsafe_path
	tmp="$(mktemp -d)"
	desktop_file="$tmp/Initial Project.desktop"
	unsafe_path=$'/tmp/Game\nInjected=true'

	create_desktop_entry "$desktop_file" "$tmp/Launch.sh" "$unsafe_path" "Initial Project"
	contents="$(<"$desktop_file")"

	assert_contains "Path=/tmp/Game Injected=true" "$contents" "desktop Path should replace newlines with spaces"
	if [[ "$contents" == *$'Path=/tmp/Game\nInjected=true'* ]]; then
		printf 'FAIL: desktop Path should not contain raw newlines from input\n'
		exit 1
	fi
	rm -rf "$tmp"
}

test_setup_validates_game_dir_before_installing_dependencies() {
	local tmp output status
	tmp="$(mktemp -d)"
	printf '#!/usr/bin/env bash\nprintf "Linux\\n"\n' >"$tmp/uname"
	printf '#!/usr/bin/env bash\ntouch "$TEST_MARKER"\nexit 1\n' >"$tmp/pacman"
	chmod +x "$tmp/uname" "$tmp/pacman"

	set +e
	output="$(PATH="$tmp:$PATH" HOME="$tmp/home" TEST_MARKER="$tmp/package-manager-called" "$ROOT_DIR/setup-and-run.sh" --game-dir "$tmp/missing" 2>&1)"
	status="$?"
	set -e

	if [[ "$status" -eq 0 ]]; then
		printf 'FAIL: setup should fail when game directory is missing\n'
		exit 1
	fi
	assert_contains "Path does not exist: $tmp/missing" "$output" "setup should report missing game directory first"
	if [[ -e "$tmp/package-manager-called" ]]; then
		printf 'FAIL: setup should not call package manager before validating game directory\n'
		exit 1
	fi
	rm -rf "$tmp"
}

test_install_shortcuts_uses_xdg_data_home() {
	local tmp home data game_dir
	tmp="$(mktemp -d)"
	home="$tmp/home"
	data="$tmp/xdg-data"
	game_dir="$tmp/Game Dir"
	mkdir -p "$home" "$data" "$game_dir"

	(HOME="$home" XDG_DATA_HOME="$data" install_shortcuts "$tmp/Launch Script.sh" "$game_dir" "Initial Project" "initialproject")

	assert_file_exists "$data/applications/initialproject.desktop" "install_shortcuts should use XDG_DATA_HOME"
	rm -rf "$tmp"
}

test_detect_package_manager
test_has_command
test_system_command_ignores_path_entries
test_runtime_command_path_rejects_custom_path_by_default
test_runtime_command_path_allows_custom_path_when_enabled
test_resolve_root_dir
test_resolve_root_dir_handles_dash_prefixed_paths
test_write_launcher_script_quotes_paths_with_spaces
test_write_launcher_script_embeds_resolved_wine_path
test_write_launcher_script_supports_nvidia_prime_offload
test_warn_if_vulkan_unavailable_warns_when_vulkaninfo_fails
test_warn_if_vulkan_unavailable_warns_when_vulkaninfo_missing
test_resolve_game_dir_uses_explicit_directory
test_resolve_game_dir_rejects_exe_paths
test_install_missing_packages_allows_unknown_pm_when_commands_exist
test_install_missing_packages_continues_when_only_recommended_install_fails
test_install_missing_packages_continues_when_only_recommended_missing_without_sudo
test_install_missing_packages_installs_required_before_recommended
test_require_linux_host_accepts_linux
test_create_desktop_entry_quotes_exec_path_with_spaces
test_desktop_exec_quote_escapes_percent_signs
test_create_desktop_entry_sanitizes_path_newlines
test_setup_validates_game_dir_before_installing_dependencies
test_install_shortcuts_uses_xdg_data_home

printf 'All tests passed\n'
