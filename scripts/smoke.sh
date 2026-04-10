#!/usr/bin/env bash
#
# smoke.sh - MVP smoke-test harness for apple-calendar-ctl
#
# Runs: build, --help, status, list, today
# - All non-destructive (no calendar writes).
# - Auto-skips authorization-required commands when calendar access
#   has not yet been granted.
#
# Exit 0 = all pass, non-zero = at least one failure.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="$PROJECT_DIR/.build/arm64-apple-macosx/debug/calctl"
TIMEOUT_SECS=8

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BOLD='\033[1m'; RESET='\033[0m'
PASS="${GREEN}PASS${RESET}"; FAIL="${RED}FAIL${RESET}"; INFO="${YELLOW}--${RESET}"; SKIP="${YELLOW}SKIP${RESET}"

passed=0; failed=0; skipped=0

log()  { echo -e "${BOLD}[smoke]${RESET} $*"; }
step() { echo -e "  ${INFO} $*"; }
ok()   { echo -e "    ${PASS} $*"; passed=$((passed+1)); }
err()  { echo -e "    ${FAIL} $*"; failed=$((failed+1)); }
skp()  { echo -e "    ${SKIP} $*  (no calendar access)"; skipped=$((skipped+1)); }

# Run a command with a timeout (works on macOS without GNU timeout)
run_with_timeout() {
    local cmd=("$@")
    local start end elapsed
    start=$(date +%s)
    "${cmd[@]}" &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        end=$(date +%s)
        elapsed=$((end - start))
        if (( elapsed >= TIMEOUT_SECS )); then
            kill -9 "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
        sleep 0.2
    done
    wait "$pid"
    return $?
}

log "calctl - MVP Smoke Test"
log "Project: $PROJECT_DIR"
echo

# ── 1. Build ──────────────────────────────────────────────────────────────────
log "1. Build"
if ! swift build --package-path "$PROJECT_DIR" > /dev/null 2>&1; then
    err "swift build failed"
    exit 1
fi
if [[ -x "$BINARY" ]]; then
    ok "binary exists: $BINARY"
else
    err "binary not found: $BINARY"
    exit 1
fi
echo

# ── 2. --help ─────────────────────────────────────────────────────────────────
log "2. --help (non-destructive)"
output=$(run_with_timeout "$BINARY" --help 2>&1) || true
if [[ -n "$output" ]]; then
    ok "responds to --help"
else
    err "--help produced no output"
fi
echo

# ── 3. status ────────────────────────────────────────────────────────────────
log "3. status (non-destructive)"
output=$(run_with_timeout "$BINARY" status 2>&1) || true
if [[ -n "$output" ]]; then
    ok "status executed"
    step "output: $output"
else
    err "status produced no output"
fi

# Detect if calendar access is granted (first word of output)
auth_status=$(echo "$output" | awk '{print $1; exit}')
[[ "$auth_status" == "authorized" ]] && auth_granted=true || auth_granted=false
echo

# ── 4. list (skip if not authorized) ─────────────────────────────────────────
log "4. list"
if [[ "$auth_granted" == "true" ]]; then
    output=$(run_with_timeout "$BINARY" list 2>&1) || true
    if [[ -n "$output" ]]; then
        ok "list executed"
        step "output: $output"
    else
        err "list produced no output"
    fi
else
    skp "list"
fi
echo

# ── 5. today (skip if not authorized) ────────────────────────────────────────
log "5. today"
if [[ "$auth_granted" == "true" ]]; then
    output=$(run_with_timeout "$BINARY" today 2>&1) || true
    if [[ -n "$output" ]]; then
        ok "today executed"
        step "output: $output"
    else
        err "today produced no output"
    fi
else
    skp "today"
fi
echo

# ── Summary ───────────────────────────────────────────────────────────────────
echo "========================================"
log "Summary"
echo -e "  PASS : $passed"
echo -e "  SKIP : $skipped"
[[ $failed -gt 0 ]] && echo -e "  FAIL : $failed" || true
echo

[[ $failed -gt 0 ]] && exit 1 || exit 0
