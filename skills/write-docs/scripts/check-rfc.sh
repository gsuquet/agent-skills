#!/usr/bin/env bash
# Check an RFC against the template rules and the done criteria of its status.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: check-rfc.sh <rfc-file> [--target <status>] [--skip-adr]

Checks an RFC (docs/rfc/NNNN-slug.md) against the done criteria of a status, from the lifecycle
in SKILL.md. Prints one line per failure on stderr, or one "ok" line on stdout.

  draft       front matter keys, file name, title line, every section heading once and in order.
  review      draft, plus: no <...> placeholder outside code; valid front matter values; every
              section filled; optional sections filled or "N/A: <reason>"; Operational impact
              N/A rules; options and length limits of the track; Decision is "Pending.".
  accepted    review, plus: Open questions is "None."; Decision filled and standing alone; the
              Decision has a Context line, 3 lines max,
              and one Decision line per row of the Summary decision table; the ADR that
              rfc-to-adr.sh would write passes check-readability.sh --type adr. Once the ADR
              exists, an RFC without Context, with another number of Decision lines or with a
              longer ADR stays valid, and the ADR in adr: matches the Decision section.
  rejected    review, plus: Decision filled with the rejection; adr: null.
  withdrawn   draft, plus: Decision starts with "Withdrawn on YYYY-MM-DD: <reason>"; adr: null.
  superseded  accepted, plus: superseded-by: names an existing RFC; the ADR status is
              "superseded by ADR-NNNN", the ADR of that RFC.

Options:
  --target <status>  check the criteria of <status> instead of the current status. The move
                     must be allowed: draft -> review | withdrawn, review -> accepted | rejected |
                     withdrawn, accepted -> superseded.
  --skip-adr         skip the adr: criterion (rfc-to-adr.sh uses it before it writes the ADR)
  -h, --help         show this help

Exit codes: 0 all criteria pass, 1 at least one failure, 2 usage error.
EOF
}

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null # lib.sh sits next to this script.
. "${here}/lib.sh"

file=""
target=""
skip_adr=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --target)
            [[ $# -ge 2 ]] || {
                echo "error: --target needs a status" >&2
                exit 2
            }
            target="$2"
            shift 2
            ;;
        --skip-adr)
            skip_adr=true
            shift
            ;;
        -*)
            echo "error: unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
        *)
            [[ -z "${file}" ]] || {
                echo "error: expected one RFC file" >&2
                exit 2
            }
            file="$1"
            shift
            ;;
    esac
done
[[ -n "${file}" ]] || {
    usage >&2
    exit 2
}
[[ -f "${file}" && -r "${file}" ]] || {
    echo "error: cannot read '${file}'" >&2
    exit 2
}

failures=()
fail() {
    failures+=("$1")
}
report() {
    if [[ ${#failures[@]} -gt 0 ]]; then
        for failure in "${failures[@]}"; do
            echo "${file}: ${failure}" >&2
        done
        exit 1
    fi
    echo "ok: ${file} meets the ${target} criteria"
    exit 0
}
date_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
confidence_re='^(high|medium|low)[,:]? [^[:space:]]'

# Location and name.
root="$(rfc_root "${file}")" || {
    fail "must be in a docs/rfc/ folder"
    root=""
}
name="$(basename "${file}")"
number=""
if [[ "${name}" =~ ^([0-9]{4})-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]]; then
    number="${BASH_REMATCH[1]}"
else
    fail "file name must be NNNN-slug.md (4 digits, kebab-case slug)"
fi

# Front matter and status.
[[ "$(head -n 1 "${file}")" == "---" ]] || {
    fail "front matter must start on line 1 with ---"
    target="${target:-draft}"
    report
}
for key in "${RFC_KEYS[@]}"; do
    fm_has "${file}" "${key}" || fail "front matter: missing key '${key}'"
done
status="$(fm_get "${file}" status)"
case "${status}" in
    draft | review | accepted | rejected | withdrawn | superseded) ;;
    *)
        fail "status must be draft, review, accepted, rejected, withdrawn or superseded, got '${status}'"
        target="${target:-draft}"
        report
        ;;
esac
target="${target:-${status}}"
if [[ "${target}" != "${status}" ]]; then
    case "${status}:${target}" in
        draft:review | draft:withdrawn | review:accepted | review:rejected | review:withdrawn | accepted:superseded) ;;
        *)
            fail "cannot move from status '${status}' to '${target}'"
            report
            ;;
    esac
fi

# Title line and sections.
title="$(fm_get "${file}" title)"
h1="$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm && /^# / { print; exit }' "${file}")"
[[ -n "${h1}" ]] || fail "missing the title line '# RFC NNNN: <title>'"
found="$(headings "${file}")"
sections_ok=true
for heading in "${RFC_SECTIONS[@]}"; do
    count="$(grep -cxF -- "${heading}" <<< "${found}" || true)"
    [[ "${count}" -eq 1 ]] || {
        fail "section '## ${heading}' must appear once, found ${count}"
        sections_ok=false
    }
