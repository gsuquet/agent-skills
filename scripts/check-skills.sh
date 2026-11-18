#!/usr/bin/env bash
# Check that every skill follows the Agent Skills format that all supported agents read.
# Also checks the links between skills, the skill versions, and the tracked files against a private
# word list, kept outside the repository.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="origin/main"
FORBIDDEN_WORDS="${AGENT_SKILLS_FORBIDDEN_WORDS:-${XDG_CONFIG_HOME:-${HOME}/.config}/agent-skills/forbidden-words}"
errors=0

fail() {
    echo "$1: $2" >&2
    errors=$((errors + 1))
}

# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

# A changed skill must carry a higher version than on BASE_REF. "changed" compares the working tree
# with the merge base, so commits that BASE_REF gained since the branch started do not count.
base_commit=""
if ! git -C "${REPO_ROOT}" rev-parse --verify --quiet "${BASE_REF}^{commit}" > /dev/null; then
    echo "notice: no ${BASE_REF}, skill version bumps not checked (fetch it, or clone with full history)" >&2
elif ! base_commit="$(git -C "${REPO_ROOT}" merge-base HEAD "${BASE_REF}" 2> /dev/null)"; then
    echo "notice: no merge base with ${BASE_REF}, skill version bumps not checked (shallow clone?)" >&2
    base_commit=""
fi
changed_skills=""
if [[ -n "${base_commit}" ]]; then
    changed_skills="$({
        git -C "${REPO_ROOT}" diff --name-only "${base_commit}" -- skills/
        git -C "${REPO_ROOT}" ls-files --others --exclude-standard -- skills/
    } | cut -d / -f 2 | sort -u)"
fi

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
    elif grep -qxF "${name}" <<< "${changed_skills}"; then
        # A skill that is new on the branch, or had no version on BASE_REF yet, is exempt.
        base_version="$(git -C "${REPO_ROOT}" show "${BASE_REF}:${rel}" 2> /dev/null | skill_version - || true)"
        if [[ -n "${base_version}" ]] && ! version_gt "${version}" "${base_version}"; then
            fail "${rel}" "skill changed since ${BASE_REF} but its version ${version} is not higher than ${base_version}: run 'mise run bump -- ${name}'"
        fi
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
