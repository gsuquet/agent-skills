#!/usr/bin/env bash
# Publish the spec and ticket drafts of one folder to GitHub, GitLab or Jira, blockers first.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage:
  publish-tickets.sh [--tracker github|gitlab|jira] [--project <KEY>] [--label <name>]...
                     [--config <file.json>] [--max <n>] [--dry-run] <draft-dir>
  publish-tickets.sh -h | --help

Run it from the repository the issues belong to. Publishes the drafts of <draft-dir>:
  spec.md         the parent issue, first (optional)
  NN-<slug>.md    one issue per ticket, in number order
and appends each published draft to <draft-dir>/map.tsv (draft, issue id, URL). A draft already in
map.tsv is skipped, so a re-run continues where a failed run stopped.

Draft format: the first line is "# <title>". A ticket holds exactly one "Blocked by: 01, 03" or
"Blocked by: None" line ("none" also works), and each blocker has a smaller number than the ticket. The line is
rewritten with the issue references before publishing; the files are never changed.

Tracker, first match wins:
  1. --tracker (jira also needs --project <KEY>, or a jira line in AGENTS.md);
  2. a line "Tracker: github", "Tracker: gitlab" or "Tracker: jira <KEY>" in the AGENTS.md of the
     repository root;
  3. the host of `git remote get-url origin`: github.com -> github; a host containing "gitlab", or
     equal to $GITLAB_HOST -> gitlab.

Per tracker:
  github  gh issue create. Tickets get --parent <spec> and --blocked-by <blockers>.
          Once every ticket is published, each body that names "ticket NN" is rewritten with
          #<id> of NN through gh issue edit --body-file (map.tsv row "refs-NN").
  gitlab  glab issue create. Tickets get --linked-issues <spec> --link-type relates_to. Each
          blocker gets an is_blocked_by link through `glab api`; when GitLab refuses it, the
          script warns and continues (the "Blocked by:" line stays). The spec description gets a
          task list "- [ ] #<iid>" of the tickets. "ticket NN" is rewritten as on github,
          through glab issue update --description-file.
  jira    acli jira workitem create --from-json, built by jira-payload.py (needs python3): the
          body is converted to Atlassian Document Format. The spec is an Epic, tickets are Tasks
          with the epic as parent. Each blocker gets a "Blocks" link; on failure the script warns
          and continues. Once every ticket is published, each description that names "ticket NN"
          is rewritten with the key of NN (map.tsv row "refs-NN"), linked to <site>/browse/KEY
          when the config sets "site".

Options:
  --tracker <name>  github, gitlab or jira.
  --project <KEY>   Jira project key.
  --label <name>    Add this label to every ticket, not to the spec. Repeat for more labels. On
                    GitHub and GitLab the label must exist.
  --config <file>   Jira only: project rules in JSON (issue types, custom fields, epic link, label
                    rules, lines to drop, extra links, an epic without spec.md). See
                    references/trackers.md.
  --max <n>         Publish at most <n> new tickets, then stop (the spec does not count). Use
                    --max 1 as a canary: check the first ticket on the tracker, then re-run.
  --dry-run         Print every command and run none. Rendered bodies are kept in a temporary
                    folder, printed at the end. map.tsv is not written.

Exit codes:
  0  published, or printed with --dry-run
  1  bad usage or invalid drafts
  2  no tracker found: ask the user which tracker to use
  3  missing command (gh, glab, acli, jq) or missing label
  4  a tracker command failed: map.tsv lists what was published; fix the cause and re-run
EOF
}

die() {
    local code="$1"
    shift
    echo "error: $*" >&2
    exit "${code}"
}

