#!/usr/bin/env bash
# Check Markdown documents against the readability limits of their type.
set -euo pipefail

# Word limits by type. Fenced blocks, front matter, HTML comments and link targets do not count.
MAX_WORDS_RFC=1500
MAX_WORDS_ADR=400
MAX_WORDS_CONCEPT=800
MAX_WORDS_HOW_TO=600
MAX_WORDS_RUNBOOK=600
MAX_WORDS_README=500
MAX_WORDS_STUDY_INDEX=600
# Diagrams per document.
MAX_DIAGRAMS_RFC=6
MAX_DIAGRAMS_ADR=1
# Content of one diagram.
MAX_NODES=10
MAX_EDGES=12
MAX_LABEL_WORDS=6
MAX_MESSAGES=8
MAX_BARS=8
# Decisions of an RFC.
MAX_DECISIONS=5
# A family of codes (D7, D12) is reported from this number of occurrences.
MIN_CODE_USES=2
# Real names that look like codes: priorities, percentiles and products (awk regex).
REAL_NAMES='P[1-5]|P50|P75|P9[059]|S3|EC2|D2'

usage() {
    cat << EOF
Usage: check-readability.sh --type <type> [--allow-code <regex>]... <file>...

Checks Markdown documents, whatever their template, against the readability limits. Prints one
"file:line: rule: message" line per finding on stderr, or one "ok" line per file on stdout.

Types: rfc, adr, concept, how-to, runbook, readme, study-index, reference, tutorial, other.

  word-limit         words outside fenced blocks, front matter, HTML comments and link targets;
                     prose, headings, tables and the metadata list count. In the RFC template of
                     this skill, ## Decision and the "- YYYY-MM-DD URL" lines of
                     ## Implementation do not. Max:
                       rfc ${MAX_WORDS_RFC}, adr ${MAX_WORDS_ADR}, concept ${MAX_WORDS_CONCEPT}, how-to ${MAX_WORDS_HOW_TO}, runbook ${MAX_WORDS_RUNBOOK},
                       readme ${MAX_WORDS_README}, study-index ${MAX_WORDS_STUDY_INDEX}; reference, tutorial, other: no limit
  diagram-count      diagrams in the document, max: rfc ${MAX_DIAGRAMS_RFC}, adr ${MAX_DIAGRAMS_ADR}; others: no limit. A diagram
                     is a mermaid, d2, plantuml or dot block, or a local .svg or .excalidraw image
                     on its own line; without a source file (.d2, .mmd, ...) next to it, an image that
                     links elsewhere or is named logo, badge, icon, banner or shield is not one
  diagram-nodes      nodes of a Mermaid flowchart, subgraphs not counted, max: ${MAX_NODES}
  diagram-edges      visible edges of a Mermaid flowchart ("a & b --> c" has 2), max: ${MAX_EDGES}
  diagram-label      words of a node, edge or subgraph label of a Mermaid flowchart, max: ${MAX_LABEL_WORDS}
  sequence-messages  messages of a Mermaid sequence diagram, max: ${MAX_MESSAGES}
  xychart-bars       bars of a Mermaid xychart, all series together, max: ${MAX_BARS}
  diagram-caption    the first text under each diagram must be a paragraph; a "Legend:" line paragraph
                     does not count as the caption
  diagram-type       Mermaid C4*, timeline and quadrantChart are not allowed
  invented-code      a family of 1 or 2 capital letters and a number (D7, WP2), used ${MIN_CODE_USES} times or
                     more; inline code, code blocks, URLs and link targets are skipped. Real names
                     (P1 to P5, P50, P75, P90, P95, P99, S3, EC2, D2) count only next to another code
                     of their family; "<!-- readability: allow-code <regex>... -->" in the
                     document adds names, split on spaces
  allow-code         an allow-code comment holds an invalid regex
  decision-table     rfc only: the Summary section (a heading of level 1 or 2 that holds "summary") needs a table with the columns Decision, Why, Cost
                     and Reversible, with at least 1 row and no empty cell
  decision-reversible  rfc only: each Reversible cell starts with yes or no, then says how or why, not
                     starting with yes, no, unknown or depends. While
                     the status is draft or withdrawn, "open" with a link to #open-questions passes. A cell that
                     says no contradicts "reversibility: two-way"
  decision-cap       rfc only: rows of the decision tables, and "### " headings of "## Decisions",
                     max: ${MAX_DECISIONS} each; above that, split into peer RFCs
  doc-type           the front matter is the one of an RFC or ADR of this skill, and contradicts --type
  unclosed-block     a fence, front matter or HTML comment that never closes hides text

Not checked here: repetition, caption quality, legend and colors. Review them by hand.

Options:
  --type <type>         type of every file given (required)
  --allow-code <regex>  real name that is not an invented code; matches the whole code, for
                        example 'S3' or 'Q[1-4]' (repeatable, awk regex)
  --base <git-ref>      report a finding that the version of the file in <git-ref> already has as
                        "existing", without failing; a worse count, and every finding of a file that
                        <git-ref> does not have, still fails. Outside a Git repository, every
                        finding is new
  --status <status>     check an RFC as if it had this status: draft, review, accepted, rejected,
                        withdrawn or superseded
  --count-decisions     print only the number of rows of the decision table
  --list-allowed        print only the names of the allow-code comments, one per line
  -h, --help            show this help

Exit codes: 0 pass, 1 findings, 2 usage error.
EOF
}

usage_error() {
    echo "error: $1" >&2
    exit 2
}

# valid_regex <regex>: succeed when awk accepts the regex, alone and in a group.
valid_regex() {
    RE="$1" awk 'BEGIN { x = ("" ~ ENVIRON["RE"]) + ("" ~ ("^(" ENVIRON["RE"] ")$")); exit }' 2> /dev/null
}