done
while IFS= read -r heading; do
    [[ -n "${heading}" ]] || continue
    known=false
    for expected in "${RFC_SECTIONS[@]}"; do
        [[ "${heading}" == "${expected}" ]] && known=true
    done
    [[ "${known}" == true ]] || fail "unknown section '## ${heading}': use '### ' inside a section"
done <<< "${found}"
if [[ "${sections_ok}" == true && "$(grep -xF -f <(printf '%s\n' "${RFC_SECTIONS[@]}") <<< "${found}" || true)" != "$(printf '%s\n' "${RFC_SECTIONS[@]}")" ]]; then
    fail "sections must follow the template order: $(printf '%s, ' "${RFC_SECTIONS[@]}" | sed 's/, $//')"
fi

decision="$(section "${file}" Decision | trim)"
adr="$(fm_get "${file}" adr)"

if [[ "${target}" == draft ]]; then
    report
fi

if [[ "${target}" == withdrawn ]]; then
    [[ "$(head -n 1 <<< "${decision}")" =~ ^Withdrawn\ on\ [0-9]{4}-[0-9]{2}-[0-9]{2}:\ [^[:space:]] ]] ||
        fail "Decision must start with 'Withdrawn on YYYY-MM-DD: <reason>'"
    is_unset "${adr}" || fail "adr: must be null: a withdrawn RFC has no ADR"
    report
fi

# From here: review, accepted, rejected, superseded.
while IFS= read -r line; do
    [[ -n "${line}" ]] && fail "placeholder left, ${line}"
done <<< "$(placeholders "${file}")"

