#!/usr/bin/env bash
# Human-in-the-loop template for the diagnose skill: a loop where a human performs the steps.
# Copy this file, replace the steps between the EDIT markers, then run the copy.
# The human answers in the terminal; the agent reads the KEY=VALUE lines printed at the end.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: hitl-loop.sh [-h|--help]

Copy this template, edit the steps between the EDIT markers, and run the copy.

Helpers:
  step "<instruction>"          print the instruction, wait for Enter
  capture <VAR> "<question>"    print the question, store the answer in VAR

At the end, every captured variable is printed as KEY=VALUE.
Capture observations only (yes/no, error text, timings). Never capture a secret:
ask the human to sign in with a step instead.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

[[ -t 0 ]] || {
    echo "error: needs an interactive terminal: run it where the human can answer" >&2
    exit 1
}

CAPTURED=()

step() {
    printf '\n>>> %s\n' "$1"
    read -r -p "    [Enter when done] " _
}

capture() {
    local var="$1" question="$2" answer
    [[ "${var}" =~ ^[A-Z][A-Z0-9_]*$ ]] || {
        echo "error: capture: '${var}' must be an UPPER_CASE name" >&2
        exit 1
    }
    printf '\n>>> %s\n' "${question}"
    read -r -p "    > " answer
    printf -v "${var}" '%s' "${answer}"
    CAPTURED+=("${var}")
}

# --- EDIT BELOW: replace these example steps ---------------------------------

step "Open https://app.example.test and sign in."
capture FAILED "Click 'Export'. Did it fail? (y/n)"
capture MESSAGE "Copy the error text shown, without any token or ID (or 'none'):"

# --- EDIT ABOVE --------------------------------------------------------------

printf '\n--- captured ---\n'
for var in "${CAPTURED[@]}"; do
    printf '%s=%s\n' "${var}" "${!var}"
done
