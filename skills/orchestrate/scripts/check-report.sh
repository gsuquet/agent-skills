#!/usr/bin/env bash
# Fail when a subagent report misses a required field, or when the check named in its brief fails
# when the main session re-runs it.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: check-report.sh [-C <dir>] <report-file> -- <check command> [<arg>...]

1. Checks the report written in the Report format of assets/brief.md. Each section is a markdown
   heading (any level) whose text starts with the section name; case does not matter.
     Links and paths   at least one path or URL (a line with "/")
     Checks            at least one non-blank line other than "None."
     Judgement calls   at least one non-blank line ("None." is allowed)
     Unverified        at least one non-blank line ("None." is allowed)
2. Runs the check command itself, in <dir> when -C is given, and prints its output. Take the
   command from the brief's Finish condition, never from the report.

Options:
  -C <dir>    Run the check command in <dir> (the agent's worktree)
  -h, --help  Show this help

Exit codes: 0 report complete and check passed, 1 report incomplete or check failed (each finding
on stderr), 2 usage error.
EOF
}

die_usage() {
    echo "error: $*" >&2
    echo "run 'check-report.sh --help' for usage" >&2
    exit 2
}

dir=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -C)
            [[ $# -ge 2 ]] || die_usage "-C needs a directory"
            dir="$2"
            shift 2
            ;;
        *) break ;;
    esac
done

[[ $# -ge 1 ]] || die_usage "missing <report-file>"
report="$1"
shift
[[ "${1:-}" == "--" ]] || die_usage "missing '--' before the check command"
shift
[[ $# -ge 1 ]] || die_usage "missing check command after '--'"
[[ -f "${report}" && -r "${report}" ]] || die_usage "'${report}' is not a readable file"
if [[ -n "${dir}" ]]; then
    [[ -d "${dir}" ]] || die_usage "'${dir}' is not a directory"
    dir="$(cd "${dir}" && pwd)"
fi

# Section body: the lines after the first heading that starts with the name, up to the next heading
# of any level. A "# " line inside a code fence (shell output) is body, not a heading.
section() {
    awk -v name="$1" '
        /^ *(```|~~~)/ { fence = !fence; if (inside) print; next }
        !fence && /^#+ / {
            if (inside) exit
            heading = tolower($0)
            sub(/^#+ +/, "", heading)
            if (substr(heading, 1, length(name)) == tolower(name)) { inside = 1; found = 1 }
            next
        }
        inside && /[^ \t]/ { print }
        END { if (!found) exit 3 }
    ' "${report}"
}

findings=0
finding() {
    echo "${report}: $*" >&2
    findings=$((findings + 1))
}

# name<TAB>rule: path = needs a "/", result = non-empty and not only "None.", any = non-empty.
while IFS=$'\t' read -r name rule; do
    status=0
    body="$(section "${name}")" || status=$?
    if [[ ${status} -eq 3 ]]; then
        finding "missing section \"${name}\""
        continue
    fi
    if [[ -z "${body}" ]]; then
        finding "empty section \"${name}\""
        continue
    fi
    case "${rule}" in
        path) grep -q '/' <<< "${body}" || finding "section \"${name}\" has no path or URL" ;;
        result)
            grep -qvE '^[[:space:]]*(-[[:space:]]*)?None\.?[[:space:]]*$' <<< "${body}" ||
                finding "section \"${name}\" reports no check result"
            ;;
        any) ;;
    esac
done << 'EOF'
Links and paths	path
Checks	result
Judgement calls	any
Unverified	any
EOF

# Print where and what runs: a check that passes on the wrong tree proves nothing.
echo "running in ${dir:-$(pwd)}: $*" >&2
check_status=0
if [[ -n "${dir}" ]]; then
    (cd "${dir}" && "$@") || check_status=$?
else
    "$@" || check_status=$?
fi
if [[ ${check_status} -ne 0 ]]; then
    echo "error: check command exited ${check_status}: $*" >&2
    findings=$((findings + 1))
fi

if [[ ${findings} -gt 0 ]]; then
    echo "error: ${findings} finding(s) for ${report}" >&2
    exit 1
fi
echo "ok: ${report} is complete and the check passed"