type=""
allow=""
base=""
forced_status=""
mode=findings
files=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --type)
            [[ $# -ge 2 ]] || usage_error "--type needs a type"
            type="$2"
            shift 2
            ;;
        --allow-code)
            [[ $# -ge 2 && -n "$2" ]] || usage_error "--allow-code needs a regex"
            valid_regex "$2" ||
                usage_error "--allow-code: invalid regex '$2'"
            allow="${allow:+${allow}|}($2)"
            shift 2
            ;;
        --base)
            [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || usage_error "--base needs a Git ref"
            base="$2"
            shift 2
            ;;
        --status)
            [[ $# -ge 2 && -n "$2" ]] || usage_error "--status needs a status"
            forced_status="$(tr '[:upper:]' '[:lower:]' <<< "$2")"
            case "${forced_status}" in
                draft | review | accepted | rejected | withdrawn | superseded) ;;
                *) usage_error "--status: unknown status '$2'" ;;
            esac
            shift 2
            ;;
        --count-decisions)
            mode=rows
            shift
            ;;
        --list-allowed)
            mode=allowed
            shift
            ;;
        --)
            shift
            files+=("$@")
            break
            ;;
        -*)
            echo "error: unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
        *)
            files+=("$1")
            shift
            ;;
    esac
done

# 0 means no limit.
max_words=0
max_diagrams=0
case "${type}" in
    rfc)
        max_words="${MAX_WORDS_RFC}"
        max_diagrams="${MAX_DIAGRAMS_RFC}"
        ;;
    adr)
        max_words="${MAX_WORDS_ADR}"
        max_diagrams="${MAX_DIAGRAMS_ADR}"
        ;;
    concept) max_words="${MAX_WORDS_CONCEPT}" ;;
    how-to) max_words="${MAX_WORDS_HOW_TO}" ;;
    runbook) max_words="${MAX_WORDS_RUNBOOK}" ;;
    readme) max_words="${MAX_WORDS_README}" ;;
    study-index) max_words="${MAX_WORDS_STUDY_INDEX}" ;;
    reference | tutorial | other) ;;
    "") usage_error "--type is required" ;;
    *) usage_error "unknown type '${type}'" ;;