warn() {
    echo "warning: $*" >&2
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

tracker="" project="" config="" max="" dry_run=false dir=""
labels=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tracker | --project | --label | --config | --max)
            [[ $# -ge 2 && -n "$2" ]] || die 1 "$1 needs a value"
            case "$1" in
                --tracker) tracker="$2" ;;
                --project) project="$2" ;;
                --config) config="$2" ;;
                --max) max="$2" ;;
                *) labels+=("$2") ;;
            esac
            shift
            ;;
        --dry-run) dry_run=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*) die 1 "unknown option $1 (see --help)" ;;
        *)
            [[ -z "${dir}" ]] || die 1 "only one <draft-dir> expected, got '${dir}' and '$1'"
            dir="$1"
            ;;
    esac
    shift
done

[[ -n "${dir}" ]] || die 1 "missing <draft-dir> (see --help)"
[[ -d "${dir}" ]] || die 1 "draft folder '${dir}' not found"
dir="$(cd "${dir}" && pwd)"
map="${dir}/map.tsv"
[[ -z "${max}" || "${max}" =~ ^[1-9][0-9]*$ ]] || die 1 "--max needs a positive number"
if [[ -n "${config}" ]]; then
    [[ -f "${config}" ]] || die 1 "config '${config}' not found"
    config="$(cd "$(dirname "${config}")" && pwd)/$(basename "${config}")"
fi

# --- Tracker ------------------------------------------------------------------------------------

# Sets tracker (and project for jira) from the "Tracker:" line of AGENTS.md. Returns 1 without one.
tracker_from_agents() {
    local root line value
    root="$(git rev-parse --show-toplevel 2> /dev/null)" || return 1
    [[ -f "${root}/AGENTS.md" ]] || return 1
    line="$(grep -m 1 -E '^Tracker:' "${root}/AGENTS.md" || true)"
    [[ -n "${line}" ]] || return 1
    value="$(sed -E 's/^Tracker:[[:space:]]*//; s/[[:space:]]+$//' <<< "${line}")"
    case "${value}" in
        github | gitlab) agents_tracker="${value}" agents_project="" ;;
        "jira "*)
            agents_tracker=jira
            agents_project="$(sed -E 's/^jira[[:space:]]+//' <<< "${value}")"
            ;;
        *) die 1 "${root}/AGENTS.md: '${line}' must be 'Tracker: github', 'Tracker: gitlab' or 'Tracker: jira <KEY>'" ;;
    esac
}

agents_tracker="" agents_project=""
# AGENTS.md is read only when the flags leave the tracker or the Jira project open.
if [[ -z "${tracker}" || ("${tracker}" == jira && -z "${project}") ]]; then
    tracker_from_agents || true
fi

if [[ -z "${tracker}" && -n "${agents_tracker}" ]]; then
    tracker="${agents_tracker}"
    project="${project:-${agents_project}}"
fi
if [[ -z "${tracker}" ]]; then
    if url="$(git remote get-url origin 2> /dev/null)" && host="$(remote_host "${url}")"; then
        tracker="$(forge_of_host "${host}")" || tracker=""
    fi
fi
[[ -n "${tracker}" ]] || die 2 "no tracker found: no --tracker, no 'Tracker:' line in AGENTS.md, and origin is not github.com or a GitLab host. Ask the user which tracker to use."

case "${tracker}" in
    github | gitlab)
        [[ -z "${project}" ]] || die 1 "--project is only valid with jira"
        [[ -z "${config}" ]] || die 1 "--config is only valid with jira"
        ;;
    jira)
        [[ -z "${project}" && "${agents_tracker}" == jira ]] && project="${agents_project}"
        [[ -n "${project}" ]] || die 1 "jira needs a project key: --project <KEY> or 'Tracker: jira <KEY>' in AGENTS.md"
        [[ "${project}" =~ ^[A-Z][A-Z0-9_]+$ ]] || die 1 "Jira project key '${project}' must match [A-Z][A-Z0-9_]+"
        ;;
    *) die 1 "unknown tracker '${tracker}': github, gitlab or jira" ;;
esac

case "${tracker}" in
    github) needed=(gh python3) ;;
    gitlab) needed=(glab jq python3) ;;
    jira) needed=(acli jq python3) ;;