# Front matter values.
[[ -z "${number}" || "$(fm_get "${file}" rfc)" == "${number}" ]] || fail "rfc: must be ${number}, the number in the file name"
[[ -n "${title}" && ${#title} -le 60 ]] || fail "title: must be set, 60 characters max"
[[ -z "${number}" || "${h1}" == "# RFC ${number}: ${title}" ]] || fail "title line must be '# RFC ${number}: ${title}'"
track="$(fm_get "${file}" track)"
[[ "${track}" == lightweight || "${track}" == full ]] || fail "track: must be lightweight or full"
reversibility="$(fm_get "${file}" reversibility)"
[[ "${reversibility}" == one-way || "${reversibility}" == two-way ]] || fail "reversibility: must be one-way or two-way"
for key in author deciders; do
    is_unset "$(fm_get "${file}" "${key}")" && fail "${key}: must be set"
done
for key in created updated; do
    [[ "$(fm_get "${file}" "${key}")" =~ ${date_re} ]] || fail "${key}: must be a YYYY-MM-DD date"
done
[[ "$(fm_get "${file}" review)" =~ ^https?:// ]] || fail "review: must be the URL of the PR/MR"
supersedes="$(fm_get "${file}" supersedes)"
if ! is_unset "${supersedes}"; then
    if [[ ! "${supersedes}" =~ ^[0-9]{4}$ ]]; then
        fail "supersedes: must be a 4-digit RFC number or null"
    elif ! compgen -G "$(dirname "${file}")/${supersedes}-*.md" > /dev/null; then
        fail "supersedes: no RFC ${supersedes} in $(dirname "${file}")"
    fi
fi

# Sections: filled, N/A only on optional sections and always with a reason.
for index in "${!RFC_SECTIONS[@]}"; do
    heading="${RFC_SECTIONS[${index}]}"
    body="$(section "${file}" "${heading}" | trim)"
    if [[ -z "${body}" ]]; then
        fail "section '${heading}' is empty"
    elif [[ "${body}" == N/A* ]]; then
        if [[ ${index} -lt ${RFC_REQUIRED} ]]; then
            fail "section '${heading}' is required: N/A is not allowed"
        elif [[ ! "${body}" =~ ^N/A:\ [^[:space:]] ]]; then
            fail "section '${heading}': write 'N/A: <reason>'"
        fi
    fi
done

nonblank() { grep -c '[^[:space:]]' || true; }
[[ "$(section "${file}" Context | nonblank)" -le 15 ]] || fail "Context: 15 lines max"
section "${file}" "Goals and non-goals" | awk '/^Non-goals:/ { ng = 1; next } ng && /^- [^[:space:]]/ { found = 1 } END { exit !found }' ||
    fail "Goals and non-goals: needs a 'Non-goals:' line followed by at least one '- ' bullet"
options="$(section "${file}" "Options considered" | awk -v fence_re="${FENCE}" '$0 ~ fence_re { fence = !fence; next } !fence && /^### / { print }')"
grep -qix '### Do nothing' <<< "${options}" || fail "Options considered: needs a '### Do nothing' option"
option_count="$(grep -c '^### ' <<< "${options}" || true)"
if [[ "${track}" == full && "${option_count}" -lt 3 ]]; then
    fail "Options considered: full track needs 2 options plus Do nothing, found ${option_count} '### ' options"
elif [[ "${option_count}" -lt 2 ]]; then
    fail "Options considered: needs 1 option plus Do nothing, found ${option_count} '### ' options"
fi
if [[ "${track}" == lightweight && "$(section "${file}" Proposal | nonblank)" -gt 20 ]]; then
    fail "Proposal: 20 lines max on the lightweight track: shorten it or move to the full track"
fi

# Operational impact: 7 lines, filled; N/A with a reason; some lines never N/A.
ops="$(section "${file}" "Operational impact")"
for label in "${OPS_LINES[@]}"; do
    count="$(grep -c "^- ${label}:" <<< "${ops}" || true)"
    if [[ "${count}" -ne 1 ]]; then
        fail "Operational impact: needs exactly one '- ${label}:' line, found ${count}"
        continue
    fi
    value="$(sed -n "s/^- ${label}:[[:space:]]*//p" <<< "${ops}" | sed 's/[[:space:]]*$//')"
    if [[ -z "${value}" ]]; then
        fail "Operational impact: '${label}' is empty"
    elif [[ "${value}" == N/A* ]]; then
        case "${label}:${track}" in
            "Blast radius:"* | "Rollback:"* | "Migration:"* | "Observability:full")
                fail "Operational impact: '${label}' cannot be N/A on the ${track} track"
                ;;
            *)
                [[ "${value}" =~ ^N/A:\ [^[:space:]] ]] || fail "Operational impact: '${label}': write 'N/A: <reason>'"
                ;;
        esac
    fi
done

# Open questions and Decision, by target status.
stand_alone='see (above|below)|as (described|mentioned|stated) (above|below)|the (section|options?) above'
# No ADR yet: the rules that an older accepted RFC need not follow apply.
undecided=false
if is_unset "${adr}" || [[ -z "${root}" || ! -f "${root}/${adr}" ]]; then undecided=true; fi

# check_decision_count: one Decision line per row of the Summary decision table.
check_decision_count() {
    local rows lines
    rows="$("${here}/check-readability.sh" --type rfc --count-decisions "${file}")" || rows=0
    lines="$(grep -c '^- Decision:[[:space:]]*[^[:space:]]' <<< "${decision}" || true)"
    [[ "${rows}" -gt 0 ]] || {
        fail "Summary: needs a decision table (check-readability.sh --type rfc)"
        return
    }
    [[ "${rows}" -eq "${lines}" ]] ||
        fail "Decision: needs one '- Decision:' line per row of the Summary decision table: ${rows} rows, ${lines} lines"
}

# check_adr_limits: the ADR that rfc-to-adr.sh would write passes the readability limits.
check_adr_limits() {
    local tmp path finding findings=""
    path="$(adr_of "${file}" "${here}")"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/check-rfc.XXXXXX")"
    render_adr "${file}" "${path}" "${here}/../assets/adr.md" > "${tmp}/adr.md"
    findings="$("${here}/check-readability.sh" --type adr "${tmp}/adr.md" 2>&1 > /dev/null)" || true
    rm -rf "${tmp}"
    while IFS= read -r finding; do
        [[ -z "${finding}" ]] || fail "Decision: the ADR fails: ${finding#"${tmp}/adr.md:"}"
    done <<< "${findings}"
}
decision_line() {
    sed -n "s/^- $1:[[:space:]]*//p" <<< "${decision}" | head -n 1
}
case "${target}" in
    review)
        [[ "${decision}" == "Pending." ]] || fail "Decision: must be 'Pending.' until the RFC is accepted or rejected"
        ;;
    accepted | superseded)
        [[ "$(section "${file}" "Open questions" | trim)" == "None." ]] ||
            fail "Open questions: must be 'None.': resolve each question or move it to Future work"
        [[ "$(decision_line Status)" =~ ^accepted\ on\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ by\ [^[:space:]] ]] ||
            fail "Decision: needs '- Status: accepted on YYYY-MM-DD by <deciders>'"
        if grep -q '^- Context:' <<< "${decision}"; then
            context="$(awk '/^- / { in_context = /^- Context:/ } in_context && NF { print }' <<< "${decision}")"
            [[ "${context#- Context:}" =~ [^[:space:]] ]] || fail "Decision: '- Context:' is empty"
            # The label alone on its line is not a line of Context.
            context="$(sed '1{/^- Context:[[:space:]]*$/d;}' <<< "${context}")"
            [[ "$(nonblank <<< "${context}")" -le 3 ]] || fail "Decision: Context: 3 lines max"
        elif [[ "${undecided}" == true ]]; then
            fail "Decision: needs a '- Context:' line"
        fi
        [[ -n "$(decision_line Decision)" ]] || fail "Decision: needs a filled '- Decision:' line"
        if [[ "${undecided}" == true ]]; then
            check_decision_count
            [[ -z "${root}" || -z "${number}" ]] || check_adr_limits
        fi
        grep -q '^- Consequences:' <<< "${decision}" || fail "Decision: needs a '- Consequences:' line"
        grep -q '^  - Good: [^[:space:]]' <<< "${decision}" || fail "Decision: needs a '  - Good:' consequence"
        grep -q '^  - Bad: [^[:space:]]' <<< "${decision}" || fail "Decision: needs a '  - Bad:' consequence"
        [[ "$(decision_line Confidence)" =~ ${confidence_re} ]] ||
            fail "Decision: needs '- Confidence: <high | medium | low>, <reason>'"
        [[ -n "$(decision_line Confirmation)" ]] || fail "Decision: needs a filled '- Confirmation:' line"
        [[ -n "$(decision_line 'Revisit when')" ]] || fail "Decision: needs a filled '- Revisit when:' line"
        ;;
    rejected)
        [[ "$(decision_line Status)" =~ ^rejected\ on\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ by\ [^[:space:]] ]] ||
            fail "Decision: needs '- Status: rejected on YYYY-MM-DD by <deciders>'"
        [[ -n "$(decision_line Decision)" ]] || fail "Decision: needs a '- Decision:' line with the reason for the rejection"
        ;;
