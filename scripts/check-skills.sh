#!/usr/bin/env bash
# Check that every skill follows the Agent Skills format that all supported agents read.
# Also checks the links between skills, the skill versions, and the tracked files against a private
# word list, kept outside the repository.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORBIDDEN_WORDS="${AGENT_SKILLS_FORBIDDEN_WORDS:-${XDG_CONFIG_HOME:-${HOME}/.config}/agent-skills/forbidden-words}"
errors=0

fail() {
    echo "$1: $2" >&2
    errors=$((errors + 1))
}

# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

for dir in "${REPO_ROOT}"/skills/*/; do
    name="$(basename "${dir}")"
    file="${dir}SKILL.md"
    rel="skills/${name}/SKILL.md"

    [[ -f "${file}" ]] || {
        fail "skills/${name}" "missing SKILL.md"
        continue
    }
    [[ "${name}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && ${#name} -le 64 ]] ||
        fail "skills/${name}" "folder name must be kebab-case, 64 characters max"
    [[ "$(head -n 1 "${file}")" == "---" ]] || {
        fail "${rel}" "frontmatter must start on line 1"
        continue
    }

    frontmatter="$(awk 'NR > 1 && $0 == "---" { exit } NR > 1 { print }' "${file}")"
    fm_name="$(sed -n 's/^name:[[:space:]]*//p' <<< "${frontmatter}" | tr -d "\"'")"
    description="$(sed -n 's/^description:[[:space:]]*//p' <<< "${frontmatter}")"

    [[ "${fm_name}" == "${name}" ]] || fail "${rel}" "name must equal the folder name"
    [[ -n "${description}" && "${description}" != ">"* && "${description}" != "|"* ]] ||
        fail "${rel}" "description must be a non-empty single line"
    [[ ${#description} -le 1024 ]] || fail "${rel}" "description longer than 1024 characters"

    version="$(skill_version "${file}")"
    if [[ -z "${version}" ]]; then
        fail "${rel}" "metadata.version is required"
    elif ! [[ "${version}" =~ ${SEMVER_RE} ]]; then
        fail "${rel}" "metadata.version '${version}' is not a semantic version (MAJOR.MINOR.PATCH)"
    fi

    # install.sh installs linked skills: each link must name an existing skill.
    while IFS= read -r linked; do
        [[ -f "${REPO_ROOT}/skills/${linked}/SKILL.md" ]] ||
            fail "${rel}" "links to missing skill '${linked}' (../${linked}/SKILL.md)"
    done < <(grep -oE '\]\(\.\./[^/)]+/SKILL\.md\)' "${file}" | sed -E 's#^\]\(\.\./([^/)]+)/SKILL\.md\)$#\1#' | sort -u || true)
done

if [[ -f "${FORBIDDEN_WORDS}" ]]; then
    pattern="$(grep -v -e '^#' -e '^[[:space:]]*$' "${FORBIDDEN_WORDS}" | paste -sd '|' -)"
    if [[ -n "${pattern}" ]] && git -C "${REPO_ROOT}" grep -n -i -I -E "${pattern}" -- . > /dev/null; then
        # Print only the locations: the words themselves stay private.
        git -C "${REPO_ROOT}" grep -l -i -I -E "${pattern}" -- . | sed 's/^/forbidden word in: /' >&2
        errors=$((errors + 1))
    fi
else
    echo "notice: no ${FORBIDDEN_WORDS}, forbidden words not checked" >&2
fi

[[ ${errors} -eq 0 ]] || {
    echo "${errors} error(s)" >&2
    exit 1
}
