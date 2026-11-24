#!/usr/bin/env bash
# Print (never run) the gh or glab command that creates or updates the PR/MR of the current branch,
# for the forge of the "origin" remote of the current repository.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage:
  forge.sh create --title <title> [--base <branch>] [--draft] <body-file>
  forge.sh update [--title <title>] [--number <n>] <body-file>
  forge.sh -h | --help

Detects the forge from `git remote get-url origin`:
  github.com                          -> gh pr create / gh pr edit
  a host containing "gitlab",
  or equal to $GITLAB_HOST            -> glab mr create / glab mr update
  anything else                       -> error

Prints the command on stdout and runs nothing. Without --number, update targets the PR/MR of the
current branch.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

# BEGIN shared:forge-detect
# Host part of a git remote URL: git@host:path, ssh://user@host[:port]/path or https://host/path.
remote_host() {
    local url="$1" host
    case "${url}" in
        *://*)
            host="${url#*://}"
            host="${host#*@}"
            host="${host%%/*}"
            host="${host%%:*}"
            ;;
        *@*:*)
            host="${url#*@}"
            host="${host%%:*}"
            ;;
        *) return 1 ;;
    esac
    [[ -n "${host}" ]] && echo "${host}"
}

# Forge of a host: github for github.com, gitlab for a host containing "gitlab" or equal to
# $GITLAB_HOST. Returns 1 for any other host.
forge_of_host() {
    if [[ "$1" == github.com ]]; then
        echo github
    elif [[ "$1" == *gitlab* || "$1" == "${GITLAB_HOST:-}" ]]; then
        echo gitlab
    else
        return 1
    fi
}
# END shared:forge-detect

[[ $# -gt 0 ]] || {
    usage >&2
    exit 1
}

action="$1"
shift
case "${action}" in
    -h | --help)
        usage
        exit 0
        ;;
    create | update) ;;
    *) die "unknown action '${action}' (create or update, see --help)" ;;
esac

title="" base="" number="" body="" draft=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t | --title | -b | --base | -n | --number)
            [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value"
            case "$1" in
                -t | --title) title="$2" ;;
                -b | --base) base="$2" ;;
                *) number="$2" ;;
            esac
            shift
            ;;
        -d | --draft) draft=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*) die "unknown option $1" ;;
        *)
            [[ -z "${body}" ]] || die "only one body file expected, got '${body}' and '$1'"
            body="$1"
            ;;
    esac
    shift
done

[[ -n "${body}" ]] || die "missing <body-file> (see --help)"
[[ -f "${body}" ]] || die "body file '${body}' not found"
[[ -s "${body}" ]] || die "body file '${body}' is empty"
body="$(cd "$(dirname "${body}")" && pwd)/$(basename "${body}")"
[[ "${action}" != create || -n "${title}" ]] || die "create needs --title"
[[ "${action}" != create || -z "${number}" ]] || die "--number is only valid with update"
[[ "${action}" != update || -z "${base}" ]] || die "--base is only valid with create"
[[ "${action}" != update || "${draft}" == false ]] || die "--draft is only valid with create"
[[ -z "${number}" || "${number}" =~ ^[0-9]+$ ]] || die "--number must be a number, got '${number}'"

url="$(git remote get-url origin 2> /dev/null)" || die "no 'origin' remote in $(pwd)"
host="$(remote_host "${url}")" || die "cannot read the host of origin '${url}'"

forge="$(forge_of_host "${host}")" ||
    die "unknown forge '${host}': expected github.com or a GitLab host (set GITLAB_HOST=${host} for a GitLab host without 'gitlab' in its name)"

cmd=()
case "${forge}/${action}" in
    github/create)
        cmd=(gh pr create --title "${title}" --body-file "${body}")
        [[ -z "${base}" ]] || cmd+=(--base "${base}")
        [[ "${draft}" == false ]] || cmd+=(--draft)
        ;;
    github/update)
        cmd=(gh pr edit)
        [[ -z "${number}" ]] || cmd+=("${number}")
        [[ -z "${title}" ]] || cmd+=(--title "${title}")
        cmd+=(--body-file "${body}")
        ;;
    gitlab/create)
        cmd=(glab mr create --title "${title}" --description-file "${body}" --yes)
        [[ -z "${base}" ]] || cmd+=(--target-branch "${base}")
        [[ "${draft}" == false ]] || cmd+=(--draft)
        ;;
    gitlab/update)
        cmd=(glab mr update)
        [[ -z "${number}" ]] || cmd+=("${number}")
        [[ -z "${title}" ]] || cmd+=(--title "${title}")
        cmd+=(--description-file "${body}")
        ;;
esac

# Quote each word so that the printed line can be pasted into a shell as is.
printf '%q ' "${cmd[@]}" | sed 's/ $//'
echo