esac
if [[ "${target}" != review ]] && grep -qiE "${stand_alone}" <<< "${decision}"; then
    fail "Decision: must stand alone, it is copied into the ADR: replace 'see above' by the content"
fi

# superseded-by: set only once superseded.
superseded_by="$(fm_get "${file}" superseded-by)"
successor=""
if [[ "${target}" == superseded ]]; then
    if [[ ! "${superseded_by}" =~ ^[0-9]{4}$ ]]; then
        fail "superseded-by: must be the 4-digit number of the new RFC (run supersede.sh)"
    else
        successor="$(compgen -G "$(dirname "${file}")/${superseded_by}-*.md" | head -n 1 || true)"
        [[ -n "${successor}" ]] || fail "superseded-by: no RFC ${superseded_by} in $(dirname "${file}")"
    fi
else
    is_unset "${superseded_by}" || fail "superseded-by: must be null until the RFC is superseded"
fi

# adr: null unless accepted; once accepted, the ADR must match the Decision section.
check_adr() {
    local path="${root}/${adr}" adr_name adr_status expected
    [[ -f "${path}" ]] || {
        fail "adr: '${adr}' does not exist: run rfc-to-adr.sh"
        return
    }
    adr_name="$(basename "${path}")"
    [[ "${adr_name}" =~ ^([0-9]{4})- && "$(fm_get "${path}" adr)" == "${BASH_REMATCH[1]}" ]] ||
        fail "ADR ${adr}: adr: must equal the number in its file name"
    [[ "$(fm_get "${path}" rfc)" == "docs/rfc/${name}" ]] || fail "ADR ${adr}: rfc: must be docs/rfc/${name}"
    adr_status="$(fm_get "${path}" status)"
    if [[ "${status}" == superseded ]]; then
        expected="accepted"
        if [[ -n "${successor}" ]]; then
            expected="superseded by ADR-$(basename "$(fm_get "${successor}" adr)" | cut -c1-4)"
        fi
        [[ "${adr_status}" == "${expected}" ]] || fail "ADR ${adr}: status must be '${expected}' (run supersede.sh)"
    else
        [[ "${adr_status}" == accepted ]] || fail "ADR ${adr}: status must be 'accepted'"
    fi
    if [[ "$(awk '/^# / { body = 1; next } body && /^Source: / { exit } body { print }' "${path}" | trim)" != "${decision}" ]]; then
        fail "ADR ${adr}: differs from the RFC's Decision section: re-run rfc-to-adr.sh, never edit the ADR"
    fi
}
case "${target}" in
    accepted | superseded)
        if [[ "${skip_adr}" == false && ("${status}" == accepted || "${status}" == superseded) ]]; then
            if is_unset "${adr}"; then
                fail "adr: must be set: run rfc-to-adr.sh"
            elif [[ -n "${root}" ]]; then
                check_adr
            fi
        fi
        ;;
    *)
        is_unset "${adr}" || fail "adr: must be null: only an accepted RFC has an ADR"
        ;;
esac

report
