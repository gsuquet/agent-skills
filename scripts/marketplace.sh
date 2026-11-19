#!/usr/bin/env bash
# Generate .claude-plugin/marketplace.json from skills/: one plugin per skill, plus "all".
# Each single-skill plugin carries the skill's metadata.version, so Claude Code updates it only when
# that version changes. "all" has no version: Claude Code uses the commit SHA and updates it on every
# commit.
# With --check, fail when the committed file is not up to date.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPO_ROOT}/.claude-plugin/marketplace.json"

# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

entries="[]"
for dir in "${REPO_ROOT}"/skills/*/; do
    [[ -f "${dir}SKILL.md" ]] || continue
    name="$(basename "${dir}")"
    description="$(frontmatter "${dir}SKILL.md" description)"
    version="$(skill_version "${dir}SKILL.md")"
    [[ -n "${version}" ]] || {
        echo "skills/${name}/SKILL.md: missing metadata.version" >&2
        exit 1
    }
    entries="$(jq -c --arg n "${name}" --arg d "${description}" --arg v "${version}" \
        '. + [{name: $n, description: $d, version: $v}]' <<< "${entries}")"
done

generated="$(jq --indent 2 '{
  name: "gsuquet-skills",
  owner: {name: "Gabriel Suquet", url: "https://github.com/gsuquet"},
  description: "Agent skills: install all of them with the \"all\" plugin, or one plugin per skill.",
  plugins: (
    [{
      name: "all",
      source: "./",
      description: "Every skill of this repository. Do not combine with the single-skill plugins.",
      skills: map("./skills/" + .name)
    }]
    + map({name, source: "./", description, version, skills: ["./skills/" + .name]})
  )
}' <<< "${entries}")"

if [[ "${1:-}" == "--check" ]]; then
    if ! diff -u "${OUT}" <(echo "${generated}"); then
        echo "${OUT#"${REPO_ROOT}"/} is out of date: run 'mise run marketplace'" >&2
        exit 1
    fi
else
    echo "${generated}" > "${OUT}"
fi