esac
for cmd in "${needed[@]}"; do
    if ! command -v "${cmd}" > /dev/null; then
        [[ "${cmd}" != acli ]] || die 3 "acli not found: install the Atlassian CLI (https://developer.atlassian.com/cloud/acli/) and run 'acli jira auth login', or publish to another tracker"
        die 3 "${cmd} not found in PATH"
    fi
done

# --- Drafts -------------------------------------------------------------------------------------

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Value of a config key (jq path), empty when there is no config or no such key.
cfg() {
    [[ -n "${config}" ]] || return 0
    jq -r "$1 // empty" "${config}" || die 1 "cannot read $1 from ${config}"
}
title_prefix="$(cfg .titlePrefix)" ignore="$(cfg .ignore)" blocks_type="$(cfg .blocksLinkType)"
blocks_type="${blocks_type:-Blocks}"
site="$(cfg .site)"
site="${site%/}"

title_of() {
    local first
    first="$(head -n 1 "$1")"
    [[ "${first}" =~ ^#\ +[^[:space:]] ]] || die 1 "$1: the first line must be '# <title>'"
    first="$(sed -E 's/^#[[:space:]]+//; s/[[:space:]]+$//' <<< "${first}")"
    [[ -z "${title_prefix}" ]] || first="$(jq -rn --arg t "${first}" --arg p "${title_prefix}" '$t | sub($p; "")')"
    echo "${first}"
}

has_spec=false spec_title=""
if [[ -f "${dir}/spec.md" ]]; then
    has_spec=true
    spec_title="$(title_of "${dir}/spec.md")"
fi

# A Jira config can name the parent instead of spec.md: an existing epic (key) or a new one.
epic_key="" epic_file=""
if [[ -n "${config}" ]] && jq -e '.epic' "${config}" > /dev/null; then
    [[ "${has_spec}" == false ]] || die 1 "${dir}/spec.md and the epic of ${config} both name the parent: keep one"
    has_spec=true
    epic_key="$(cfg .epic.key)"
    if [[ -n "${epic_key}" ]]; then
        [[ "${epic_key}" =~ ^[A-Z][A-Z0-9_]+-[0-9]+$ ]] || die 1 "${config}: epic.key '${epic_key}' is not a Jira key"
        spec_title="${epic_key}"
    else
        spec_title="$(cfg .epic.summary)"
        [[ -n "${spec_title}" ]] || die 1 "${config}: the epic needs a 'key' or a 'summary'"
        epic_file="$(cfg .epic.descriptionFile)"
        if [[ -n "${epic_file}" ]]; then
            epic_file="$(dirname "${config}")/${epic_file}"
            [[ -f "${epic_file}" ]] || die 1 "${config}: epic.descriptionFile '${epic_file}' not found"
        fi
    fi
fi

t_num=() t_file=() t_title=() t_block=()
for file in "${dir}"/*.md; do
    [[ -e "${file}" ]] || continue
    name="$(basename "${file}")"
    [[ "${name}" != spec.md ]] || continue
    if [[ -n "${ignore}" ]] && jq -en --arg n "${name}" --arg p "${ignore}" '$n | test($p)' > /dev/null; then
        continue
    fi
    [[ "${name}" =~ ^([0-9]{2})-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] ||
        die 1 "${file}: draft names are spec.md or NN-<kebab-slug>.md"
    num="${BASH_REMATCH[1]}"
    [[ ${#t_num[@]} -eq 0 || "${t_num[${#t_num[@]} - 1]}" != "${num}" ]] ||
        die 1 "two drafts numbered ${num} in ${dir}"

    lines="$(grep -c -E '^Blocked by:' "${file}" || true)"
    [[ "${lines}" -eq 1 ]] || die 1 "${file}: needs exactly one 'Blocked by:' line, found ${lines}"
    value="$(sed -nE 's/^Blocked by:[[:space:]]*//p' "${file}" | sed -E 's/[[:space:]]+$//')"
    blockers=""
    if [[ "${value}" != None && "${value}" != none ]]; then
        for b in $(tr ',' ' ' <<< "${value}"); do
            [[ "${b}" =~ ^[0-9]{1,2}$ ]] || die 1 "${file}: blocker '${b}' is not a draft number (Blocked by: 01, 03 or None)"
            b="$(printf '%02d' "$((10#${b}))")"
            [[ "$((10#${b}))" -lt "$((10#${num}))" ]] ||
                die 1 "${file}: blocker ${b} must have a smaller number than ${num} (number drafts in dependency order)"
            found=false
            for n in ${t_num[@]+"${t_num[@]}"}; do [[ "${n}" != "${b}" ]] || found=true; done
            [[ "${found}" == true ]] || die 1 "${file}: blocker ${b} has no draft"
            blockers="${blockers:+${blockers} }${b}"
        done
    fi

    t_num+=("${num}")
    t_file+=("${file}")
    t_title+=("$(title_of "${file}")")
    t_block+=("${blockers}")
done
[[ ${#t_num[@]} -gt 0 ]] || die 1 "no NN-<slug>.md ticket draft in ${dir}"

# --- Map ----------------------------------------------------------------------------------------

map_get() {
    [[ -f "${map}" ]] || return 0
    awk -F '\t' -v k="$1" '$1 == k { print $2; exit }' "${map}"
}

# URL of a Jira key: <site>/browse/<key>, or nothing without "site" in the config.
jira_url() {
    [[ -z "${site}" ]] || echo "${site}/browse/$1"
}

# Issue id of a draft: from map.tsv, or the placeholder @<draft> in a dry run.
ref_id() {
    local id
    id="$(map_get "$1")"
    [[ -n "${id}" || "$1" != spec ]] || id="${epic_key}"
    if [[ -z "${id}" ]]; then
        [[ "${dry_run}" == true ]] || die 4 "draft $1 is not in ${map}"
        id="@$1"
    fi
    echo "${id}"
}

# Reference written in issue bodies: #<n> on GitHub and GitLab, the key on Jira.
ref_text() {
    local id
    id="$(ref_id "$1")"
    [[ "${tracker}" == jira || "${id}" == @* ]] && echo "${id}" || echo "#${id}"
}

map_put() {
    [[ "${dry_run}" == false ]] || return 0
    local tmp="${map}.tmp"
    if [[ -f "${map}" ]]; then
        awk -F '\t' -v k="$1" '$1 != k' "${map}" > "${tmp}"
    else
        : > "${tmp}"
    fi
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "${tmp}"
    mv "${tmp}" "${map}"
}

recorded="$(map_get tracker)"
if [[ -n "${recorded}" && "${recorded}" != "${tracker}" ]]; then
    die 1 "${map} was published to ${recorded}, not ${tracker}: use --tracker ${recorded}, or move map.tsv away to publish again"
fi

# --- Commands -----------------------------------------------------------------------------------

tmp="${TMPDIR:-/tmp}"
work="$(mktemp -d "${tmp%/}/publish-tickets.XXXXXX")"
[[ "${dry_run}" == true ]] || trap 'rm -rf "${work}"' EXIT

print_cmd() {
    printf '%q ' "$@" | sed 's/ $//'
    echo
}

# Body of a draft without its title line, with the "Blocked by:" line rewritten to $2.
render() {
    awk -v repl="$2" '
        NR == 1 { next }
        !started && /^[[:space:]]*$/ { next }
        { started = 1 }
        /^Blocked by:/ && repl != "" { print "Blocked by: " repl; next }
        { print }
    ' "$1" > "$3"
}

# Runs a command that creates an issue, then records "<draft> <id> <url>" in map.tsv. When the
# command fails after printing the new issue (a refused link), records it and warns.
create() {
    local key="$1" out status=0 url="" id=""
    shift
    print_cmd "$@"
    [[ "${dry_run}" == false ]] || return 0
    if [[ "${tracker}" == jira ]]; then
        out="$("$@")" || status=$?
        id="$(jq -r '.key // empty' <<< "${out}" 2> /dev/null || true)"
        [[ -z "${id}" ]] || url="$(jira_url "${id}")"
    else
        out="$("$@" 2>&1)" || status=$?
        url="$(grep -Eo 'https?://[^[:space:]]+/issues/[0-9]+' <<< "${out}" | tail -n 1 || true)"
        id="${url##*/}"
    fi
    if [[ -z "${id}" ]]; then
        [[ ${status} -ne 0 ]] ||
            die 4 "draft ${key} may be published, but its id is not in the output: check the tracker, add '${key}<TAB><id><TAB><url>' to ${map}, then re-run. Output: ${out}"
        die 4 "publishing draft ${key} failed (map.tsv lists what was published; fix the cause and re-run): ${out}"
    fi
    map_put "${key}" "${id}" "${url:--}"
    echo "  -> ${key}: ${id} ${url}"
    [[ ${status} -eq 0 ]] ||
        warn "draft ${key} was published as ${id}, but the command failed after it: ${out}"
}

# Runs a command whose failure is a warning only (native links the tier may refuse).
try() {
    print_cmd "$@"
    [[ "${dry_run}" == false ]] || return 0
    "$@" > /dev/null || warn "$1 refused the link above: the 'Blocked by:' line in the body still records it"
}

# Numeric id of the GitLab project, read once: the issue links API needs it.
gitlab_project_id=""
load_project_id() {
    if [[ "${dry_run}" == true ]]; then
        gitlab_project_id="@project-id"
    else
        gitlab_project_id="$(glab api 'projects/:id' | jq -r '.id')" ||
            die 4 "cannot read the GitLab project id with 'glab api projects/:id'"
    fi
}

# Writes the acli --from-json payload of one draft to $1, then prints its type, summary and labels.
jira_payload() {
    local out="$1"
    shift
    [[ -z "${config}" ]] || set -- "$@" --config "${config}"
    python3 "${script_dir}/jira-payload.py" payload --project "${project}" "$@" > "${out}" ||
        die 1 "jira-payload.py could not build ${out}"
    jq -r '"  = " + .type + " | " + .summary + " | " + (.labels | join(","))' "${out}"
}

# "Blocked by:" text of ticket index $1: the blocker references, comma-separated, or None.
blocked_refs() {
    local b refs=""
    for b in ${t_block[$1]}; do refs="${refs:+${refs}, }$(ref_text "${b}")"; done
    echo "${refs:-None}"
}

# --- Labels -------------------------------------------------------------------------------------

check_labels() {
    [[ ${#labels[@]} -gt 0 ]] || return 0
    local existing="" page=1 chunk label
    case "${tracker}" in
        github)
            print_cmd gh label list --limit 1000 --json name --jq '.[].name'
            [[ "${dry_run}" == false ]] || return 0
            existing="$(gh label list --limit 1000 --json name --jq '.[].name')" || die 4 "gh label list failed"
            ;;
        gitlab)
            print_cmd glab label list --output json --per-page 100 --page 1
            [[ "${dry_run}" == false ]] || return 0
            while :; do
                chunk="$(glab label list --output json --per-page 100 --page "${page}" | jq -r '.[].name')" ||
                    die 4 "glab label list failed"
                [[ -n "${chunk}" ]] || break
                existing="${existing}${chunk}"$'\n'
                page=$((page + 1))
            done
            ;;
        jira) return 0 ;; # Jira creates a label on first use (unverified).
    esac
    for label in "${labels[@]}"; do
        grep -Fxq -- "${label}" <<< "${existing}" || die 3 "label '${label}' does not exist on ${tracker}: create it, or drop --label ${label}"
    done
}

# --- Publish ------------------------------------------------------------------------------------

check_labels
[[ -n "${recorded}" ]] || map_put tracker "${tracker}" "${project:--}"

if [[ "${has_spec}" == true ]]; then
    if [[ -n "$(map_get spec)" ]]; then
        echo "skip spec: already $(ref_text spec)"
    elif [[ -n "${epic_key}" ]]; then
        echo "spec: existing epic ${epic_key}"
        url="$(jira_url "${epic_key}")"
        map_put spec "${epic_key}" "${url:--}"
    else
        body="${work}/spec.md"
        if [[ -n "${epic_file}" ]]; then
            cp "${epic_file}" "${body}"
        elif [[ -f "${dir}/spec.md" ]]; then
            render "${dir}/spec.md" "" "${body}"
        else
            : > "${body}"
        fi
        case "${tracker}" in
            github) create spec gh issue create --title "${spec_title}" --body-file "${body}" ;;
            gitlab) create spec glab issue create --title "${spec_title}" --description-file "${body}" --yes ;;
            jira)
                jira_payload "${work}/spec.json" --kind spec --title "${spec_title}" --body "${body}"
                create spec acli jira workitem create --from-json "${work}/spec.json" --json
                ;;
        esac
    fi
fi

created=0 stopped=false
for i in "${!t_num[@]}"; do
    num="${t_num[${i}]}"
    if [[ -n "$(map_get "${num}")" ]]; then
        echo "skip ${num}: already $(ref_text "${num}")"
        continue
    fi
    if [[ -n "${max}" && ${created} -ge ${max} ]]; then
        stopped=true
        break
    fi
    created=$((created + 1))

    ids=""
    for b in ${t_block[${i}]}; do ids="${ids:+${ids},}$(ref_id "${b}")"; done
    body="${work}/$(basename "${t_file[${i}]}")"
    render "${t_file[${i}]}" "$(blocked_refs "${i}")" "${body}"

    cmd=()
    case "${tracker}" in
        github)
            cmd=(gh issue create --title "${t_title[${i}]}" --body-file "${body}")
            [[ "${has_spec}" == false ]] || cmd+=(--parent "$(ref_id spec)")
            [[ -z "${ids}" ]] || cmd+=(--blocked-by "${ids}")
            for label in ${labels[@]+"${labels[@]}"}; do cmd+=(--label "${label}"); done
            ;;
        gitlab)
            cmd=(glab issue create --title "${t_title[${i}]}" --description-file "${body}" --yes)
            [[ "${has_spec}" == false ]] || cmd+=(--linked-issues "$(ref_id spec)" --link-type relates_to)
            for label in ${labels[@]+"${labels[@]}"}; do cmd+=(--label "${label}"); done
            ;;
        jira)
            args=(--kind ticket --title "${t_title[${i}]}" --body "${body}")
            [[ "${has_spec}" == false ]] || args+=(--parent "$(ref_id spec)")
            for label in ${labels[@]+"${labels[@]}"}; do args+=(--label "${label}"); done
            jira_payload "${work}/${num}.json" "${args[@]}"
            cmd=(acli jira workitem create --from-json "${work}/${num}.json" --json)
            ;;
    esac
    create "${num}" "${cmd[@]}"

    for b in ${t_block[${i}]}; do
        case "${tracker}" in
            gitlab)
                [[ -n "${gitlab_project_id}" ]] || load_project_id
                try glab api --method POST "projects/:id/issues/$(ref_id "${num}")/links" \
                    -F "target_project_id=${gitlab_project_id}" -F "target_issue_iid=$(ref_id "${b}")" \
                    -f link_type=is_blocked_by
                ;;
            jira)
                try acli jira workitem link create --out "$(ref_id "${b}")" --in "$(ref_id "${num}")" \
                    --type "${blocks_type}" --yes
                ;;
        esac
    done

    # Extra links of the config, for example "relates to" an issue outside the drafts.
    [[ -n "${config}" ]] || continue
    while IFS=$'\t' read -r direction other kind; do
        if [[ "${direction}" == in ]]; then
            try acli jira workitem link create --out "${other}" --in "$(ref_id "${num}")" --type "${kind}" --yes
        else
            try acli jira workitem link create --out "$(ref_id "${num}")" --in "${other}" --type "${kind}" --yes
        fi
    done < <(jq -r --arg n "${num}" '.links[]? | select((.ticket | tostring | tonumber) == ($n | tonumber))
        | [.direction // "out", .key, .type] | @tsv' "${config}")
done
[[ "${stopped}" == false ]] || echo "Stopped after --max ${max} new tickets: re-run to publish the rest."

# Once every ticket has an id, "ticket NN" in a body becomes the reference of NN: the Jira key,
# or #<id> on GitHub and GitLab. Map row "refs-NN" records a rewritten ticket. A body that names no
# ticket is left alone.
if [[ "${stopped}" == false ]]; then
    for i in "${!t_num[@]}"; do
        num="${t_num[${i}]}"
        [[ -z "$(map_get "refs-${num}")" ]] || continue
        body="${work}/${num}.refs.md"
        out="${work}/${num}.refs.out"
        render "${t_file[${i}]}" "$(blocked_refs "${i}")" "${body}"
        args=(refs --body "${body}" --map "${map}")
        [[ "${tracker}" == jira ]] || args+=(--format markdown)
        [[ -z "${config}" ]] || args+=(--config "${config}")
        [[ "${dry_run}" == false ]] || args+=(--placeholder)
        python3 "${script_dir}/jira-payload.py" "${args[@]}" > "${out}" ||
            die 1 "jira-payload.py could not rewrite the ticket references of ${num}"
        [[ -s "${out}" ]] || continue
        case "${tracker}" in
            github) cmd=(gh issue edit "$(ref_id "${num}")" --body-file "${out}") ;;
            gitlab) cmd=(glab issue update "$(ref_id "${num}")" --description-file "${out}") ;;
            jira) cmd=(acli jira workitem edit --key "$(ref_id "${num}")" --description-file "${out}" --yes) ;;
        esac
        print_cmd "${cmd[@]}"
        [[ "${dry_run}" == false ]] || continue
        "${cmd[@]}" > /dev/null || die 4 "rewriting the ticket references of ${num} failed: re-run to retry"
        map_put "refs-${num}" 1 -
    done
