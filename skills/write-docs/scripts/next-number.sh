#!/usr/bin/env bash
# Print the path of the next RFC or ADR.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: next-number.sh <rfc|adr> <slug> [--root <dir>]

Prints the path of the next RFC or ADR, relative to the root, for example docs/rfc/0004-slug.md.
Creates nothing.

  rfc  goes in docs/rfc/.
  adr  goes in the first folder that exists among docs/adr/, docs/decisions/ and adr/, else
       docs/adr/.

The number is the highest leading number of the *.md files in that folder plus one, written with
4 digits. RFCs and ADRs are numbered independently.

Arguments:
  <slug>        kebab-case name: lowercase letters, digits and hyphens
  --root <dir>  folder that holds docs/ (default: the git root of the current directory, or the
                current directory outside a repository)
  -h, --help    show this help

Exit codes: 0 path printed, 2 usage error.
EOF
}

kind=""
slug=""
root=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --root)
            [[ $# -ge 2 ]] || {
                echo "error: --root needs a folder" >&2
                exit 2
            }
            root="$2"
            shift 2
            ;;
        -*)
            echo "error: unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -z "${kind}" ]]; then
                kind="$1"
            elif [[ -z "${slug}" ]]; then
                slug="$1"
            else
                echo "error: unexpected argument '$1'" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

[[ "${kind}" == rfc || "${kind}" == adr ]] || {
    echo "error: first argument must be rfc or adr, got '${kind}'" >&2
    usage >&2
    exit 2
}
[[ "${slug}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
    echo "error: slug must be kebab-case (a-z, 0-9, -), got '${slug}'" >&2
    exit 2
}
if [[ -z "${root}" ]]; then
    root="$(git rev-parse --show-toplevel 2> /dev/null || pwd -P)"
fi
[[ -d "${root}" ]] || {
    echo "error: root '${root}' is not a folder" >&2
    exit 2
}

folder=docs/rfc
if [[ "${kind}" == adr ]]; then
    folder=docs/adr
    for candidate in docs/adr docs/decisions adr; do
        if [[ -d "${root}/${candidate}" ]]; then
            folder="${candidate}"
            break
        fi
    done
fi

max=0
for file in "${root}/${folder}"/[0-9]*-*.md; do
    [[ -e "${file}" ]] || continue
    if [[ "$(basename "${file}")" =~ ^([0-9]+)- ]]; then
        number=$((10#${BASH_REMATCH[1]}))
        if [[ ${number} -gt ${max} ]]; then
            max=${number}
        fi
    fi
done

printf '%s/%04d-%s.md\n' "${folder}" $((max + 1)) "${slug}"
