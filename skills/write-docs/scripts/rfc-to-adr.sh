#!/usr/bin/env bash
# Write the ADR of an accepted RFC and link it from the RFC.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: rfc-to-adr.sh <rfc-file>

Writes the ADR of an accepted RFC from assets/adr.md: front matter, the RFC's Decision section
copied verbatim, a link back to the RFC, and the names its allow-code comments allow. Then sets the RFC's adr: field to the ADR path.

The ADR path is the RFC's adr: value when set, else the one next-number.sh prints. Running it again
rewrites the same ADR and changes nothing when the RFC did not change.

Refuses unless the RFC status is accepted and check-rfc.sh passes (adr: aside), and when the ADR path
holds another file.

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
adr="$(adr_of "${file}" "${here}")"
[[ "$(basename "${adr}")" =~ ^[0-9]{4}-[a-z0-9-]+\.md$ ]] || {
    echo "error: adr: '${adr}' is not a NNNN-slug.md path" >&2
    exit 1
}
adr_path="${root}/${adr}"
if [[ -e "${adr_path}" && "$(fm_get "${adr_path}" rfc)" != "docs/rfc/$(basename "${file}")" ]]; then
    echo "error: ${adr} is not the ADR of ${file}: set adr: to null or to the right path" >&2
    exit 1
fi

tmp="$(mktemp "${TMPDIR:-/tmp}/rfc-to-adr.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT
render_adr "${file}" "${adr}" "${template}" "${here}" > "${tmp}"

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
