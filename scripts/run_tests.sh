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
# Anything ending in _probe prints telemetry rather than asserting.
EXCLUDED_SUFFIX_ALT="_probe"
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
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Desktop/Godot.app/Contents/MacOS/Godot"; do
		if [[ -x "$candidate" ]]; then
			echo "$candidate"
			return
		fi
	done
	# Last resort: ask Spotlight. Costs a second but beats telling someone their
	# engine is missing when it is sitting in an unusual folder.
	if command -v mdfind >/dev/null 2>&1; then
		local found
		found="$(mdfind -name 'Godot.app' 2>/dev/null | head -1)"
		if [[ -n "$found" && -x "$found/Contents/MacOS/Godot" ]]; then
			echo "$found/Contents/MacOS/Godot"
			return
		fi
	fi
}

is_excluded() {
	local name="$1" excluded
	[[ "$name" == *"$EXCLUDED_SUFFIX" ]] && return 0
	[[ "$name" == *"$EXCLUDED_SUFFIX_ALT" ]] && return 0
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

# Cheap static gate: a test that seeds a renamed private field still passes
# while protecting nothing, and Godot cannot tell us that.
if command -v python3 >/dev/null 2>&1; then
	if ! python3 "$ROOT/scripts/check_test_introspection.py"; then
		exit 1
	fi
else
	echo "note: python3 not found, skipping the test-introspection check" >&2
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
# preload() in the suite would fail. The global class cache also goes stale
# when a script gains a `class_name` after the editor last scanned, and a
# headless run never rescans on its own: every reference to the new class is
# then a parse error. Re-import whenever a script is newer than that cache.
CLASS_CACHE="$ROOT/.godot/global_script_class_cache.cfg"
if [[ ! -d "$ROOT/.godot/imported" ]]; then
	echo "Importing project resources (first run)..."
	"$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
elif [[ ! -f "$CLASS_CACHE" ]] || [[ -n "$(find "$ROOT/scripts" "$ROOT/tests" -name '*.gd' -newer "$CLASS_CACHE" -print -quit)" ]]; then
	echo "Refreshing the script class cache..."
	"$GODOT_BIN" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
fi

# macOS has no coreutils timeout, so supervise the run directly.
# Two-process harnesses (names ending _network_harness) need a client beside
# the host: the script reads --role, and a lone host only ever times out.
NETWORK_CLIENT_DELAY_SECONDS=3

run_with_timeout() {
	local log="$1" name="$2"
	local client_pid=""
	if [[ "$name" == *_network_harness ]]; then
		"$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/$name.gd" -- --role=host >"$log" 2>&1 &
		local pid=$!
		sleep "$NETWORK_CLIENT_DELAY_SECONDS"
		"$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/$name.gd" -- --role=client >"$log.client" 2>&1 &
		client_pid=$!
	else
		"$GODOT_BIN" --headless --path "$ROOT" --script "res://tests/$name.gd" >"$log" 2>&1 &
		local pid=$!
	fi
	supervise "$log" "$pid"
	local status=$?
	if [[ -n "$client_pid" ]]; then
		supervise "$log.client" "$client_pid"
		local client_status=$?
		{ echo "--- client ---"; cat "$log.client"; } >>"$log"
		[[ $status -eq 0 ]] && status=$client_status
	fi
	return $status
}

supervise() {
	local log="$1" pid="$2"
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
