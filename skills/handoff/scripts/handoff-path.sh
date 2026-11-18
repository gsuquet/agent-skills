#!/usr/bin/env bash
# Print the path of a new handoff document, and create its directory.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: handoff-path.sh [-h|--help]

Prints the path where the handoff document goes, and creates its directory:
  1. $HANDOFF_DIR/<repo>-<yyyymmdd-hhmm>.md, when HANDOFF_DIR is set;
  2. <dir>/handoffs/<repo>-<yyyymmdd-hhmm>.md, where <dir> is the nearest ancestor of the git root
     (or of the current directory, itself included, outside a repository) that holds a CLAUDE.md
     or an AGENTS.md;
  3. ${TMPDIR:-/tmp}/handoff-<repo>-<yyyymmdd-hhmm>.md otherwise.
<repo> is the name of the git root folder, or of the current directory outside a repository.
EOF
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "") ;;
    *)
        usage >&2
        exit 1
        ;;
esac

stamp="$(date +%Y%m%d-%H%M)"

if root="$(git rev-parse --show-toplevel 2> /dev/null)"; then
    # Start above the repository: its own instruction files do not count.
    dir="$(dirname "${root}")"
else
    root="$(pwd -P)"
    dir="${root}"
fi
repo="$(basename "${root}")"
[[ "${repo}" != / ]] || repo=root

if [[ -n "${HANDOFF_DIR:-}" ]]; then
    mkdir -p "${HANDOFF_DIR}" || {
        echo "error: cannot create HANDOFF_DIR '${HANDOFF_DIR}'" >&2
        exit 1
    }
    echo "${HANDOFF_DIR%/}/${repo}-${stamp}.md"
    exit 0
fi

while :; do
    if [[ -f "${dir}/CLAUDE.md" || -f "${dir}/AGENTS.md" ]]; then
        mkdir -p "${dir}/handoffs" || {
            echo "error: cannot create '${dir}/handoffs'" >&2
            exit 1
        }
        echo "${dir%/}/handoffs/${repo}-${stamp}.md"
        exit 0
    fi
    [[ "${dir}" != / ]] || break
    dir="$(dirname "${dir}")"
done

tmp="${TMPDIR:-/tmp}"
echo "${tmp%/}/handoff-${repo}-${stamp}.md"
