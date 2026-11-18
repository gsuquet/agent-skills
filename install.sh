#!/usr/bin/env bash
# Install skills of this repository into the skills directory of one or more agents.
# Claude Code users can also install them as plugins, see README.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
MARKER=".installed-by-agent-skills"

usage() {
    cat << 'EOF'
Usage: install.sh [options] (--all | <skill>...)

Installing a skill also installs every skill it links to (a "](../<name>/SKILL.md)" link in its
SKILL.md), recursively. --uninstall removes only the skills named.

Options:
  -a, --agent AGENT  Target agent, repeatable (default: antigravity):
                       claude       ~/.claude/skills
                       antigravity  ~/.gemini/config/skills (Antigravity App, CLI and IDE)
                       <dir>        any other skills directory (path with a /)
      --all          Install every skill
  -c, --copy         Copy the skills instead of linking them
  -u, --uninstall    Remove the skills installed by this script
  -n, --dry-run      Print the actions, change nothing
  -l, --list         List the available skills
  -h, --help         Show this help
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

target_dir() {
    case "$1" in
        claude) echo "${HOME}/.claude/skills" ;;
        antigravity) echo "${HOME}/.gemini/config/skills" ;;
        */*) echo "${1/#\~/${HOME}}" ;;
        *) die "unknown agent '$1' (claude, antigravity or a directory)" ;;
    esac
}

list_skills() {
    local dir
    for dir in "${SKILLS_DIR}"/*/; do
        [[ -f "${dir}SKILL.md" ]] && basename "${dir}"
    done
}

# Names of the skills that a skill's SKILL.md links to, one per line.
linked_skills() {
    grep -oE '\]\(\.\./[a-z0-9-]+/SKILL\.md\)' "${SKILLS_DIR}/$1/SKILL.md" |
        sed -E 's#^\]\(\.\./([a-z0-9-]+)/SKILL\.md\)$#\1#' | sort -u || true
}

# Add the linked skills to SKILLS, recursively. Each skill appears once, so cycles end.
add_linked_skills() {
    local i=0 skill linked
    while [[ ${i} -lt ${#SKILLS[@]} ]]; do
        skill="${SKILLS[${i}]}"
        while IFS= read -r linked; do
            [[ -n "${linked}" ]] || continue
            [[ -f "${SKILLS_DIR}/${linked}/SKILL.md" ]] ||
                die "skill '${skill}' links to unknown skill '${linked}'"
            if ! printf '%s\n' "${SKILLS[@]}" | grep -qxF -- "${linked}"; then
                echo "adding ${linked}: linked from ${skill}" >&2
                SKILLS+=("${linked}")
            fi
        done < <(linked_skills "${skill}")
        i=$((i + 1))
    done
}

run() {
    if [[ "${DRY_RUN}" == true ]]; then
        echo "+ $*"
    else
        "$@"
    fi
}

# True when the path was installed by this script: a link into this repo, or a copy with the marker.
owned() {
    local path="$1" link
    if [[ -L "${path}" ]]; then
        link="$(readlink "${path}")"
        [[ "${link}" == "${SKILLS_DIR}/"* ]]
    else
        [[ -f "${path}/${MARKER}" ]]
    fi
}

install_skill() {
    local skill="$1" dest="$2/$1"
    if [[ -e "${dest}" || -L "${dest}" ]]; then
        if ! owned "${dest}"; then
            echo "skip ${dest}: exists and was not installed by this script" >&2
            return 0
        fi
        run rm -rf "${dest}"
    fi
    if [[ "${COPY}" == true ]]; then
        run cp -R "${SKILLS_DIR}/${skill}" "${dest}"
        run touch "${dest}/${MARKER}"
    else
        run ln -s "${SKILLS_DIR}/${skill}" "${dest}"
    fi
    if [[ "${DRY_RUN}" != true ]]; then echo "installed ${skill} -> ${dest}"; fi
}

uninstall_skill() {
    local dest="$2/$1"
    if [[ ! -e "${dest}" && ! -L "${dest}" ]]; then
        return 0
    fi
    if ! owned "${dest}"; then
        echo "skip ${dest}: not installed by this script" >&2
        return 0
    fi
    run rm -rf "${dest}"
    if [[ "${DRY_RUN}" != true ]]; then echo "removed ${dest}"; fi
}

AGENTS=()
SKILLS=()
ALL=false COPY=false UNINSTALL=false DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a | --agent)
            [[ $# -ge 2 ]] || die "$1 needs a value"
            AGENTS+=("$2")
            shift
            ;;
        --all) ALL=true ;;
        -c | --copy) COPY=true ;;
        -u | --uninstall) UNINSTALL=true ;;
        -n | --dry-run) DRY_RUN=true ;;
        -l | --list)
            list_skills
            exit 0
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*) die "unknown option $1" ;;
        *) SKILLS+=("$1") ;;
    esac
    shift
done

[[ ${#AGENTS[@]} -gt 0 ]] || AGENTS=(antigravity)

if [[ "${ALL}" == true ]]; then
    [[ ${#SKILLS[@]} -eq 0 ]] || die "--all and skill names are exclusive"
    while IFS= read -r skill; do SKILLS+=("${skill}"); done < <(list_skills)
fi
[[ ${#SKILLS[@]} -gt 0 ]] || {
    usage >&2
    exit 1
}

for skill in "${SKILLS[@]}"; do
    [[ -f "${SKILLS_DIR}/${skill}/SKILL.md" ]] || die "unknown skill '${skill}' (see --list)"
done

[[ "${UNINSTALL}" == true ]] || add_linked_skills

for agent in "${AGENTS[@]}"; do
    dir="$(target_dir "${agent}")"
    [[ "${UNINSTALL}" == true ]] || run mkdir -p "${dir}"
    for skill in "${SKILLS[@]}"; do
        if [[ "${UNINSTALL}" == true ]]; then
            uninstall_skill "${skill}" "${dir}"
        else
            install_skill "${skill}" "${dir}"
        fi
    done
done