fi

# GitLab has no sub-issues on every tier: the spec lists its tickets as a task list instead.
# map.tsv row "spec-tasks <count>" records how many tickets the published list holds.
if [[ "${tracker}" == gitlab && "${stopped}" == false && "${has_spec}" == true && "$(map_get spec-tasks)" != "${#t_num[@]}" ]]; then
    body="${work}/spec-with-tasks.md"
    render "${dir}/spec.md" "" "${body}"
    {
        printf '\n## Tickets\n\n'
        for num in "${t_num[@]}"; do echo "- [ ] $(ref_text "${num}")"; done
    } >> "${body}"
    print_cmd glab issue update "$(ref_id spec)" --description-file "${body}"
    if [[ "${dry_run}" == false ]]; then
        glab issue update "$(ref_id spec)" --description-file "${body}" > /dev/null ||
            die 4 "adding the task list to spec $(ref_text spec) failed: re-run to retry"
        map_put spec-tasks "${#t_num[@]}" -
    fi
fi

# --- Issue list ---------------------------------------------------------------------------------

echo
echo "Issues (${tracker}):"
list_line() {
    local url
    url="$([[ -f "${map}" ]] && awk -F '\t' -v k="$1" '$1 == k && $3 != "-" { print $3; exit }' "${map}" || true)"
    echo "- $1 $(ref_text "$1") $2${url:+ ${url}}"
}
[[ "${has_spec}" == false ]] || list_line spec "${spec_title}"
for i in "${!t_num[@]}"; do
    [[ "${dry_run}" == true || -n "$(map_get "${t_num[${i}]}")" ]] || continue # not published (--max)
    list_line "${t_num[${i}]}" "${t_title[${i}]}"
done
[[ "${dry_run}" == false ]] || echo "Dry run: nothing published. Rendered bodies: ${work}"
