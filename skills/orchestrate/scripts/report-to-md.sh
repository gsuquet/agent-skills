#!/usr/bin/env bash
# Turn a JSON report (assets/report.schema.json) into the markdown Report format of assets/brief.md,
# so scripts/check-report.sh can read it.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: report-to-md.sh <report.json|->

Prints the report as markdown on stdout, in the Report format of assets/brief.md. Empty lists
become "None.". Reads stdin when the argument is "-".

Options:
  -h, --help  Show this help

Exit codes: 0 converted, 1 the JSON misses a required field of assets/report.schema.json,
2 usage error or invalid JSON.
EOF
}

die_usage() {
    echo "error: $*" >&2
    echo "run 'report-to-md.sh --help' for usage" >&2
    exit 2
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "") die_usage "missing <report.json>" ;;
esac
[[ $# -eq 1 ]] || die_usage "expected one argument, got $#"
command -v jq > /dev/null || die_usage "jq is required"

if [[ "$1" == "-" ]]; then
    json="$(cat)"
else
    [[ -f "$1" && -r "$1" ]] || die_usage "'$1' is not a readable file"
    json="$(cat "$1")"
fi
jq -e . > /dev/null 2>&1 <<< "${json}" || die_usage "'$1' is not valid JSON"

missing="$(jq -r '
    [ ("outcome.status", "outcome.reason") as $k
      | select(($k | split(".")) as $p | getpath($p) | type != "string" or length == 0) | $k ] +
    [ ("links", "checks", "judgement_calls", "unverified", "requests") as $k
      | select(.[$k] | type != "array") | $k ] +
    [ ("links", "checks") as $k | select((.[$k] | type) == "array" and (.[$k] | length) == 0) | $k ]
    | .[]' <<< "${json}")"
if [[ -n "${missing}" ]]; then
    while IFS= read -r field; do
        echo "missing or empty: ${field}" >&2
    done <<< "${missing}"
    exit 1
fi

jq -r '
    def list: if length == 0 then "None." else map("- " + .) | join("\n") end;
    "## Outcome\n\n\(.outcome.status): \(.outcome.reason)\n",
    "## Links and paths\n\n\(.links | list)\n",
    "## Checks\n\n\(.checks | map("- `\(.command)` -> \(.result)"
        + (if .result == "fail" and (.output | length) > 0 then ": \(.output)" else "" end))
        | join("\n"))\n",
    "## Judgement calls\n\n\(.judgement_calls | list)\n",
    "## Unverified\n\n\(.unverified | list)\n",
    "## Requests\n\n\(.requests | list)"' <<< "${json}"
