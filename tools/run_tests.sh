#!/usr/bin/env bash
# Runs a draft's checks. Fails (exit 1) on any FAIL, script error or parse error.
#
#   tools/run_tests.sh               # apex: smoke, input, practice and soak tests (~5 min)
#   tools/run_tests.sh apex --probes # also the tuning probes; results saved to tests/results/
#   tools/run_tests.sh apex --shots  # also render screenshots (needs xvfb-run; slow)
#
# Needs `godot` on PATH (tools/get_godot.sh installs it).
set -uo pipefail

draft="${1:-apex}"
shift || true
probes=false
shots=false
for arg in "$@"; do
	case "$arg" in
		--probes) probes=true ;;
		--shots) shots=true ;;
	esac
done

cd "$(dirname "$0")/.." || exit 1
if ! command -v godot >/dev/null; then
	echo "godot not found: run tools/get_godot.sh first"
	exit 1
fi

failed=0

# Run one Godot script; print its result lines; fail on errors or a missing PASS.
run() {
	local name="$1" script="$2" want="$3"
	shift 3
	echo "== $name"
	local out
	out="$(timeout 900 godot --headless --path "$draft" "$@" -s "$script" 2>&1)"
	echo "$out" | grep -E "^  (ok|FAIL)|PASS|FAIL|saved|-> " | grep -v "^  ok" || true
	if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		echo "$out" | grep -A4 -E "SCRIPT ERROR|Parse Error" | head -30
		failed=1
	fi
	if [ -n "$want" ] && ! echo "$out" | grep -q "$want"; then
		echo "   (no '$want' in output)"
		failed=1
	fi
}

godot --headless --path "$draft" --import >/dev/null 2>&1
run "smoke test" tests/smoke_test.gd "SMOKE TEST: PASS" --fixed-fps 60
run "input test" tests/input_test.gd "INPUT TEST: PASS"
run "practice test" tests/practice_test.gd "PRACTICE TEST: PASS" --fixed-fps 60
run "soak test" tests/soak_test.gd "SOAK TEST: PASS" --fixed-fps 60

if $probes; then
	run "hunt probe" tests/hunt_sim.gd "saved" --fixed-fps 60
	run "ride probe" tests/ride_sim.gd "saved"
	run "fight probe" tests/fight_sim.gd "saved" --fixed-fps 60
fi

if $shots; then
	echo "== screenshots"
	timeout 1800 xvfb-run -a -s "-screen 0 1600x900x24" godot --path "$draft" --fixed-fps 30 \
		-s tests/screenshot.gd 2>&1 | grep -E "saved|SCRIPT ERROR"
fi

if [ "$failed" -ne 0 ]; then
	echo "RESULT: FAIL"
	exit 1
fi
echo "RESULT: PASS"
