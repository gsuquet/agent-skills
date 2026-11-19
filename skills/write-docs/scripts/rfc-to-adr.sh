#!/usr/bin/env bash
# Write the ADR of an accepted RFC and link it from the RFC.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: rfc-to-adr.sh <rfc-file>

Writes the ADR of an accepted RFC from assets/adr.md: front matter, the RFC's Decision section
copied verbatim, and a link back to the RFC. Then sets the RFC's adr: field to the ADR path.

The ADR path is the RFC's adr: value when set, else the one next-number.sh prints. Running it again
rewrites the same ADR and changes nothing when the RFC did not change.

Refuses unless the RFC status is accepted and check-rfc.sh passes (adr: aside).

Options:
  -h, --help  show this help

Exit codes: 0 ADR written or unchanged, 1 refused or failed (reason on stderr), 2 usage error.
EOF
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "")
        usage >&2
        exit 2
        ;;
esac
[[ $# -eq 1 ]] || {
    echo "error: expected one RFC file, got $#" >&2
    exit 2
}
file="$1"
[[ -f "${file}" && -r "${file}" && -w "${file}" ]] || {
    echo "error: cannot read and write '${file}'" >&2
    exit 2
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null # lib.sh sits next to this script.
. "${here}/lib.sh"
template="${here}/../assets/adr.md"
[[ -f "${template}" ]] || {
    echo "error: missing ADR template ${template}" >&2
    exit 1
}

status="$(fm_get "${file}" status)"
[[ "${status}" == accepted ]] || {
    echo "error: ${file} has status '${status}': only an accepted RFC gets an ADR" >&2
    exit 1
}
"${here}/check-rfc.sh" --skip-adr "${file}" > /dev/null || {
    echo "error: ${file} fails check-rfc.sh (failures above): fix them, then run rfc-to-adr.sh again" >&2
    exit 1
}

root="$(rfc_root "${file}")"
name="$(basename "${file}")"
slug="${name#[0-9][0-9][0-9][0-9]-}"
slug="${slug%.md}"
adr="$(fm_get "${file}" adr)"
if is_unset "${adr}"; then
    adr="$("${here}/next-number.sh" adr "${slug}" --root "${root}")"
fi
[[ "$(basename "${adr}")" =~ ^([0-9]{4})-[a-z0-9-]+\.md$ ]] || {
    echo "error: adr: '${adr}' is not a NNNN-slug.md path" >&2
    exit 1
}
adr_number="${BASH_REMATCH[1]}"
adr_path="${root}/${adr}"

decision="$(section "${file}" Decision | trim)"
decision_date="$(sed -n 's/^- Status: accepted on \([0-9-]*\) .*/\1/p' <<< "${decision}" | head -n 1)"
# From the ADR folder back to the root: one ".." per path segment.
up="$(dirname "${adr}" | sed 's#[^/][^/]*#..#g')"

tmp="$(mktemp "${TMPDIR:-/tmp}/rfc-to-adr.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT
ADR_NUMBER="${adr_number}" \
    RFC_TITLE="$(fm_get "${file}" title)" \
    DECISION_DATE="${decision_date}" \
    RFC_PATH="docs/rfc/${name}" \
    REVIEW_URL="$(fm_get "${file}" review)" \
    RFC_NUMBER="$(fm_get "${file}" rfc)" \
    RFC_LINK="${up}/docs/rfc/${name}" \
    DECISION="${decision}" \
    awk '
        # Literal replacement: gsub would treat "&" in a URL as the match.
        function put(s, token, value,    out, i) {
            out = ""
            while ((i = index(s, token)) > 0) {
                out = out substr(s, 1, i - 1) value
                s = substr(s, i + length(token))
            }
            return out s
        }
        $0 == "<rfc-decision-section>" { print ENVIRON["DECISION"]; next }
        {
            line = put($0, "<adr-number>", ENVIRON["ADR_NUMBER"])
            line = put(line, "<rfc-title>", ENVIRON["RFC_TITLE"])
            line = put(line, "<decision-date>", ENVIRON["DECISION_DATE"])
            line = put(line, "<rfc-path>", ENVIRON["RFC_PATH"])
            line = put(line, "<review-url>", ENVIRON["REVIEW_URL"])
            line = put(line, "<rfc-number>", ENVIRON["RFC_NUMBER"])
            line = put(line, "<rfc-link>", ENVIRON["RFC_LINK"])
            print line
        }
    ' "${template}" > "${tmp}"

if [[ -f "${adr_path}" ]] && cmp -s "${tmp}" "${adr_path}"; then
    result="unchanged"
else
    mkdir -p "$(dirname "${adr_path}")"
    cat "${tmp}" > "${adr_path}"
    result="written"
fi
[[ "$(fm_get "${file}" adr)" == "${adr}" ]] || fm_set "${file}" adr "${adr}"

"${here}/check-rfc.sh" "${file}" > /dev/null || {
    echo "error: ${file} fails check-rfc.sh after writing ${adr} (failures above)" >&2
    exit 1
}
echo "${adr} ${result}"
