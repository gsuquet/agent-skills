#!/usr/bin/env bash
# Generate .claude-plugin/marketplace.json from skills/: one plugin per skill, plus "all".
# With --check, fail when the committed file is not up to date.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPO_ROOT}/.claude-plugin/marketplace.json"

# Value of a single-line frontmatter key, quotes removed (scripts/check-skills.sh enforces the format).
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

entries="[]"
for dir in "${REPO_ROOT}"/skills/*/; do
    [[ -f "${dir}SKILL.md" ]] || continue
    name="$(basename "${dir}")"
    description="$(frontmatter "${dir}SKILL.md" description)"
    entries="$(jq -c --arg n "${name}" --arg d "${description}" '. + [{name: $n, description: $d}]' <<< "${entries}")"
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
    + map({name, source: "./", description, skills: ["./skills/" + .name]})
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
