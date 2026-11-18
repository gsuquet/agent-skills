# shellcheck shell=bash
# Functions shared by the scripts in scripts/. Source it, do not run it.

# Semantic Versioning 2.0.0: MAJOR.MINOR.PATCH, optional -prerelease and +build.
# shellcheck disable=SC2034 # read by the scripts that source this file
SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

# Value of a single-line top-level frontmatter key, quotes removed. Reads the file $1, or stdin
# when $1 is "-".
frontmatter() {
    awk -v key="$2" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        index($0, key ":") == 1 {
            sub("^" key ":[[:space:]]*", "")
            gsub(/^["\x27]|["\x27]$/, "")
            print
            exit
        }
    ' "$1"
}

# Value of "version" under the top-level "metadata" key of the frontmatter, quotes removed. Reads
# the file $1, or stdin when $1 is "-". Prints nothing when the key is missing.
skill_version() {
    awk '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        /^[^[:space:]#]/ { in_metadata = ($0 ~ /^metadata:[[:space:]]*$/); next }
        in_metadata && /^[[:space:]]+version:/ {
            sub(/^[[:space:]]+version:[[:space:]]*/, "")
            sub(/[[:space:]]+$/, "")
            gsub(/^["\x27]|["\x27]$/, "")
            print
            exit
        }
    ' "$1"
}

# 0 when version $1 is higher than version $2. Compares MAJOR.MINOR.PATCH only: a -prerelease
# or +build suffix is ignored.
version_gt() {
    local -a a b
    IFS=. read -r -a a <<< "${1%%[-+]*}"
    IFS=. read -r -a b <<< "${2%%[-+]*}"
    local i
    for i in 0 1 2; do
        ((10#${a[i]} > 10#${b[i]})) && return 0
        ((10#${a[i]} < 10#${b[i]})) && return 1
    done
    return 1
}
