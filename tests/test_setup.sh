#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/lib/common.sh"

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

test_resolve_root_dir() {
	local resolved
	resolved="$(resolve_root_dir "$ROOT_DIR")"
	assert_eq "$ROOT_DIR" "$resolved" "resolve_root_dir should return provided path"
}

test_detect_package_manager
test_has_command
test_resolve_root_dir

printf 'All tests passed\n'
