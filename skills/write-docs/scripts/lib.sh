# shellcheck shell=bash
# Helpers shared by the RFC scripts. Source this file; do not run it. Works with bash 3.2.
# shellcheck disable=SC2034 # The arrays are read by the scripts that source this file.

# Sections of an RFC, in order. The first RFC_REQUIRED ones are required: never N/A.
RFC_SECTIONS=("Summary" "Context" "Goals and non-goals" "Decision drivers" "Options considered"
    "Proposal" "Operational impact" "Drawbacks and risks" "Open questions" "Decision"
    "Implementation" "References" "Future work")
RFC_REQUIRED=10
RFC_KEYS=(rfc title status track reversibility author deciders created updated review adr
    supersedes superseded-by)
OPS_LINES=("Blast radius" "Rollout" "Rollback" "Migration" "Security" "Cost" "Observability")

# A code fence opens or closes on a line that starts with ``` or ~~~, indentation allowed.
FENCE='^[[:space:]]*(```|~~~)'

# front_matter <file>: print the lines between the opening and the closing "---".
front_matter() {
    awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

# fm_has <file> <key>: succeed when the front matter has the key.
fm_has() {
    front_matter "$1" | grep -q "^$2:"
}

# fm_get <file> <key>: print the value of a front matter key, trimmed.
fm_get() {
    front_matter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -n 1 | sed 's/[[:space:]]*$//'
}

# is_unset <value>: succeed when a front matter value is empty or null.
is_unset() {
    [[ -z "$1" || "$1" == null || "$1" == "~" ]]
}

# fm_set <file> <key> <value>: replace the value of a front matter key, in place.
fm_set() {
    local file="$1" tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    KEY="$2" VALUE="$3" awk '
        NR == 1 && $0 == "---" { infm = 1; print; next }
        infm && $0 == "---" { infm = 0; print; next }
        infm && index($0, ENVIRON["KEY"] ":") == 1 { print ENVIRON["KEY"] ": " ENVIRON["VALUE"]; next }
        { print }
    ' "${file}" > "${tmp}"
    # Copy instead of mv: the file keeps its permissions.
    cat "${tmp}" > "${file}"
    rm -f "${tmp}"
}

# headings <file>: print the "## " headings outside code fences, without the "## ".
headings() {
    awk -v fence_re="${FENCE}" '
        $0 ~ fence_re { fence = !fence; next }
        !fence && /^## / { print substr($0, 4) }
    ' "$1"
}

# section <file> <heading>: print the body of a "## " section, up to the next "## " heading.
section() {
    awk -v fence_re="${FENCE}" -v name="$2" '
        !fence && /^## / { in_section = (substr($0, 4) == name); next }
        $0 ~ fence_re { fence = !fence }
        in_section { print }
    ' "$1"
}

# trim: drop the leading and trailing blank lines of stdin.
trim() {
    awk 'NF { for (; blank > 0; blank--) print ""; print; started = 1; next } started { blank++ }'
}

# placeholders <file>: print "line N: <...>" for each placeholder left outside code.
# Autolinks (<https://...>) and inline code spans do not count.
placeholders() {
    awk -v fence_re="${FENCE}" '
        $0 ~ fence_re { fence = !fence; next }
        fence { next }
        {
            line = $0
            gsub(/`[^`]*`/, "", line)
            gsub(/<(https?|mailto):[^<>]*>/, "", line)
            while (match(line, /<[A-Za-z0-9][^<>]*>/)) {
                print "line " NR ": " substr(line, RSTART, RLENGTH)
                line = substr(line, RSTART + RLENGTH)
            }
            # A placeholder wrapped onto the next line.
            if (match(line, /<[A-Za-z0-9][^<>]*$/)) print "line " NR ": " substr(line, RSTART)
        }
    ' "$1"
}

# rfc_root <rfc-file>: print the root that holds docs/rfc/, or fail.
rfc_root() {
    local dir
    dir="$(cd "$(dirname "$1")" && pwd -P)" || return 1
    [[ "$(basename "${dir}")" == rfc && "$(basename "$(dirname "${dir}")")" == docs ]] || return 1
    dirname "$(dirname "${dir}")"
}
