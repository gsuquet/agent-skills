#!/usr/bin/env bash
# List Claude Code sessions, and print the moments where the agent struggled in one of them.
set -euo pipefail

usage() {
    cat << 'EOF2'
Usage:
  session-moments.sh list [<dir>]
  session-moments.sh moments [--search-run <n>] [--pattern <regex>] <session.jsonl>
  session-moments.sh -h | --help

Reads Claude Code session logs (JSON Lines, schema undocumented). Writes nothing.

list     One line per session of <dir> (default: the current directory), newest first:
           <file>  <first timestamp>  <last timestamp>  <first user prompt>
         Logs are in ${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<slug>/<session id>.jsonl, where
         <slug> is the absolute path of <dir> with each character other than A-Z, a-z and 0-9
         replaced by '-'. Subagent logs are in <slug>/<session id>/subagents/agent-*.jsonl.

moments  One tab-separated line per moment, in log order:
           <timestamp>  FAILED      <tool> <input> -> <output>
           <timestamp>  DENIED      <tool> <input> -> <output>   (the user refused the call)
           <timestamp>  RETRY       <tool> x<n> <input>          (same tool and input as a failed
                                                                 call, or as the call just before)
           <timestamp>  SEARCH      x<n> <first input> .. <last input>
           <timestamp>  CORRECTION  <user message>
           <timestamp>  INTERRUPT   <user message>
         SEARCH: <n> search calls in a row (Grep, Glob, Read, LS, or a Bash grep, rg, find, fd,
         ls, cat, head, tail, tree), with no other tool call or user message between them.
         CORRECTION: a message typed by the user that matches --pattern (case-insensitive).
         Subagent logs have no user messages: CORRECTION is skipped there.

Options:
  --search-run <n>   Shortest search run to print (default: 10)
  --pattern <regex>  Correction pattern, Oniguruma syntax (default: see DEFAULT_PATTERN)

Every printed text is redacted (tokens, keys, passwords, long opaque strings) and cut to 200
characters. A line that is not valid JSON (a session still being written) is skipped.

Exit codes:
  0  success, even with no moment
  1  usage error
  2  jq not found
  3  log directory or file not found
  4  log schema changed: a required field is missing (the message names it)
EOF2
}

DEFAULT_PATTERN="^(no|nope|wrong|stop|wait|undo|revert)\\b|\\b(not what|that's not|that is not|i said|i asked|i told you|you should|you shouldn't|don't|do not|why did you|why are you|you forgot|you missed|instead|incorrect|mistake|still (fails|broken|wrong))\\b"

die() {
    local code="$1"
    shift
    echo "error: $*" >&2
    exit "${code}"
}

command -v jq > /dev/null || die 2 "jq not found: install jq 1.6 or later"

# Shared jq helpers: text of a message content, redaction, one-line cut to 200 characters.
JQ_LIB='
def text:
  if type == "string" then .
  elif type == "array" then map(if type == "object" and .type == "text" then .text else "" end) | join(" ")
  else "" end;
def redact:
  gsub("-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?(-----END [A-Z ]*PRIVATE KEY-----|$)"; "<REDACTED>")
  | gsub("(?i)(?<k>(bearer|basic)\\s+)[A-Za-z0-9._~+/=-]+"; "\(.k)<REDACTED>")
  | gsub("(?i)(?<k>(api[_-]?key|access[_-]?key|token|secret|passw(or)?d|pwd|authorization|cookie|credentials?)[\"'\''`]?\\s*[:=]\\s*)[\"'\''`]?[^\\s\"'\''`,;&]+"; "\(.k)<REDACTED>")
  | gsub("(?i)(?<k>://[^/:@\\s]+:)[^@\\s]+@"; "\(.k)<REDACTED>@")
  | gsub("(gh[pousr]_|github_pat_|glpat-|sk-|xox[abprs]-|AKIA|ASIA|AIza)[A-Za-z0-9_-]{10,}"; "<REDACTED>")
  | gsub("eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"; "<REDACTED>")
  | gsub("[A-Za-z0-9+_=-]{40,}"; "<REDACTED>");
def clip: redact | gsub("\\s+"; " ") | if length > 200 then .[0:200] + "..." else . end;
'

cmd_list() {
    [[ $# -le 1 ]] || {
        usage >&2
        exit 1
    }
    local dir="${1:-.}" abs projects slug sessions="" candidate file
    abs="$(cd "${dir}" 2> /dev/null && pwd)" || die 3 "no such directory: ${dir}"
    projects="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/projects"
    # The logical and the physical path can differ (for example /tmp and /private/tmp on macOS).
    for candidate in "${abs}" "$(cd "${abs}" && pwd -P)"; do
        slug="$(printf '%s' "${candidate}" | sed 's/[^A-Za-z0-9]/-/g')"
        if [[ -d "${projects}/${slug}" ]]; then
            sessions="${projects}/${slug}"
            break
        fi
    done
    [[ -n "${sessions}" ]] || die 3 "no session directory for ${abs} in ${projects} (expected ${projects}/${slug})"

    for file in "${sessions}"/*.jsonl; do
        [[ -f "${file}" ]] || continue
        printf '%s\t' "${file}"
        jq -nrR "${JQ_LIB}"'
            reduce (inputs | fromjson? | objects) as $r ({first: null, last: null, prompt: null};
              (if $r.timestamp then (.first //= $r.timestamp) | .last = $r.timestamp else . end)
              | if .prompt == null and $r.type == "user" and $r.origin.kind? == "human"
                then .prompt = ($r.message.content | text) else . end)
            | if .first == null then error("no record has the field .timestamp") else . end
            | [.first, .last, ((.prompt // "-") | clip | .[0:80])] | @tsv' < "${file}" ||
            die 4 "cannot read the schema of ${file}"
    done | sort -t $'\t' -k 3,3r
    # The pipeline runs in a subshell: check for sessions again outside it.
    compgen -G "${sessions}/*.jsonl" > /dev/null || die 3 "no session file in ${sessions}"
}

cmd_moments() {
    local search_run=10 pattern="${DEFAULT_PATTERN}" file=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --search-run)
                [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || die 1 "--search-run needs a positive integer"
                search_run="$2"
                shift 2
                ;;
            --pattern)
                [[ -n "${2:-}" ]] || die 1 "--pattern needs a regex"
                pattern="$2"
                shift 2
                ;;
            -*) die 1 "unknown option: $1" ;;
            *)
                [[ -z "${file}" ]] || die 1 "one session file only"
                file="$1"
                shift
                ;;
        esac
    done
    [[ -n "${file}" ]] || die 1 "missing <session.jsonl> (run: session-moments.sh list)"
    [[ -f "${file}" ]] || die 3 "no such file: ${file}"
    [[ -s "${file}" ]] || die 3 "empty file: ${file}"

    local subagent=false
    [[ "${file}" != */subagents/* ]] || subagent=true

    jq -nrR --argjson run "${search_run}" --arg pattern "${pattern}" --argjson subagent "${subagent}" \
        "${JQ_LIB}"'
        def need($r; $path; $name):
          if ($r | getpath($path)) == null
          then error("record \($r.uuid // "?") of type \($r.type): missing field \($name)") else . end;
        def search_call:
          (.name | IN("Grep", "Glob", "Read", "LS"))
          or (.name == "Bash" and ((.input.command // "") | test("\\b(grep|rg|find|fd|ls|cat|head|tail|tree)\\b")));
        def input_text: (.input | if type == "object" then (.command // .pattern // .file_path // .path // .url // tojson) else tojson end);
        def flush:
          if .streak.n >= $run
          then .out += [[.streak.ts, "SEARCH", "x\(.streak.n) \(.streak.first) .. \(.streak.last)"]]
          else . end
          | .streak = {n: 0};

        reduce (inputs | fromjson? | objects) as $r (
          {calls: {}, seen: {}, failed: {}, lastkey: null, streak: {n: 0}, out: [], records: 0, users: 0, origins: 0};
          .records += 1
          | if $r.type == "assistant" then
              need($r; ["timestamp"]; ".timestamp") | need($r; ["message", "content"]; ".message.content")
              | reduce ($r.message.content | if type == "array" then .[] else empty end
                        | select(type == "object" and .type == "tool_use")) as $c (.;
                  need($c; ["id"]; "tool_use.id") | need($c; ["name"]; "tool_use.name")
                  | need($c; ["input"]; "tool_use.input")
                  | ($c | input_text | clip) as $in
                  | ($c.name + " " + ($c.input | if type == "object" then del(.description) else . end | tojson)) as $key
                  | .calls[$c.id] = {name: $c.name, input: $in, key: $key}
                  | .seen[$key] += 1
                  | if .seen[$key] > 1 and (.failed[$key] or .lastkey == $key)
                    then .out += [[$r.timestamp, "RETRY", "\($c.name) x\(.seen[$key]) \($in)"]] else . end
                  | .lastkey = $key
                  | if ($c | search_call)
                    then .streak = (if .streak.n == 0 then {n: 1, ts: $r.timestamp, first: $in, last: $in}
                                    else .streak | .n += 1 | .last = $in end)
                    else flush end)
            elif $r.type == "user" then
              .users += 1
              | (if $r.origin != null then .origins += 1 else . end)
              | need($r; ["timestamp"]; ".timestamp") | need($r; ["message", "content"]; ".message.content")
              | ($r.message.content | text) as $msg
              | reduce ($r.message.content | if type == "array" then .[] else empty end
                        | select(type == "object" and .type == "tool_result")) as $t (.;
                  need($t; ["tool_use_id"]; "tool_result.tool_use_id")
                  | if $t.is_error == true then
                      (.calls[$t.tool_use_id] // {name: "?", input: "?"}) as $c
                      | ($t.content | text | clip) as $outp
                      | (if ($outp | test("(?i)permission .*denied|doesn.t want to proceed|user (rejected|denied)")) then "DENIED" else "FAILED" end) as $kind
                      | .out += [[$r.timestamp, $kind, "\($c.name) \($c.input) -> \($outp)"]]
                      | if $c.key then .failed[$c.key] = true else . end
                    else . end)
              | if ($msg | test("\\[Request interrupted by user")) then
                  flush | .out += [[$r.timestamp, "INTERRUPT", ($msg | clip)]]
                elif $r.origin.kind? == "human" then
                  flush
                  | if ($msg | test($pattern; "i")) then .out += [[$r.timestamp, "CORRECTION", ($msg | clip)]] else . end
                else . end
            else . end)
        | flush
        | if .records == 0 then error("no JSON record in the file") else . end
        | if .users > 0 and .origins == 0 and ($subagent | not)
          then error("no user record has the field .origin (used to find messages typed by the user)") else . end
        | .out | sort_by(.[0]) | .[] | @tsv' < "${file}"
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    list)
        shift
        cmd_list "$@"
        ;;
    moments)
        shift
        cmd_moments "$@" || {
            code=$?
            # jq exits 5 on error(): a missing field. Its message is already on stderr.
            [[ ${code} -eq 5 ]] && die 4 "the log schema changed; update this script"
            exit "${code}"
        }
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