esac
[[ ${#files[@]} -gt 0 ]] || {
    usage >&2
    exit 2
}
for file in "${files[@]}"; do
    [[ -f "${file}" && -r "${file}" ]] || usage_error "cannot read '${file}'"
done

# front_matter <file>: print the number of the line that closes the front matter, 0 without one, or
# "unclosed". A leading "---" whose text is not YAML is a thematic break: it hides nothing.
front_matter() {
    LC_ALL=C awk '
        { sub(/\r$/, "") }
        NR == 1 { sub(/^\357\273\277/, ""); if ($0 != "---") exit; next }
        NR == 2 && $0 !~ /^([A-Za-z_"\047][^:]*:([ \t]|$)|#|---$|\.\.\.$)/ { bad = 1; exit }
        $0 == "---" || $0 == "..." { end = NR; exit }
        $0 !~ /^([ \t]|[A-Za-z0-9_"\047][^:]*:([ \t]|$)|#|-([ \t]|$)|[]}]|$)/ { bad = 1; exit }
        END { print end ? end : (NR < 2 || bad ? 0 : "unclosed") }
    ' < "$1"
}

# check <file> <dir> <status>: print one "line: rule: message" per finding, sorted by line. <dir>
# holds the images.
check() {
    local allowed names="${allow}" line name
    allowed="$(scan "$1" "$2" "$3" allowed "")" || return 1
    while read -r line name; do
        [[ -n "${name}" ]] || continue
        if valid_regex "${name}"; then
            names="${names:+${names}|}(${name})"
        else
            printf "%s: allow-code: invalid regex '%s' in a comment\n" "${line}" "${name}"
        fi
    done <<< "${allowed}" > "${tmp}/invalid"
    scan "$1" "$2" "$3" findings "${names}" > "${tmp}/scan" || return 1
    LC_ALL=C sort -s -n -k1,1 "${tmp}/invalid" "${tmp}/scan"
}

# scan <file> <dir> <status> <mode> <allowed codes>: run the parser. The modes print the findings, the
# number of decisions (rows), or a line number and a name per allowed code (allowed). The awk program avoids regex intervals ({n,m}) and gawk-only features so that the BSD awk
# of macOS runs it too.
scan() {
    local front_end front_unclosed=0
    front_end="$(front_matter "$1")"
    [[ "${front_end}" != unclosed ]] || {
        front_end=0
        front_unclosed=1
    }
    LC_ALL=C tr -d '\000' < "$1" | LC_ALL=C ALLOW="$5" DOC_DIR="$2" awk -v type="${type}" -v mode="$4" \
        -v front_end="${front_end}" -v front_unclosed="${front_unclosed}" \
        -v forced_status="$3" -v real_names="${REAL_NAMES}" \
        -v max_words="${max_words}" -v max_diagrams="${max_diagrams}" \
        -v max_nodes="${MAX_NODES}" -v max_edges="${MAX_EDGES}" \
        -v max_label="${MAX_LABEL_WORDS}" -v max_messages="${MAX_MESSAGES}" \
        -v max_bars="${MAX_BARS}" -v max_decisions="${MAX_DECISIONS}" \
        -v min_code_uses="${MIN_CODE_USES}" '
    function finding(line, rule, message) {
        if (mode != "findings") return
        printf "%d: %s: %s\n", line, rule, message
    }
    # Number of whitespace-separated tokens that hold more than punctuation, as a reader sees them:
    # no HTML tag, no entity; an unspaced dash separates two words.
    function words(s, parts, n, i, count) {
        gsub(/<\/?[A-Za-z][A-Za-z0-9-]*([ \t\/][^<>]*)?>/, " ", s)
        gsub(/&#?[A-Za-z0-9]+;/, " ", s)
        gsub(/\342\200[\223\224]|---*/, " ", s)
        n = split(s, parts, /[ \t\n]+/)
        count = 0
        for (i = 1; i <= n; i++) {
            # UTF-8 dashes, quotes and arrows.
            gsub(/\342\200[\200-\277]|\342\206[\200-\277]/, "", parts[i])
            gsub(/[[:punct:]]/, "", parts[i])
            if (parts[i] != "") count++
        }
        return count
    }
    function count_char(s, c, n, i) {
        n = 0
        while ((i = index(s, c)) > 0) { n++; s = substr(s, i + 1) }
        return n
    }
    # Length of the fence at the start of a line (3+ backticks or tildes), else 0.
    function fence_len(s, c, n) {
        sub(/^[ \t]+/, "", s)
        c = substr(s, 1, 1)
        if (c != "`" && c != "~") return 0
        n = 0
        while (substr(s, n + 1, 1) == c) n++
        fence_char = c
        fence_rest = substr(s, n + 1)
        # The info string of a backtick fence holds no backtick: that is inline code.
        if (c == "`" && index(fence_rest, "`")) return 0
        return n >= 3 ? n : 0
    }
    # Remove the HTML comments, which can span lines.
    function strip_comments(s, out, i) {
        out = ""
        while (s != "") {
            if (in_comment) {
                i = index(s, "-->")
                if (!i) { comment = comment " " s; return out }
                comment = comment " " substr(s, 1, i - 1)
                read_comment(comment)
                in_comment = 0
                s = substr(s, i + 3)
                continue
            }
            i = index(s, "<!--")
            if (!i) return out s
            out = out substr(s, 1, i - 1)
            # Escaped, or inside inline code: literal text.
            if (out ~ /\\$/ || count_char(out, "`") % 2) { out = out "<!--"; s = substr(s, i + 4); continue }
            in_comment = 1
            comment = ""
            comment_line = NR
            s = substr(s, i + 4)
        }
        return out
    }
    function read_comment(s, names, n, i) {
        if (mode != "allowed") return
        if (!sub(/^[ \t]*readability:[ \t]*allow-code[ \t]+/, "", s)) return
        n = split(s, names, /[ \t]+/)
        for (i = 1; i <= n; i++) if (names[i] != "") print comment_line, names[i]
    }
    # Width of a string, with tab stops of 4, when it starts at a column.
    function width(s, column, i, start) {
        start = column
        for (i = 1; i <= length(s); i++) {
            if (substr(s, i, 1) == "\t") column += 4 - column % 4
            else column++
        }
        return column - start
    }
    function indent(s) {
        match(s, /^[ \t]*/)
        return width(substr(s, 1, RLENGTH), 0)
    }
    function is_rule(s) {
        gsub(/[ \t]/, "", s)
        return s ~ /^(---+|\*\*\*+|___+)$/
    }
    # Find the list items, footnotes and admonitions that hold a line. Sets base (the column where
    # their content starts), indented (the line is an indented code block) and content (the line
    # without its list markers). The quoted lines have their own stack.
    function read_containers(s, ind, spaces, marker, parts) {
        content = s
        indented = 0
        if (s ~ /^[ \t]*$/) { paragraph = 0; return }
        ind = indent(s)
        while (depth[quoted] && ind < item[quoted, depth[quoted]]) depth[quoted]--
        base = depth[quoted] ? item[quoted, depth[quoted]] : 0
        if (ind - base >= 4) {
            if (!paragraph) indented = 1
            can_fence = 0
            return
        }
        can_fence = 1
        while (!is_rule(content) && match(content, /^[ \t]*([-*+]|[0-9]+[.)])([ \t]+|$)/)) {
            marker = substr(content, 1, RLENGTH)
            content = substr(content, RLENGTH + 1)
            parts = marker
            sub(/[ \t]+$/, "", parts)
            spaces = width(substr(marker, length(parts) + 1), 0)
            # ind: the column where the content of the marker starts.
            base = (depth[quoted] && first_marker ? ind : 0) + width(parts, 0) + (spaces > 4 || content == "" ? 1 : spaces)
            first_marker = 1
            ind = base
            item[quoted, ++depth[quoted]] = base
        }
        first_marker = 0
        if (content ~ /^[ \t]*(!!!|\?\?\?\+?|===)[ \t]/ || content ~ /^[ \t]*\[\^[^]]*\]:/)
            item[quoted, ++depth[quoted]] = ind + 4
        paragraph = !(content ~ /^[ \t]*(#+([ \t]|$)|$)/ || is_rule(content))
    }
    function new_diagram(line) {
        diagrams++
        if (max_diagrams && diagrams == max_diagrams + 1) diagrams_line = line
        if (caption_for) no_caption(caption_for)
    }
    function no_caption(line) {
        finding(line, "diagram-caption", "no caption paragraph under the diagram")
        caption_for = 0
    }
    function has_source(target, stem, exts, n, i, path, unused, found) {
        if (target ~ /\.(excalidraw|drawio)(\.svg|\.png)?$/) return 1
        stem = target
        sub(/\.[^.\/]*$/, "", stem)
        n = split("d2 mmd puml plantuml dot gv excalidraw drawio", exts, " ")
        for (i = 1; i <= n; i++) {
            path = ENVIRON["DOC_DIR"] "/" stem "." exts[i]
            found = (getline unused < path) >= 0
            if (found) { close(path); return 1 }
        }
        return 0
    }
    # A local .svg or .excalidraw image. Without a source file next to it, an image that links to
    # another page or that is named as a logo or a badge is decoration.
    function is_diagram_image(s, target, rest, link) {
        sub(/^[ \t]+/, "", s)
        while (match(s, /^<(p|picture|source|div|center|figure|span)([ \t][^<>]*)?>[ \t]*/)) s = substr(s, RLENGTH + 1)
        link = ""
        if (match(s, /^<a[ \t][^<>]*>[ \t]*/)) {
            link = attribute(substr(s, 1, RLENGTH), "href")
            s = substr(s, RLENGTH + 1)
        }
        while (match(s, /^<(p|picture|source|div|center|figure|span)([ \t][^<>]*)?>[ \t]*/)) s = substr(s, RLENGTH + 1)
        if (s !~ /^(\[?!\[|<img[ \t])/) return 0
        if (match(s, /!\[[^]]*\]\((<[^>]*>|[^ \t)]*)/)) {
            target = substr(s, RSTART, RLENGTH)
            rest = substr(s, RSTART + RLENGTH)
            sub(/^!\[[^]]*\]\(/, "", target)
            gsub(/[<>]/, "", target)
            if (s ~ /^\[!\[/ && match(rest, /\]\([^ \t)]*/)) link = substr(rest, RSTART + 2, RLENGTH - 2)
        } else target = attribute(s, "src")
        if (target == "" || target ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || target ~ /^\/\//) return 0
        sub(/[?#].*$/, "", target)
        if (tolower(target) !~ /\.(svg|excalidraw|excalidraw\.png)$/) return 0
        if (has_source(target)) return 1
        if (link != "" && link != target) return 0
        sub(/^.*\//, "", target)
        return tolower(target) !~ /logo|badge|icon|banner|shield/
    }
    # Value of an HTML attribute, with double or single quotes.
    function attribute(s, name, value) {
        if (!match(s, name "=(\"[^\"]*\"|\047[^\047]*\047)")) return ""
        value = substr(s, RSTART + length(name) + 2, RLENGTH - length(name) - 3)
        return value
    }
    # Record the invented codes of a line of text.
    function scan_codes(s, i, code, before, before2, after, family) {
        if (s ~ /^[ \t]*$/) { open_code = 0; return }
        # Inline code that started on the line before.
        if (open_code && (i = index(s, "`"))) s = substr(s, i + 1)
        open_code = 0
        gsub(/``[^`]*``/, " ", s)
        gsub(/`[^`]*`/, " ", s)
        if (s ~ /^[ \t]*\[[^]^][^]]*\]:/) return
        sub(/^[ \t]*\[\^[^]]*\]:/, " ", s)
        gsub(/\[\^[^]]*\]/, " ", s)
        if ((i = index(s, "`")) > 0) {
            open_code = 1
            s = substr(s, 1, i - 1)
        }
        gsub(/\]\([^)]*\)/, "] ", s)
        gsub(/\]\[[^]]*\]/, "] ", s)
        gsub(/[A-Za-z][A-Za-z0-9+.-]*:\/\/[^ \t<>)|]*/, " ", s)
        gsub(/<\/?[A-Za-z][^<>]*>/, " ", s)
        s = "  " s " "
        # Emphasis with underscores.
        gsub(/[ \t(|]__?/, " ", s)
        gsub(/__?[ \t).,;:|]/, " ", s)
        while (match(s, /[A-Z][A-Z]?[0-9]+/)) {
            code = substr(s, RSTART, RLENGTH)
            before = substr(s, RSTART - 1, 1)
            before2 = substr(s, RSTART - 2, 1)
            after = substr(s, RSTART + RLENGTH, 1)
            # Drop the code and the word it is part of. The character that is left gives the context
            # of the next code: \002 after a code, x after anything else.
            s = substr(s, RSTART + RLENGTH)
            if (before ~ /[A-Za-z0-9_.#]/ || after ~ /[A-Za-z0-9_]/ ||
                # A range or a list (B1-B5, T1/T2) holds codes, other compound names do not.
                (before ~ /[-\/]/ && before2 != "\002")) {
                sub(/^[A-Za-z0-9_]+/, "", s)
                s = " x" s
                continue
            }
            s = " \002" s
            ncodes++
            code_of[ncodes] = code
            code_at[ncodes] = NR
        }
    }
    # Group the codes by family, once the allowed codes of the whole document are known. A built-in
    # name counts only next to a code of its family that is not one: D1 and D2 are invented codes.
    function count_codes(i, code, family, pass) {
        for (pass = 1; pass <= 2; pass++) for (i = 1; i <= ncodes; i++) {
            code = code_of[i]
            if (allow != "" && code ~ ("^(" allow ")$")) continue
            family = code
            sub(/[0-9]+$/, "", family)
            if (pass == 1) {
                if (code !~ ("^(" real_names ")$")) invented[family] = 1
                continue
            }
            if (!(family in invented)) continue
            if (!(family in code_uses)) { families[++nfamilies] = family; code_line[family] = code_at[i] }
            code_uses[family]++
            if (!((family, code) in code_seen)) {
                code_seen[family, code] = 1
                code_list[family] = code_list[family] (code_list[family] == "" ? "" : ", ") code
            }
        }
    }
    # Split a table row into cells[1..n] and return n.
    function read_row(s, cells, n, i) {
        gsub(/\\\|/, "\001", s)
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        sub(/^\|/, "", s)
        sub(/\|$/, "", s)
        n = split(s, cells, "|")
        for (i = 1; i <= n; i++) gsub(/^[ \t]+|[ \t]+$/, "", cells[i])
        return n
    }
    function is_delimiter_row(s, parts, n, i) {
        if (s !~ /-/ || s !~ /^[ \t|:-]+$/ || s !~ /[|:]/) return 0
        n = read_row(s, parts)
        for (i = 1; i <= n; i++) if (parts[i] !~ /^:?-+:?$/) return 0
        return n
    }
    # Column of a header: the cell that is the name, else the first that holds it.
    function column_of(name, cells, n, i, found) {
        found = 0
        for (i = 1; i <= n; i++) {
            if (cells[i] == name) return i
            if (!found && index(cells[i], name)) found = i
        }
        return found
    }
    function check_reversible(value, shown, answer, reason) {
        shown = value
        reason = ""
        answer = tolower(value)
        if (answer ~ /\]\([^)]*#open-questions\)/) reason = "open"
        gsub(/\]\([^)]*\)|\[/, "", answer)
        gsub(/<[^<>]*>|&nbsp;|\302\240/, "", answer)
        gsub(/&[mn]dash;|\342\200[\220-\225]|\342\210\222/, "-", answer)
        gsub(/[*_`~. \t]+/, " ", answer)
        gsub(/^ | $/, "", answer)
        if (answer ~ /^open([^a-z0-9]|$)/ && (status == "draft" || status == "withdrawn") && reason == "open") return
        if (answer ~ /^(yes|no)([^a-z0-9\200-\377]|$)/) {
            reason = answer
            sub(/^(yes|no)[^a-z0-9\200-\377]*/, "", reason)
            if (reason != "" && reason !~ /^(not stated|not assessed|not known|unknown|tbd|tbc|todo|n\/a|to be [a-z]+)[^a-z0-9]*$/ && reason !~ /^(yes|no|unknown|depends)([^a-z0-9\200-\377]|$)/) {
                if (answer ~ /^no/ && reversibility == "two-way")
                    finding(NR, "decision-reversible", "Reversible cell says no, but reversibility: is two-way")
                return
            }
            finding(NR, "decision-reversible", "Reversible cell says " shown ": write how or why")
            return
        }
        finding(NR, "decision-reversible", "Reversible cell " (shown == "" ? "is empty" : "says " shown) ": write yes or no, and how or why" \
            (answer ~ /^open([^a-z0-9]|$)/ ? "; only a draft can say open, with a link to Open questions" : ""))
    }
    function scan_table(s, n, c, cells) {
        if (s ~ /^[ \t]*$/ || s ~ /^[ \t]*(#+[ \t]|[-*+][ \t]|[0-9]+[.)][ \t]|<\/?[A-Za-z])/ || is_rule(s)) {
            in_table = 0
            prev_row = ""
            return
        }
        if (in_table) {
            if (in_table == 2) {
                decision_rows++
                split("", cells)
                read_row(s, cells)
                if (type == "rfc") {
                    if (cells[columns["decision"]] == "" || cells[columns["why"]] == "" || cells[columns["cost"]] == "")
                        finding(NR, "decision-table", "a Decision, Why or Cost cell is empty")
                    check_reversible(cells[columns["reversib"]])
                }
            }
            return
        }
        n = is_delimiter_row(s)
        if (n && prev_row ~ /\|/ && read_row(tolower(prev_row), cells) == n) {
            in_table = 1
            for (c in cells) gsub(/[*_`]/, "", cells[c])
            columns["decision"] = column_of("decision", cells, n)
            columns["why"] = column_of("why", cells, n)
            columns["cost"] = column_of("cost", cells, n)
            columns["reversib"] = column_of("reversible", cells, n)
            if (!columns["reversib"]) columns["reversib"] = column_of("reversib", cells, n)
            split("", seen_column)
            for (c in columns) if (columns[c]) seen_column[columns[c]] = 1
            n = 0
            for (c in seen_column) n++
            if (n == 4) {
                if (in_summary) {
                    in_table = 2
                    if (!table_line) table_line = NR - 1
                } else if (!misplaced_line) misplaced_line = NR - 1
            }
        }
        prev_row = s
    }

    # Flowchart scanner: T is the text, P the position, T_LINE the document line of position 1.
    function line_at(pos) { return T_LINE + count_char(substr(T, 1, pos - 1), "\n") }
    function skip_blanks() { while (substr(T, P, 1) ~ /^[ \t]$/) P++ }
    function skip_statement() { while (P <= length(T) && substr(T, P, 1) !~ /^[\n;]$/) P++ }
    function check_label(s, pos, shown, n) {
        gsub(/fa[a-z]?:fa-[a-z0-9-]+/, "", s)
        gsub(/\\n|#[A-Za-z0-9]+;/, " ", s)
        n = words(s)
        if (n <= max_label) return
        shown = s
        gsub(/[ \t\n]+/, " ", shown)
        finding(line_at(pos), "diagram-label", n " words in a label, max " max_label ": " shown)
    }
    # Read a bracketed text from P, nested brackets and quotes included; P moves after it.
    function read_brackets(start, i, c, depth, quoted) {
        start = P
        depth = 0
        quoted = 0
        for (i = P; i <= length(T); i++) {
            c = substr(T, i, 1)
            if (c == "\"") quoted = !quoted
            if (quoted) continue
            # ">" opens only the asymmetric shape: id>text].
            if (c ~ /^[[({]$/ || (i == start && c == ">")) depth++
            else if (c ~ /^[])}]$/ && --depth == 0) {
                P = i + 1
                return substr(T, start, i - start + 1)
            }
        }
        # Never closed: take the rest of the line.
        while (P <= length(T) && substr(T, P, 1) != "\n") P++
        return substr(T, start, P - start)
    }
    function label_of(s) {
        gsub(/^[][(){}>"`\/\\ \t\n]+/, "", s)
        # Keep the ">" of a final <br/>.
        gsub(/[][(){}"`\\ \t\n]+$/, "", s)
        return s
    }
    # Read a node identifier with the lexer rule of Mermaid: "-" and "=" belong to it unless they
    # start a link.
    function read_id(start, c, after) {
        start = P
        while (P <= length(T)) {
            c = substr(T, P, 1)
            after = substr(T, P + 1, 1)
            if (c ~ /^[ \t\n;|<>@]$/ || c ~ /^[][(){}]$/) break
            if (c == "-" && (after == "" || after ~ /^[->.]$/)) break
            if (c == "=" && after == "=") break
            if (c == "~" && after == "~") break
            if (c == ":" && substr(T, P, 3) == ":::") break
            P++
        }
        return substr(T, start, P - start)
    }
    # Read a node, its shape and its class. Returns 0 when there is none.
    function read_node(id, pos, label) {
        skip_blanks()
        pos = P
        id = read_id()
        if (id == "") return 0
        if (!(id in node_seen)) { node_seen[id] = 1; node_ids[++nnodes] = id }
        if (substr(T, P, 2) == "@{") {
            P++
            label = read_brackets()
            if (match(label, /label[ \t]*:[ \t]*"[^"]*"/) || match(label, /label[ \t]*:[^,}]*/)) {
                label = substr(label, RSTART, RLENGTH)
                sub(/^label[ \t]*:/, "", label)
                check_label(label_of(label), pos)
            }
        } else if (substr(T, P, 1) ~ /^[[({>]$/) check_label(label_of(read_brackets()), pos)
        if (substr(T, P, 3) == ":::") { P += 3; read_id() }
        return 1
    }
    # Read "a & b & c" and return the number of nodes.
    function read_group(n) {
        n = read_node()
        while (n) {
            skip_blanks()
            if (substr(T, P, 1) != "&") break
            P++
            if (!read_node()) break
            n++
        }
        return n
    }
    # Read a link. Returns 0 for none, 1 for a visible link, 2 for an invisible one.
    function read_link(s, close_re, pos, result) {
        skip_blanks()
        s = substr(T, P)
        if (match(s, /\n/)) s = substr(s, 1, RSTART - 1)
        pos = P
        if (match(s, /^[A-Za-z0-9_]+@/) && substr(s, RLENGTH + 1) ~ /^[xo<]?(--|==|-\.|~~)/) {
            P += RLENGTH
            s = substr(s, RLENGTH + 1)
        }
        result = 1
        if (match(s, /^~~~+/)) { P += RLENGTH; result = 2 }
        else if (match(s, /^[xo<]?--+[-xo>]/) || match(s, /^[xo<]?==+[=xo>]/) ||
            match(s, /^[xo<]?-\.+-[xo>]?/)) P += RLENGTH
        else if (match(s, /^[xo<]?(--|==|-\.)/)) {
            close_re = "--+[-xo>]"
            if (index(substr(s, 1, RLENGTH), "==")) close_re = "==+[=xo>]"
            else if (index(substr(s, 1, RLENGTH), "-.")) close_re = "\\.+-[xo>]?"
            P += RLENGTH
            s = substr(s, RLENGTH + 1)
            if (!match(s, close_re)) return 0
            P += RSTART + RLENGTH - 1
            check_label(label_of(substr(s, 1, RSTART - 1)), pos)
        } else return 0
        skip_blanks()
        if (substr(T, P, 1) == "|") {
            s = substr(T, P + 1)
            # A quoted label can hold a pipe.
            if (match(s, /^[ \t]*"[^"\n]*"[ \t]*\|/) || match(s, /^[^|]*\|/)) {
                P += RLENGTH + 1
                check_label(label_of(substr(s, 1, RLENGTH - 1)), pos)
            }
        }
        return result
    }
    function check_flowchart(block_line, n, i, left, right, link, start, rest, edges, total) {
        split("", node_seen)
        split("", node_ids)
        split("", subgraphs)
        nnodes = 0
        edges = 0
        P = 1
        while (P <= length(T)) {
            while (substr(T, P, 1) ~ /^[ \t\n;]$/) P++
            if (P > length(T)) break
            start = P
            rest = substr(T, P)
            if (match(rest, /\n/)) rest = substr(rest, 1, RSTART - 1)
            if (match(rest, /^subgraph[ \t]+/)) {
                P += RLENGTH
                start = P
                rest = substr(rest, RLENGTH + 1)
                if (rest !~ /^"/ && match(rest, /\[/)) {
                    n = RSTART
                    P += n - 1
                    rest = substr(rest, 1, n - 1)
                    check_label(label_of(read_brackets()), start)
                } else check_label(label_of(rest), start)
                gsub(/^[ \t"]+|[ \t";]+$/, "", rest)
                subgraphs[rest] = 1
                while (P <= length(T) && substr(T, P, 1) != "\n") P++
            } else if (rest ~ /^accDescr[ \t]*\{/) {
                while (P <= length(T) && substr(T, P, 1) != "}") P++
                P++
            } else if (rest ~ /^accDescr[ \t]*:/ || rest ~ /^accTitle[ \t]*:/ || rest ~ /^(subgraph|end)[ \t;]*$/ ||
                rest ~ /^(direction|classDef|class|style|linkStyle|click)[ \t]/) {
                while (P <= length(T) && substr(T, P, 1) != "\n") P++
            } else if (match(rest, /^[A-Za-z0-9_]+@\{/) && rest ~ /@\{[ \t]*(animate|animation|curve)[ \t]*:/) {
                # Properties of an edge, not a node.
                P += RLENGTH - 1
                read_brackets()
            } else {
                left = read_group()
                while (left && (link = read_link())) {
                    right = read_group()
                    if (link == 1) edges += left * right
                    left = right
                }
                # Always move forward, also on text the scanner does not know.
                if (P == start) P++
            }
        }
        total = 0
        for (i = 1; i <= nnodes; i++) if (!(node_ids[i] in subgraphs)) total++
        if (total > max_nodes) finding(block_line, "diagram-nodes", total " nodes, max " max_nodes)
        if (edges > max_edges) finding(block_line, "diagram-edges", edges " edges, max " max_edges)
    }
    function count_messages(s, parts, n, i, count, part) {
        # Entity codes (#59;) end with the statement separator.
        gsub(/#[A-Za-z0-9]+;/, "", s)
        n = split(s, parts, /[\n;]/)
        count = 0
        for (i = 1; i <= n; i++) {
            part = parts[i]
            sub(/^[ \t]+/, "", part)
            # Not an actor named like a keyword: "Links->>B: x".
            if (tolower(part) !~ /^[a-z_]+[ \t]*(<<)?--?(>|x|\)|\|)[^:]*:/ && tolower(part) ~ /^(note|loop|alt|else|opt|par|par_over|and|critical|option|break|rect|box|title|participant|actor|create|destroy|links?|properties|details|activate|deactivate|acctitle|accdescr)([ \t:]|$)/) continue
            if (part ~ /^[^:]+(->|-x|-\)|-\||\/\/-|\\\\-)[^:]*:/) count++
        }
        return count
    }
    function count_bars(s, count, values, list) {
        gsub(/"[^"]*"/, "", s)
        count = 0
        while (match(s, /\n[ \t]*bar[ \t]*[^[\n]*\[[^]]*\]/)) {
            list = substr(s, RSTART + 1, RLENGTH - 1)
            s = substr(s, RSTART + RLENGTH)
            if (list !~ /^[ \t]*bar[ \t[]/) continue
            sub(/^[^[]*\[/, "", list)
            sub(/\]$/, "", list)
            count += split(list, values, ",")
        }
        return count
    }
    function check_mermaid(block_line, i, first, kind, in_config, n) {
        first = 0
        in_config = 0
        for (i = 1; i <= nbody; i++) {
            if (in_config) {
                if (body[i] ~ /^[ \t]*---[ \t]*$/ && in_config == 1) in_config = 0
                else if (body[i] ~ /\}%%/ && in_config == 2) in_config = 0
                continue
            }
            if (body[i] ~ /^[ \t]*---[ \t]*$/) { in_config = 1; continue }
            if (body[i] ~ /^[ \t]*%%\{/) { if (body[i] !~ /\}%%/) in_config = 2; continue }
            if (body[i] ~ /^[ \t]*(%%.*)?$/) continue
            first = i
            break
        }
        if (!first) return
        kind = body[first]
        sub(/^[ \t]+/, "", kind)
        sub(/[ \t;:].*$/, "", kind)
        if (kind ~ /^C4/ || kind == "timeline" || kind == "quadrantChart") {
            finding(block_line + first, "diagram-type", "Mermaid type " kind " is not allowed")
            return
        }
        T = ""
        T_LINE = block_line + first
        for (i = first; i <= nbody; i++) T = T (body[i] ~ /^[ \t]*%%/ ? "" : body[i]) "\n"
        if (kind ~ /^(flowchart|flowchart-elk|graph)$/) {
            sub(/^[ \t]*[a-z-]+[ \t]*/, "", T)
            sub(/^(TB|TD|BT|RL|LR|<|>|\^|v)[ \t]*/, "", T)
            check_flowchart(block_line)
        } else if (kind == "sequenceDiagram") {
            n = count_messages(T)
            if (n > max_messages) finding(block_line, "sequence-messages", n " messages, max " max_messages)
        } else if (kind ~ /^xychart/) {
            n = count_bars(T)
            if (n > max_bars) finding(block_line, "xychart-bars", n " bars, max " max_bars ": use a table")
        }
    }

    function close_fence() {
        open_len = 0
        if (lang == "mermaid") check_mermaid(open_line)
        if (is_diagram) caption_for = open_line
        paragraph = 0
    }
    BEGIN { allow = ENVIRON["ALLOW"]; quoted = 0; status = forced_status }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, "") }
    NR <= front_end {
        key = $0
        value = $0
        sub(/:.*/, "", key)
        sub(/^[^:]*:[ \t]*/, "", value)
        sub(/[ \t]+#.*$/, "", value)
        gsub(/^["\047]|["\047]?[ \t]*$/, "", value)
        front[key] = value
        if (key == "status" && status == "") status = tolower(value)
        else if (key == "reversibility") reversibility = value
        next
    }
    {
        line = $0
        was_quoted = quoted
        if (open_len == 0 && !in_comment) { quoted = sub(/^[ \t]*>([ \t]*>)*[ \t]?/, "", line) }
        else if (quoted) {
            # The quote ends, and its fence with it.
            if (!sub(/^[ \t]*>([ \t]*>)*[ \t]?/, "", line) && open_len > 0) { close_fence(); quoted = 0 }
        }
        if (quoted && !was_quoted) depth[1] = 0
        if (quoted != was_quoted) paragraph = 0
    }
    # The list item ends, and its fence with it.
    open_len > 0 && open_base > 0 && line !~ /^[ \t]*$/ && indent(line) < open_base { close_fence() }
    open_len > 0 {
        n = fence_len(line)
        # Closing fence: same character, at least as long, nothing after it.
        if (n >= open_len && fence_char == open_char && fence_rest ~ /^[ \t]*$/ && indent(line) - open_base <= 3) {
            close_fence()
            next
        }
        if (lang == "mermaid") body[++nbody] = line
        next
    }
    !in_comment { read_containers(line) }
    !in_comment && can_fence && (n = fence_len(content)) > 0 {
        open_len = n
        open_char = fence_char
        open_line = NR
        open_base = base
        paragraph = 0
        lang = tolower(fence_rest)
        sub(/^[ \t]*\{?[ \t]*\.?/, "", lang)
        sub(/[ \t{},].*$/, "", lang)
        nbody = 0
        is_diagram = (lang ~ /^(mermaid|d2|plantuml|puml|dot|graphviz)$/)
        if (is_diagram) new_diagram(NR)
        else if (caption_for) no_caption(caption_for)
        in_table = 0
        prev_row = ""
        open_code = 0
        next
    }
    {
        if (in_comment) indented = 0
        if (!indented) line = strip_comments(line)

        if (!indented && line ~ /^##?[ \t]/) {
            heading = tolower(line)
            sub(/^##?[ \t]+/, "", heading)
            sub(/[ \t#]+$/, "", heading)
            is_h2 = (line ~ /^##[ \t]/)
            in_summary = heading
            gsub(/\{[^}]*\}/, "", in_summary)
            in_summary = index(in_summary, "summary") > 0
            in_decisions = (is_h2 && heading == "decisions")
            # Written after the review, in the RFC template of this skill.
            own_section = (type == "rfc" && is_h2 && front["rfc"] ~ /^[0-9]+$/) ? heading : ""
        } else if (!indented && in_decisions && line ~ /^###[ \t]/) {
            decision_headings++
            if (decision_headings == max_decisions + 1) headings_line = NR
        }

        # The metadata list of a team template.
        if (status == "" && tolower(line) ~ /^[-*][ \t]+\**status\**:/) {
            status = tolower(line)
            gsub(/^[^:]*:|[* \t]/, "", status)
        }

        if (indented) { in_table = 0; prev_row = "" }
        else scan_table(line)

        text = line
        if (text ~ /^[ \t]*\[[^]^][^]]*\]:[ \t]/) text = ""
        gsub(/\]\([^)]*\)/, "]", text)
        if (in_table || text ~ /^[ \t]*\|/) gsub(/\|/, " ", text)
        not_counted = (own_section == "decision" || (own_section == "implementation" &&
            line ~ /^[ \t]*-[ \t]+[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ \t]+<?https?:\/\/[^ \t]+[ \t]*$/))
        if (!not_counted) total_words += words(text)
        if (max_words && total_words > max_words && !words_line) words_line = NR

        if (line ~ /^[ \t]*$/) in_legend = 0
        if (!indented && is_diagram_image(line)) {
            new_diagram(NR)
            caption_for = NR
            in_legend = 0
        } else if (caption_for && line !~ /^[ \t]*$/ && line !~ /^[ \t]*<\// && line !~ /^[ \t]*\[[^]^][^]]*\]:[ \t]/) {
            # A legend ends with its paragraph.
            if (tolower(line) ~ /^[ \t]*[*_]*legend[*_]*:/) in_legend = 1
            # A heading, list, table, rule, alert, image or HTML block is not a caption.
            else if (indented || line ~ /^[ \t]*(#+([ \t]|$)|\||[-*+][ \t]|[0-9]+[.)][ \t]|!\[|\[!|!!!|\?\?\?|===)/ || is_rule(line)) {
                no_caption(caption_for)
            } else if (!in_legend && line ~ /^[ \t]*<(p|div|center|span|figure|figcaption|sub|sup|em|strong|small|i|b)([ \t][^<>]*)?>/) {
                # An opening tag alone: its text is on the next line.
                if (words(line) > 0) caption_for = 0
            } else if (in_legend) caption_for = caption_for
            else if (line ~ /^[ \t]*<[A-Za-z]/ && line !~ /^[ \t]*<(a|code|kbd|mark|u|https?:)/) no_caption(caption_for)
            else if (words(line) == 0) no_caption(caption_for)
            else caption_for = 0
        }

        if (!indented) scan_codes(line)
    }
    END {
        if (mode == "rows") { print decision_rows + 0; exit }
        if (mode == "allowed") exit
        # Both have rfc: and adr:. The RFC also has track: and reversibility:, the ADR the RFC path.
        if (front["rfc"] ~ /^[0-9]+$/ && front["track"] != "" && front["reversibility"] != "") doc_type = "rfc"
        else if (front["adr"] ~ /^[0-9]+$/ && front["rfc"] ~ /^docs\/rfc\/[0-9]+-/) doc_type = "adr"
        if (front_unclosed) finding(1, "unclosed-block", "front matter never closed")
        if (doc_type != "" && doc_type != type)
            finding(1, "doc-type", "the front matter is the one of an " doc_type ", not of type " type)
        # A fence in a quote ends with the quote, and one in a list item with the list.
        if (open_len > 0 && quoted) close_fence()
        else if (open_len > 0) finding(open_line, "unclosed-block", "fence never closed")
        if (in_comment) finding(comment_line, "unclosed-block", "HTML comment never closed")
        if (caption_for) no_caption(caption_for)
        if (words_line) finding(words_line, "word-limit", total_words " words, max " max_words " for " type)
        if (diagrams_line) finding(diagrams_line, "diagram-count", diagrams " diagrams, max " max_diagrams " for " type)
        count_codes()
        for (i = 1; i <= nfamilies; i++) {
            f = families[i]
            if (code_uses[f] >= min_code_uses)
                finding(code_line[f], "invented-code", "family " f ", " code_uses[f] " uses (" code_list[f] "): link to a heading with a readable name")
        }
        if (type != "rfc") exit
        if (!table_line) finding(misplaced_line ? misplaced_line : 1, "decision-table", "no table with Decision, Why, Cost and Reversible columns in the Summary section" \
            (misplaced_line ? ": move this one" : ""))
        else if (!decision_rows) finding(table_line, "decision-table", "the decision table has no row")
        if (decision_headings > max_decisions || decision_rows > max_decisions) {
            n = decision_headings > decision_rows ? decision_headings : decision_rows
            finding(headings_line ? headings_line : table_line, "decision-cap", n " decisions, max " max_decisions ": write peer RFCs")
        }
    }
    '
}

# split_existing <base findings> <findings>: print each finding, after "existing" when the base has
# the same one or a worse count, else after "new".
split_existing() {
    LC_ALL=C awk '
        # Sets K (rule and message without the count), N (count) and C (codes of a family).
        function parse(s) {
            sub(/^[0-9]+: /, "", s)
            N = 0
            C = ""
            if (match(s, /^[a-z-]+: [0-9]+ /)) {
                N = substr(s, 1, RLENGTH)
                sub(/^[^:]*: /, "", N)
                N += 0
                sub(/: [0-9]+ /, ": ", s)
            } else if (s ~ /^invented-code: /) {
                match(s, /, [0-9]+ uses \([^)]*\)/)
                C = substr(s, RSTART + 2, RLENGTH - 2)
                N = C + 0
                sub(/^[^(]*\(/, "", C)
                sub(/\)$/, "", C)
                s = substr(s, 1, RSTART - 1)
            }
            K = s
        }
        function contains(all, some, parts, n, i) {
            n = split(some, parts, ", ")
            for (i = 1; i <= n; i++) if (!index(", " all ",", ", " parts[i] ",")) return 0
            return 1
        }
        $0 == "" { next }
        {
            parse($0)
            if (FILENAME == ARGV[1]) { nbase++; base_key[nbase] = K; base_n[nbase] = N; base_codes[nbase] = C }
            else { nhead++; head[nhead] = $0; key[nhead] = K; count[nhead] = N; codes[nhead] = C }
        }
        END {
            # Worst first, so that a count takes the worst base count of its kind.
            for (round = 1; round <= nhead; round++) {
                h = 0
                for (i = 1; i <= nhead; i++) if (!done[i] && (!h || count[i] > count[h])) h = i
                done[h] = 1
                best = 0
                for (i = 1; i <= nbase; i++)
                    if (!used[i] && base_key[i] == key[h] && base_n[i] >= count[h] && contains(base_codes[i], codes[h]) && (!best || base_n[i] > base_n[best])) best = i
                state[h] = best ? "existing" : "new"
                if (best) used[best] = 1
            }
            for (i = 1; i <= nhead; i++) print state[i] " " head[i]
        }
    ' "$1" "$2"
}

tmp="$(mktemp -d "${TMPDIR:-/tmp}/check-readability.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT

# base_findings <file>: print the findings of the version of the file in the base.
base_findings() {
    local dir name
    dir="$(dirname "$1")"
    name="$(basename "$1")"
    git -C "${dir}" rev-parse --verify --quiet "${base}^{commit}" > /dev/null 2>&1 || {
        ! git -C "${dir}" rev-parse --git-dir > /dev/null 2>&1 ||
            usage_error "--base: no commit '${base}' in the repository of '$1'"
        echo "notice: '$1' is not in a Git repository: every finding is new" >&2
        return 0
    }
    git -C "${dir}" cat-file -e "${base}:./${name}" 2> /dev/null || return 0
    git -C "${dir}" show "${base}:./${name}" > "${tmp}/document"
    # The base keeps its own status: --status is about the new version.
    check "${tmp}/document" "${dir}" ""
}

status=0
for file in "${files[@]}"; do
    if [[ "${mode}" != findings ]]; then
        scan "${file}" "$(dirname "${file}")" "${forced_status}" "${mode}" "" > "${tmp}/scan" ||
            usage_error "cannot check '${file}'"
        if [[ "${mode}" == allowed ]]; then cut -d ' ' -f 2 "${tmp}/scan"; else cat "${tmp}/scan"; fi
        continue
    fi
    check "${file}" "$(dirname "${file}")" "${forced_status}" > "${tmp}/findings" || usage_error "cannot check '${file}'"
    : > "${tmp}/base"
    if [[ -n "${base}" ]]; then
        base_findings "${file}" > "${tmp}/base" || exit 2
    fi
    split_existing "${tmp}/base" "${tmp}/findings" > "${tmp}/states" || usage_error "cannot compare '${file}'"
    blocking=false
    while read -r state finding; do
        if [[ "${state}" == new ]]; then
            printf '%s:%s\n' "${file}" "${finding}" >&2
            blocking=true
        else
            printf '%s:%s: existing: %s\n' "${file}" "${finding%%: *}" "${finding#*: }" >&2
        fi
    done < "${tmp}/states"
    if [[ "${blocking}" == true ]]; then
        status=1
    elif [[ -n "${base}" && -s "${tmp}/findings" ]]; then
        echo "ok: ${file} adds no finding to ${base}"
    else
        echo "ok: ${file} meets the ${type} readability limits"
    fi
done
exit "${status}"
