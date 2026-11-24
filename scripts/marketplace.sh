#!/usr/bin/env bash
# Generate the Claude Code plugin manifests from skills/:
#   .claude-plugin/marketplace.json         one plugin per skill, plus the bundle that installs them all
#   .claude-plugin/plugin.json              shared by the skill plugins: its name is their prefix, /gs:<skill>
#   plugins/gs/.claude-plugin/plugin.json   the bundle: no skill of its own, it depends on every skill plugin
# Each skill plugin carries the skill's metadata.version, so Claude Code updates it only when that
# version changes. The bundle's version carries a hash of the skill names, so it changes only when a
# skill is added, renamed or removed.
# With --check, fail when a committed file is not up to date.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="gs"

# shellcheck source=scripts/lib.sh
source "${REPO_ROOT}/scripts/lib.sh"

entries="[]"
for dir in "${REPO_ROOT}"/skills/*/; do
    [[ -f "${dir}SKILL.md" ]] || continue
    name="$(basename "${dir}")"
    [[ "${name}" != "${PREFIX}" ]] || {
        echo "skills/${name}: the name is taken by the bundle plugin" >&2
        exit 1
    }
    description="$(frontmatter "${dir}SKILL.md" description)"
    version="$(skill_version "${dir}SKILL.md")"
    [[ -n "${version}" ]] || {
        echo "skills/${name}/SKILL.md: missing metadata.version" >&2
        exit 1
    }
    entries="$(jq -c --arg n "${name}" --arg d "${description}" --arg v "${version}" \
        '. + [{name: $n, description: $d, version: $v}]' <<< "${entries}")"
done

# The bundle's source must hold no skills/ folder: Claude Code would load those skills at the bundle's
# version, next to the skill plugins.
marketplace="$(jq --indent 2 --arg prefix "${PREFIX}" '{
  name: "gsuquet",
  owner: {name: "Gabriel Suquet", url: "https://github.com/gsuquet"},
  description: "Agent skills: install all of them with the \"\($prefix)\" plugin, or one plugin per skill.",
  plugins: (
    [{
      name: $prefix,
      source: "./plugins/\($prefix)",
      description: "Every skill of this repository, each as a plugin with its own version."
    }]
    + map({name, source: "./", description, version, skills: ["./skills/" + .name]})
  )
}' <<< "${entries}")"

# No version here: it would override the version of every skill plugin in marketplace.json.
shared="$(jq -n --indent 2 --arg prefix "${PREFIX}" '{
  name: $prefix,
  description: "Agent skills, invoked as /\($prefix):<skill>.",
  author: {name: "Gabriel Suquet", url: "https://github.com/gsuquet"}
}')"

names_hash="$(jq -r 'map(.name) | sort[]' <<< "${entries}" | git hash-object --stdin | cut -c 1-8)"
bundle="$(jq --indent 2 --arg prefix "${PREFIX}" --arg hash "${names_hash}" '{
  name: $prefix,
  version: "1.0.0+\($hash)",
  description: "Every skill of this repository, each as a plugin with its own version.",
  author: {name: "Gabriel Suquet", url: "https://github.com/gsuquet"},
  dependencies: map(.name)
}' <<< "${entries}")"

stale=false
emit() {
    local rel="$1" content="$2"
    if [[ "${check}" == false ]]; then
        mkdir -p "$(dirname "${REPO_ROOT}/${rel}")"
        echo "${content}" > "${REPO_ROOT}/${rel}"
    elif ! diff -u "${REPO_ROOT}/${rel}" <(echo "${content}"); then
        echo "${rel} is out of date: run 'mise run marketplace'" >&2
        stale=true
    fi
}

check=false
[[ "${1:-}" != "--check" ]] || check=true
emit .claude-plugin/marketplace.json "${marketplace}"
emit .claude-plugin/plugin.json "${shared}"
emit "plugins/${PREFIX}/.claude-plugin/plugin.json" "${bundle}"
[[ "${stale}" == false ]]
