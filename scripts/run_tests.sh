#!/usr/bin/env bash
#
# Runs the Blob Duels headless contract suite.
#
#   scripts/run_tests.sh                 # every assertive test
#   scripts/run_tests.sh pause_menu      # only tests whose name matches "pause_menu"
#   scripts/run_tests.sh --fail-fast     # stop at the first failure
#   scripts/run_tests.sh --list          # show what would run
#
# Each test in tests/ is a SceneTree script that calls quit(0) on success and
# quit(1) on failure, so the exit code is the whole contract. Set GODOT to point
# at a specific binary; otherwise the usual install locations are searched.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-180}"

# Diagnostic scripts, not contracts: the capture scripts write PNGs and need a
# real rendering device, and the movement probe only prints telemetry.
EXCLUDED_SUFFIX="visual_capture"
EXCLUDED_NAMES=("debug_movement_probe")

fail_fast=0
list_only=0
filter=""

for arg in "$@"; do
	case "$arg" in
		--fail-fast) fail_fast=1 ;;
		--list) list_only=1 ;;
		-h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "unknown option: $arg" >&2; exit 2 ;;
		*) filter="$arg" ;;
	esac
done

find_godot() {
	if [[ -n "${GODOT:-}" ]]; then
		echo "$GODOT"
		return
	fi
	local candidate
	for candidate in godot godot4 Godot; do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return
		fi
	done
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
		if [[ -x "$candidate" ]]; then
			echo "$candidate"
			return
		fi
	done
}

is_excluded() {
	local name="$1" excluded
	[[ "$name" == *"$EXCLUDED_SUFFIX" ]] && return 0
	for excluded in "${EXCLUDED_NAMES[@]}"; do
		[[ "$name" == "$excluded" ]] && return 0
	done
	return 1
}

tests=()
for path in "$ROOT"/tests/*.gd; do
	name="$(basename "$path" .gd)"
	is_excluded "$name" && continue
	[[ -n "$filter" && "$name" != *"$filter"* ]] && continue
	tests+=("$name")
done

if [[ ${#tests[@]} -eq 0 ]]; then
	echo "No tests matched${filter:+ \"$filter\"}." >&2
	exit 2
fi

if [[ $list_only -eq 1 ]]; then
	printf '%s\n' "${tests[@]}"
	exit 0
fi

GODOT_BIN="$(find_godot)"
if [[ -z "$GODOT_BIN" ]]; then
	cat >&2 <<-'EOF'
	Could not find a Godot binary.

	Install Godot 4.7, then either put it on PATH or point GODOT at it:
	    GODOT=/Applications/Godot.app/Contents/MacOS/Godot scripts/run_tests.sh
	EOF
	exit 127
fi

# A fresh checkout has no .godot/, so resources are unimported and every
# preload() in the suite would fail. Importing once up front is cheap when the
# cache already exists.
if [[ ! -d "$ROOT/.godot/imported" ]]; then
	echo "Importing project resources (first run)..."
	"$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
fi

# macOS has no coreutils timeout, so supervise the run directly.
run_with_timeout() {
	local log="$1" name="$2"
	"$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/$name.gd" >"$log" 2>&1 &
	local pid=$!
	local waited=0
	while kill -0 "$pid" 2>/dev/null; do
		if [[ $waited -ge $TIMEOUT_SECONDS ]]; then
			kill -9 "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
			echo "TIMED OUT after ${TIMEOUT_SECONDS}s" >>"$log"
			return 124
		fi
		sleep 1
		waited=$((waited + 1))
	done
	wait "$pid"
}

passed=0
failed=0
failed_names=()
log_dir="$(mktemp -d)"
trap 'rm -rf "$log_dir"' EXIT

echo "Running ${#tests[@]} contracts with $GODOT_BIN"
echo

for name in "${tests[@]}"; do
	log="$log_dir/$name.log"
	run_with_timeout "$log" "$name"
	status=$?

	# Godot can exit 0 after a runtime script error, so treat those as failures
	# rather than trusting the exit code alone.
	if [[ $status -eq 0 ]] && grep -q "SCRIPT ERROR\|Parse Error" "$log"; then
		status=1
	fi

	if [[ $status -eq 0 ]]; then
		passed=$((passed + 1))
		printf '  \033[32mPASS\033[0m  %s\n' "$name"
	else
		failed=$((failed + 1))
		failed_names+=("$name")
		printf '  \033[31mFAIL\033[0m  %s (exit %d)\n' "$name" "$status"
		sed 's/^/        /' "$log"
		[[ $fail_fast -eq 1 ]] && break
	fi
done

echo
echo "$passed passed, $failed failed"
if [[ $failed -gt 0 ]]; then
	printf 'Failed: %s\n' "${failed_names[*]}"
	exit 1
fi
