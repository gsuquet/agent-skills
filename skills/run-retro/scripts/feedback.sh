#!/usr/bin/env bash
# Append a feedback line to a skill of the skills repository, or list the skills to rework.
set -euo pipefail

usage() {
    cat << 'EOF2'
Usage:
  feedback.sh append <skill> <what went wrong> <link>
  feedback.sh rework [--min <n>]
  feedback.sh -h | --help

Works on the skills repository this script belongs to, found through its real path
(<repo>/skills/run-retro/scripts/feedback.sh): a skill installed as a symbolic link to a clone
qualifies, a copy or a plugin cache does not.

append  Appends one line to <repo>/skills/<skill>/FEEDBACK.md, and creates the file with a
        one-line header when it is missing:
          YYYY-MM-DD | <metadata.version of the skill> | <what went wrong> | <link>
        Prints the appended line. FEEDBACK.md is public: <link> is '-' or the https URL of a
        PR/MR or a commit on a host of FEEDBACK_LINK_HOSTS. Never a session URL or a local path.
        Self-hosted GitLab:
          FEEDBACK_LINK_HOSTS="github.com gitlab.com gitlab.example.com" \
            feedback.sh append describe-change "step 4 printed no command" \
            https://gitlab.example.com/example-group/repo/-/merge_requests/12
rework  Prints one tab-separated line per skill with <n> or more FEEDBACK lines (default: 3)
        at its current metadata.version, that is since its last version bump:
          <skill>  <version>  <lines>

Environment:
  FEEDBACK_LINK_HOSTS  Hosts allowed in <link>, separated by spaces or commas
                       (default: "github.com gitlab.com")

Exit codes:
  0  success
  1  usage error, a field holds '|' or a line break, or <link> is not '-' or an allowed URL
  3  not a clone of the skills repository (the skill is installed as a copy or a plugin)
  4  unknown skill, or SKILL.md has no metadata.version
EOF2
}

HEADER="# date | version | what went wrong | PR, MR or commit link"

die() {
    local code="$1"
    shift
    echo "error: $*" >&2
    exit "${code}"
}

skills_dir() {
    local here dir top
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    dir="$(dirname "$(dirname "${here}")")"
    top="$(git -C "${dir}" rev-parse --show-toplevel 2> /dev/null)" ||
        die 3 "${dir} is not in a git clone: FEEDBACK.md not written"
    [[ "$(cd "${top}" && pwd -P)/skills" == "${dir}" ]] ||
        die 3 "${dir} is not the skills/ folder of ${top}: FEEDBACK.md not written"
    echo "${dir}"
}

# metadata.version from the frontmatter of a SKILL.md, empty when absent.
skill_version() {
    awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { exit }
        fm && /^metadata:[[:space:]]*$/ { meta = 1; next }
        fm && meta && /^[[:space:]]+version:/ { sub(/^[[:space:]]+version:[[:space:]]*/, ""); gsub(/["'\'']/, ""); print; exit }
        fm && /^[^[:space:]]/ { meta = 0 }
    ' "$1"
}

# FEEDBACK.md is public: accept '-' or an https URL on an allowed host, nothing else.
check_link() {
    local link="$1" hosts="${FEEDBACK_LINK_HOSTS:-github.com gitlab.com}" host allowed
    [[ "${link}" != "-" ]] || return 0
    [[ "${link}" =~ ^https://([A-Za-z0-9.-]+)/[^[:space:]]+$ ]] ||
        die 1 "link must be '-' or an https URL of a PR/MR or commit: ${link}"
    host="$(tr '[:upper:]' '[:lower:]' <<< "${BASH_REMATCH[1]}")"
    # Split on spaces and commas.
    for allowed in ${hosts//,/ }; do
        [[ "${host}" != "$(tr '[:upper:]' '[:lower:]' <<< "${allowed}")" ]] || return 0
    done
    die 1 "link host '${host}' is not in FEEDBACK_LINK_HOSTS (${hosts})"
}

cmd_append() {
    [[ $# -eq 3 ]] || die 1 "append needs <skill> <what went wrong> <link>"
    local skill="$1" what="$2" link="$3" dir version file field line
    for field in "${skill}" "${what}" "${link}"; do
        [[ -n "${field}" ]] || die 1 "empty field"
        [[ "${field}" != *"|"* && "${field}" != *$'\n'* ]] || die 1 "a field holds '|' or a line break: ${field}"
    done
    check_link "${link}"
    dir="$(skills_dir)"
    [[ -f "${dir}/${skill}/SKILL.md" ]] || die 4 "no skill '${skill}' in ${dir}"
    version="$(skill_version "${dir}/${skill}/SKILL.md")"
    [[ -n "${version}" ]] || die 4 "${dir}/${skill}/SKILL.md has no metadata.version"
    file="${dir}/${skill}/FEEDBACK.md"
    [[ -f "${file}" ]] || echo "${HEADER}" > "${file}"
    line="$(date +%Y-%m-%d) | ${version} | ${what} | ${link}"
    echo "${line}" >> "${file}"
    echo "${file}: ${line}"
}

cmd_rework() {
    local min=3
    case "${1:-}" in
        "") ;;
        --min)
            [[ "${2:-}" =~ ^[1-9][0-9]*$ && $# -eq 2 ]] || die 1 "--min needs a positive integer"
            min="$2"
            ;;
        *) die 1 "unknown argument: $1" ;;
    esac
    local dir file skill version count
    dir="$(skills_dir)"
    for file in "${dir}"/*/FEEDBACK.md; do
        [[ -f "${file}" ]] || continue
        skill="$(basename "$(dirname "${file}")")"
        version="$(skill_version "${dir}/${skill}/SKILL.md")"
        [[ -n "${version}" ]] || die 4 "${dir}/${skill}/SKILL.md has no metadata.version"
        count="$(awk -F ' [|] ' -v v="${version}" '!/^#/ && $2 == v { n++ } END { print n + 0 }' "${file}")"
        [[ "${count}" -lt "${min}" ]] || printf '%s\t%s\t%s\n' "${skill}" "${version}" "${count}"
    done
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    append)
        shift
        cmd_append "$@"
        ;;
    rework)
        shift
        cmd_rework "$@"
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
