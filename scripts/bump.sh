#!/usr/bin/env bash
# Raise the metadata.version of one skill from the Conventional Commits that changed it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="origin/main"

# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

usage() {
    cat << EOF
Usage: scripts/bump.sh <skill> [--dry-run]
       mise run bump -- <skill> [--dry-run]

Set the metadata.version of skills/<skill>/SKILL.md to the version on ${BASE_REF}, raised by the
highest level among the commits that changed skills/<skill>/ since the merge base of HEAD and
${BASE_REF}:

  major  a commit with "!" before the colon, or a "BREAKING CHANGE:" footer
  minor  feat(<skill>): ...
  patch  fix(<skill>): ..., any other commit, and uncommitted changes in skills/<skill>/

The result depends only on ${BASE_REF} and the branch, so running it again is safe: one branch
raises a skill's version once. Commit a feat or breaking change, then run it again: uncommitted
changes count only as a patch. A skill that has no version on ${BASE_REF} keeps its version.

Prints "<skill>: <old> -> <new> (<level>)" when it changes the version, then regenerates
.claude-plugin/marketplace.json (scripts/marketplace.sh), which carries the version.

Options:
  --dry-run  print the new version, do not edit SKILL.md
  -h, --help show this help

Exit codes:
  0  version raised, already right, or nothing to raise
  1  error: unknown skill, invalid version, no ${BASE_REF}
  2  usage error
EOF
}

skill=""
dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --dry-run) dry_run=true ;;
        -*)
            echo "unknown option: $1 (see --help)" >&2
            exit 2
            ;;
        *)
            [[ -z "${skill}" ]] || {
                echo "only one skill per run (see --help)" >&2
                exit 2
            }
            skill="$1"
            ;;
    esac
    shift
done
[[ -n "${skill}" ]] || {
    usage >&2
    exit 2
}

rel="skills/${skill}/SKILL.md"
file="${REPO_ROOT}/${rel}"
[[ -f "${file}" ]] || {
    echo "no skill '${skill}': ${rel} not found" >&2
    exit 1
}
current="$(skill_version "${file}")"
[[ "${current}" =~ ${SEMVER_RE} ]] || {
    echo "${rel}: metadata.version '${current}' is missing or not a semantic version" >&2
    exit 1
}
git -C "${REPO_ROOT}" rev-parse --verify --quiet "${BASE_REF}^{commit}" > /dev/null || {
    echo "no ${BASE_REF}: run 'git fetch origin main'" >&2
    exit 1
}
base_commit="$(git -C "${REPO_ROOT}" merge-base HEAD "${BASE_REF}")" || {
    echo "no merge base between HEAD and ${BASE_REF}: fetch the full history" >&2
    exit 1
}

base_version="$(git -C "${REPO_ROOT}" show "${BASE_REF}:${rel}" 2> /dev/null | skill_version - || true)"
if [[ -z "${base_version}" ]]; then
    echo "${skill}: no version on ${BASE_REF}, keeping ${current}"
    exit 0
fi
[[ "${base_version}" =~ ${SEMVER_RE} ]] || {
    echo "${rel} on ${BASE_REF}: metadata.version '${base_version}' is not a semantic version" >&2
    exit 1
}

# 0 none, 1 patch, 2 minor, 3 major.
level=0
re_breaking='^[a-zA-Z]+(\([^)]*\))?!:'
re_scoped='^([a-zA-Z]+)\(([^)]*)\):'
raise() { ((level >= $1)) || level=$1; }

while IFS= read -r -d '' message; do
    subject="${message%%$'\n'*}"
    if [[ "${subject}" =~ ${re_breaking} ]] ||
        grep -qE '^BREAKING[ -]CHANGE: ' <<< "${message}"; then
        raise 3
    elif [[ "${subject}" =~ ${re_scoped} ]] &&
        [[ "${BASH_REMATCH[1]}" == "feat" && ",${BASH_REMATCH[2]// /}," == *",${skill},"* ]]; then
        raise 2
    else
        raise 1
    fi
done < <(git -C "${REPO_ROOT}" log --no-merges -z --format='%B' "${base_commit}..HEAD" -- "skills/${skill}/")

if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain -- "skills/${skill}/")" ]]; then
    raise 1
fi

if ((level == 0)); then
    echo "${skill}: unchanged since ${BASE_REF}, keeping ${current}"
    exit 0
fi

IFS=. read -r major minor patch <<< "${base_version%%[-+]*}"
case "${level}" in
    3) target="$((major + 1)).0.0" name="major" ;;
    2) target="${major}.$((minor + 1)).0" name="minor" ;;
    1) target="${major}.${minor}.$((patch + 1))" name="patch" ;;
esac

if [[ "${current}" == "${target}" ]]; then
    echo "${skill}: already ${current} (${name} over ${BASE_REF} ${base_version})"
    exit 0
fi
if version_gt "${current}" "${target}"; then
    echo "${skill}: ${current} is already higher than ${target} (${name} over ${BASE_REF} ${base_version}), keeping it"
    exit 0
fi

if [[ "${dry_run}" == false ]]; then
    tmp="$(mktemp)"
    trap 'rm -f "${tmp}"' EXIT
    # Replace only the version line under metadata, inside the frontmatter.
    awk -v target="${target}" '
        NR > 1 && $0 == "---" { done = 1 }
        !done && /^[^[:space:]#]/ { in_metadata = ($0 ~ /^metadata:[[:space:]]*$/) }
        !done && in_metadata && /^[[:space:]]+version:/ {
            match($0, /^[[:space:]]+version:[[:space:]]*/)
            $0 = substr($0, 1, RLENGTH) target
            done = 1
        }
        { print }
    ' "${file}" > "${tmp}"
    cat "${tmp}" > "${file}"
    "${REPO_ROOT}/scripts/marketplace.sh"
fi
suffix=""
[[ "${dry_run}" == false ]] || suffix=", dry run: SKILL.md not changed"
echo "${skill}: ${current} -> ${target} (${name}${suffix})"
