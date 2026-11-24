#!/usr/bin/env bash
# Mark an accepted RFC and its ADR as superseded by a newer accepted RFC.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: supersede.sh <old-rfc-file> <new-rfc-file>

Marks the old RFC as superseded by the new one:
  - old RFC: status: superseded, superseded-by: <new number>, updated: today;
  - old ADR: status: superseded by ADR-<number of the new RFC's ADR>.
Nothing else changes. Running it again changes nothing.

Refuses unless both RFCs are in the same docs/rfc/ folder, the new RFC is accepted, has
supersedes: <old number>, has its ADR (run rfc-to-adr.sh first) and passes check-rfc.sh, and the
old RFC is accepted (or already superseded by the new one).

Options:
  -h, --help  show this help

Exit codes: 0 done or already done, 1 refused or failed (reason on stderr), 2 usage error.
EOF
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
esac
[[ $# -eq 2 ]] || {
    usage >&2
    exit 2
}
old="$1"
new="$2"
for f in "${old}" "${new}"; do
    [[ -f "${f}" && -r "${f}" && -w "${f}" ]] || {
        echo "error: cannot read and write '${f}'" >&2
        exit 2
    }
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null # lib.sh sits next to this script.
. "${here}/lib.sh"

refuse() {
    echo "error: $1" >&2
    exit 1
}

root="$(rfc_root "${old}")" || refuse "${old} is not in a docs/rfc/ folder"
[[ "$(rfc_root "${new}" || true)" == "${root}" ]] || refuse "${old} and ${new} must be in the same docs/rfc/ folder"
old_number="$(fm_get "${old}" rfc)"
new_number="$(fm_get "${new}" rfc)"

[[ "$(fm_get "${new}" status)" == accepted ]] || refuse "${new} must be accepted first"
[[ "$(fm_get "${new}" supersedes)" == "${old_number}" ]] || refuse "${new} must have supersedes: ${old_number}"
new_adr="$(fm_get "${new}" adr)"
is_unset "${new_adr}" && refuse "${new} has no ADR: run rfc-to-adr.sh ${new} first"
"${here}/check-rfc.sh" "${new}" > /dev/null || refuse "${new} fails check-rfc.sh (failures above)"
new_adr_number="$(basename "${new_adr}" | cut -c1-4)"

old_adr="$(fm_get "${old}" adr)"
is_unset "${old_adr}" && refuse "${old} has no adr: field"
[[ -f "${root}/${old_adr}" ]] || refuse "ADR ${old_adr} of ${old} does not exist"

case "$(fm_get "${old}" status)" in
    accepted)
        fm_set "${old}" status superseded
        fm_set "${old}" superseded-by "${new_number}"
        fm_set "${old}" updated "$(date +%Y-%m-%d)"
        ;;
    superseded)
        [[ "$(fm_get "${old}" superseded-by)" == "${new_number}" ]] ||
            refuse "${old} is already superseded by RFC $(fm_get "${old}" superseded-by)"
        ;;
    *)
        refuse "${old} must be accepted, got status '$(fm_get "${old}" status)'"
        ;;
esac
adr_status="superseded by ADR-${new_adr_number}"
[[ "$(fm_get "${root}/${old_adr}" status)" == "${adr_status}" ]] || fm_set "${root}/${old_adr}" status "${adr_status}"

"${here}/check-rfc.sh" "${old}" > /dev/null || refuse "${old} fails check-rfc.sh after the update (failures above)"
echo "RFC ${old_number} superseded by RFC ${new_number}; ${old_adr}: ${adr_status}"
