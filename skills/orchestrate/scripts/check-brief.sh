#!/usr/bin/env bash
# Fail when a brief misses a required section, has an empty one, or keeps a <...> placeholder.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: check-brief.sh <brief-file>

Checks a brief written from assets/brief.md:
  - each required section is a "## " heading whose text starts with the section name (case does
    not matter, text after the name is allowed);
  - each required section has at least one non-blank line before the next "## " heading;
  - no <...> placeholder is left outside code: fenced blocks and `inline code` are skipped, so
    write literal angle brackets inside backticks.

Required sections, in any order:
  Goal; Settled decisions; Facts already found; Rules for the content you write;
  Rules for your own commands; Files you may and may not touch; Finish condition; Report format

Options:
  -h, --help  Show this help

Exit codes: 0 the brief passes, 1 findings (one per line on stderr), 2 usage error.
EOF
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
esac
[[ $# -eq 1 ]] || {
    usage >&2
    exit 2
}
file="$1"
[[ -f "${file}" && -r "${file}" ]] || {
    echo "error: '${file}' is not a readable file" >&2
    exit 2
}

# Separated by "|": BSD awk rejects a newline in a -v value.
required='Goal|Settled decisions|Facts already found|Rules for the content you write|Rules for your own commands|Files you may and may not touch|Finish condition|Report format'

# The awk program prints one finding per line. It avoids regex intervals ({n,m}) and gawk-only
# features so that the BSD awk of macOS runs it too.
findings="$(
    awk -v file="${file}" -v required="${required}" '
    # Length of the fence that opens or closes on this line (3+ backticks or tildes), else 0.
    function fence_len(line, s, c, n) {
        s = line
        sub(/^ ? ? ?/, "", s)
        c = substr(s, 1, 1)
        if (c != "`" && c != "~") return 0
        n = 0
        while (substr(s, n + 1, 1) == c) n++
        fence_char = c
        rest = substr(s, n + 1)
        return n >= 3 ? n : 0
    }
    BEGIN {
        nreq = split(required, req, "|")
        for (i = 1; i <= nreq; i++) { found[i] = 0; body[i] = 0 }
        current = 0
        open_len = 0
    }
    {
        line = $0
        n = fence_len(line)
        if (open_len == 0 && n > 0) {
            open_len = n; open_char = fence_char
            if (current) body[current]++
            next
        }
        if (open_len > 0) {
            # Closing fence: same character, at least as long, nothing after it.
            if (n >= open_len && fence_char == open_char && rest ~ /^[ \t]*$/) open_len = 0
            if (current && line ~ /[^ \t]/) body[current]++
            next
        }
        if (line ~ /^## /) {
            heading = tolower(substr(line, 4))
            current = 0
            for (i = 1; i <= nreq; i++) {
                name = tolower(req[i])
                if (substr(heading, 1, length(name)) == name) {
                    found[i] = 1; current = i; heading_line[i] = NR
                    break
                }
            }
            next
        }
        if (current && line ~ /[^ \t]/) body[current]++
        # Placeholders: skip inline code spans, autolinks and HTML comments.
        s = line
        gsub(/`[^`]*`/, "", s)
        gsub(/<(https?|mailto):[^>]*>/, "", s)
        gsub(/<!--.*-->/, "", s)
        while (match(s, /<[A-Za-z][^<>]*>/)) {
            printf "%s:%d: placeholder left: %s\n", file, NR, substr(s, RSTART, RLENGTH)
            s = substr(s, RSTART + RLENGTH)
        }
        # A placeholder wrapped over two lines.
        if (match(s, /<[A-Za-z][^<>]*$/))
            printf "%s:%d: placeholder left: %s\n", file, NR, substr(s, RSTART, RLENGTH)
    }
    END {
        if (open_len > 0) printf "%s: code fence opened and never closed\n", file
        for (i = 1; i <= nreq; i++) {
            if (!found[i]) printf "%s: missing section \"## %s\"\n", file, req[i]
            else if (body[i] == 0) printf "%s:%d: empty section \"## %s\"\n", file, heading_line[i], req[i]
        }
    }
    ' "${file}"
)"

if [[ -n "${findings}" ]]; then
    echo "${findings}" >&2
    echo "error: $(wc -l <<< "${findings}" | tr -d ' ') finding(s) in ${file}" >&2
    exit 1
fi
echo "ok: ${file} has every required section, none empty, no placeholder left"
