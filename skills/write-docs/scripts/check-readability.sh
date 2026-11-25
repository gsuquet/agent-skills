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

usage() {
    cat << EOF
Usage: check-readability.sh --type <type> [--allow-code <regex>]... <file>...

Checks Markdown documents, whatever their template, against the readability limits. Prints one
"file:line: rule: message" line per finding on stderr, or one "ok" line per file on stdout.

Types: rfc, adr, concept, how-to, runbook, readme, study-index, reference, tutorial, other.

  word-limit         words outside fenced blocks, front matter, HTML comments and link targets;
                     prose, headings, tables and the metadata list count. Max:
                       rfc ${MAX_WORDS_RFC}, adr ${MAX_WORDS_ADR}, concept ${MAX_WORDS_CONCEPT}, how-to ${MAX_WORDS_HOW_TO}, runbook ${MAX_WORDS_RUNBOOK},
                       readme ${MAX_WORDS_README}, study-index ${MAX_WORDS_STUDY_INDEX}; reference, tutorial, other: no limit
  diagram-count      diagrams in the document, max: rfc ${MAX_DIAGRAMS_RFC}, adr ${MAX_DIAGRAMS_ADR}; others: no limit. A diagram
                     is a mermaid, d2, plantuml or dot block, or a local .svg or .excalidraw image
                     on its own line
  diagram-nodes      nodes of a Mermaid flowchart, subgraphs not counted, max: ${MAX_NODES}
  diagram-edges      visible edges of a Mermaid flowchart ("a & b --> c" has 2), max: ${MAX_EDGES}
  diagram-label      words of a node, edge or subgraph label of a Mermaid flowchart, max: ${MAX_LABEL_WORDS}
  sequence-messages  messages of a Mermaid sequence diagram, max: ${MAX_MESSAGES}
  xychart-bars       bars of a Mermaid xychart, all series together, max: ${MAX_BARS}
  diagram-caption    the first text under each diagram must be a paragraph; a "Legend:" line does
                     not count as the caption
  diagram-type       Mermaid C4*, timeline and quadrantChart are not allowed
  invented-code      a family of 1 or 2 capital letters and a number (D7, WP2), used ${MIN_CODE_USES} times or
                     more; inline code, fenced blocks, URLs and link targets are skipped
  decision-table     rfc only: needs a table whose header has Decision, Why, Cost and Reversible,
                     with at least 1 row
  decision-reversible  rfc only: each Reversible cell holds an answer: not empty, not a dash, not
                     "not stated", "not assessed", "unknown" or "TBD"
  decision-cap       rfc only: rows of the decision tables, and "### " headings of "## Decisions",
                     max: ${MAX_DECISIONS} each; above that, split into peer RFCs
  unclosed-block     a fence, front matter or HTML comment that never closes hides text

Not checked here: repetition, caption quality, legend and colors. Review them by hand.

Options:
  --type <type>         type of every file given (required)
  --allow-code <regex>  real name that is not an invented code; matches the whole code, for
                        example 'S3' or 'Q[1-4]' (repeatable, awk regex)
  -h, --help            show this help

Exit codes: 0 pass, 1 findings, 2 usage error.
EOF
}

usage_error() {
    echo "error: $1" >&2
    exit 2
}

type=""
allow=""
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
            RE="^($2)\$" awk 'BEGIN { if ("" ~ ENVIRON["RE"]) exit; exit }' 2> /dev/null ||
                usage_error "--allow-code: invalid regex '$2'"
            allow="${allow:+${allow}|}($2)"
            shift 2
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

# check <file>: print one "line: rule: message" per finding, sorted by line. The awk program avoids regex intervals ({n,m}) and
# gawk-only features so that the BSD awk of macOS runs it too.
check() {
    LC_ALL=C ALLOW="${allow}" awk -v type="${type}" \
        -v max_words="${max_words}" -v max_diagrams="${max_diagrams}" \
        -v max_nodes="${MAX_NODES}" -v max_edges="${MAX_EDGES}" \
        -v max_label="${MAX_LABEL_WORDS}" -v max_messages="${MAX_MESSAGES}" \
        -v max_bars="${MAX_BARS}" -v max_decisions="${MAX_DECISIONS}" \
        -v min_code_uses="${MIN_CODE_USES}" '
    function finding(line, rule, message) {
        printf "%d: %s: %s\n", line, rule, message
    }
    # Number of whitespace-separated tokens that hold more than punctuation.
    function words(s, parts, n, i, count) {
        gsub(/<[bB][rR][ \t]*\/?>/, " ", s)
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
                if (!i) return out
                in_comment = 0
                s = substr(s, i + 3)
                continue
            }
            i = index(s, "<!--")
            if (!i) return out s
            out = out substr(s, 1, i - 1)
            # Inside inline code: literal text.
            if (count_char(out, "`") % 2) { out = out "<!--"; s = substr(s, i + 4); continue }
            in_comment = 1
            comment_line = NR
            s = substr(s, i + 4)
        }
        return out
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
    function is_diagram_image(s, target) {
        if (s !~ /^[ \t]*(\[?!\[|<img[ \t])/) return 0
        if (match(s, /!\[[^]]*\]\([^ \t)]*/)) {
            target = substr(s, RSTART, RLENGTH)
            sub(/^!\[[^]]*\]\(/, "", target)
        } else if (match(s, /src="[^"]*"/)) {
            target = substr(s, RSTART + 5, RLENGTH - 6)
        } else return 0
        if (target ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || target ~ /^\/\//) return 0
        sub(/[?#].*$/, "", target)
        return tolower(target) ~ /\.(svg|excalidraw|excalidraw\.png)$/
    }
    # Record the invented codes of a line of text.
    function scan_codes(s, i, code, before, before2, after, family) {
        if (s ~ /^[ \t]*$/) { open_code = 0; return }
        # Inline code that started on the line before.
        if (open_code && (i = index(s, "`"))) s = substr(s, i + 1)
        open_code = 0
        gsub(/``[^`]*``/, " ", s)
        gsub(/`[^`]*`/, " ", s)
        if (s ~ /^[ \t]*\[[^]]*\]:/) return
        if ((i = index(s, "`")) > 0) {
            open_code = 1
            s = substr(s, 1, i - 1)
        }
        gsub(/\]\([^)]*\)/, "] ", s)
        gsub(/\]\[[^]]*\]/, "] ", s)
        gsub(/[A-Za-z][A-Za-z0-9+.-]*:\/\/[^ \t<>)|]*/, " ", s)
        gsub(/<\/?[A-Za-z][^<>]*>/, " ", s)
        s = "  " s " "
        while (match(s, /[A-Z][A-Z]?[0-9]+/)) {
            code = substr(s, RSTART, RLENGTH)
            before = substr(s, RSTART - 1, 1)
            before2 = substr(s, RSTART - 2, 1)
            after = substr(s, RSTART + RLENGTH, 1)
            # Keep two characters, for the context of the next code.
            s = substr(s, RSTART + RLENGTH - 2)
            if (before ~ /[A-Za-z0-9_.#]/ || after ~ /[A-Za-z0-9_]/) { s = "  " substr(s, 3); continue }
            # A range or a list (B1-B5, T1/T2) holds codes, other compound names do not.
            if (before ~ /[-\/]/ && before2 !~ /[0-9]/) { s = "  " substr(s, 3); continue }
            # Replace the code by a digit: it is not matched again.
            s = " 0" substr(s, 3)
            if (ENVIRON["ALLOW"] != "" && code ~ ("^(" ENVIRON["ALLOW"] ")$")) continue
            family = code
            sub(/[0-9]+$/, "", family)
            if (!(family in code_uses)) { families[++nfamilies] = family; code_line[family] = NR }
            code_uses[family]++
            if (!((family, code) in code_seen)) {
                code_seen[family, code] = 1
                code_list[family] = code_list[family] (code_list[family] == "" ? "" : ", ") code
            }
        }
    }
    # Decision tables: the header is known when the delimiter row under it is read.
    function cell(s, column, parts) {
        gsub(/\\\|/, "\001", s)
        sub(/^[ \t]*\|/, "", s)
        split(s, parts, "|")
        return parts[column]
    }
    function check_reversible(value, shown) {
        shown = value
        gsub(/^[ \t]+|[ \t]+$/, "", shown)
        value = tolower(shown)
        gsub(/<[^<>]*>|&nbsp;|\302\240/, "", value)
        gsub(/&[mn]dash;|\342\200[\220-\225]|\342\210\222/, "-", value)
        gsub(/[*_`~. \t]+/, " ", value)
        gsub(/^ | $/, "", value)
        if (value ~ /^[ -]*$/ || value ~ /^(not stated|not assessed|unknown|tbd)([^a-z0-9]|$)/)
            finding(NR, "decision-reversible", "Reversible cell " (shown == "" ? "is empty" : "says " shown) ": write yes or no, and how")
    }
    function scan_table(s, header, n) {
        if (s !~ /\|/) { in_table = 0; prev_row = ""; return }
        if (in_table) {
            if (in_table == 2) {
                decision_rows++
                if (type == "rfc") check_reversible(cell(s, reversible_column))
            }
            return
        }
        if (prev_row != "" && s ~ /^[ \t|:-]*-[ \t|:-]*$/) {
            header = tolower(prev_row)
            in_table = 1
            if (header ~ /decision/ && header ~ /why/ && header ~ /cost/ && header ~ /reversib/) {
                in_table = 2
                n = 0
                while (cell(header, ++n) !~ /reversib/) if (n > 50) break
                reversible_column = n
                if (!table_line) table_line = NR - 1
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
        gsub(/\\n/, " ", s)
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
            if (match(s, /\|/)) {
                P += RSTART + 1
                check_label(label_of(substr(s, 1, RSTART - 1)), pos)
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
            if (tolower(part) ~ /^(note|loop|alt|else|opt|par|par_over|and|critical|option|break|rect|box|title|participant|actor|create|destroy|links?|properties|details|activate|deactivate|acctitle|accdescr)([ \t:]|$)/) continue
            if (part ~ /^[^:]+(->|-x|-\)|-\||\/\/-|\\\\-)[^:]*:/) count++
        }
        return count
    }
    function count_bars(s, parts, n, i, count, values) {
        n = split(s, parts, "\n")
        count = 0
        for (i = 1; i <= n; i++) {
            if (parts[i] !~ /^[ \t]*bar[ \t"[]/ || !match(parts[i], /\[[^]]*\]/)) continue
            count += split(substr(parts[i], RSTART + 1, RLENGTH - 2), values, ",")
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

    { sub(/\r$/, "") }
    NR == 1 && $0 == "---" { in_front = 1; next }
    in_front { if ($0 == "---") in_front = 0; next }
    {
        line = $0
        if (open_len == 0 && !in_comment) { quoted = sub(/^[ \t]*>([ \t]*>)*[ \t]?/, "", line) }
        else if (quoted) sub(/^[ \t]*>([ \t]*>)*[ \t]?/, "", line)
    }
    open_len > 0 {
        n = fence_len(line)
        # Closing fence: same character, at least as long, nothing after it.
        if (n >= open_len && fence_char == open_char && fence_rest ~ /^[ \t]*$/) {
            open_len = 0
            if (lang == "mermaid") check_mermaid(open_line)
            if (is_diagram) caption_for = open_line
            next
        }
        if (lang == "mermaid") body[++nbody] = line
        next
    }
    !in_comment && (n = fence_len(line)) > 0 {
        open_len = n
        open_char = fence_char
        open_line = NR
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
        line = strip_comments(line)

        text = line
        if (text ~ /^[ \t]*\[[^]]*\]:[ \t]/) text = ""
        gsub(/\]\([^)]*\)/, "]", text)
        total_words += words(text)
        if (max_words && total_words > max_words && !words_line) words_line = NR

        if (is_diagram_image(line)) {
            new_diagram(NR)
            caption_for = NR
        } else if (caption_for && line !~ /^[ \t]*$/ && line !~ /^[ \t]*<\// && tolower(line) !~ /^[ \t]*[*_]*legend[*_]*:/) {
            # A heading, list, table, rule, alert, image or HTML block is not a caption.
            if (line ~ /^[ \t]*(#|\||[-*+][ \t]|[0-9]+[.)][ \t]|---|\*\*\*|___|!\[|\[!|<)/ || words(line) == 0) no_caption(caption_for)
            caption_for = 0
        }

        scan_codes(line)
        scan_table(line)

        if (line ~ /^##?[ \t]/) in_decisions = (tolower(line) ~ /^##[ \t]+decisions[ \t#]*$/)
        else if (in_decisions && line ~ /^###[ \t]/) {
            decision_headings++
            if (decision_headings == max_decisions + 1) headings_line = NR
        }
    }
    END {
        if (in_front) finding(1, "unclosed-block", "front matter never closed")
        if (open_len > 0) finding(open_line, "unclosed-block", "fence never closed")
        if (in_comment) finding(comment_line, "unclosed-block", "HTML comment never closed")
        if (caption_for) no_caption(caption_for)
        if (words_line) finding(words_line, "word-limit", total_words " words, max " max_words " for " type)
        if (diagrams_line) finding(diagrams_line, "diagram-count", diagrams " diagrams, max " max_diagrams " for " type)
        for (i = 1; i <= nfamilies; i++) {
            f = families[i]
            if (code_uses[f] >= min_code_uses)
                finding(code_line[f], "invented-code", "family " f ", " code_uses[f] " uses (" code_list[f] "): link to a heading with a readable name")
        }
        if (type != "rfc") exit
        if (!table_line) finding(1, "decision-table", "no table with Decision, Why, Cost and Reversible columns")
        else if (!decision_rows) finding(table_line, "decision-table", "the decision table has no row")
        if (decision_headings > max_decisions || decision_rows > max_decisions) {
            n = decision_headings > decision_rows ? decision_headings : decision_rows
            finding(headings_line ? headings_line : table_line, "decision-cap", n " decisions, max " max_decisions ": write peer RFCs")
        }
    }
    ' < "$1" | sort -s -n -k1,1
}

status=0
for file in "${files[@]}"; do
    findings="$(check "${file}")" || usage_error "cannot check '${file}'"
    if [[ -n "${findings}" ]]; then
        while IFS= read -r finding; do
            printf '%s:%s\n' "${file}" "${finding}" >&2
        done <<< "${findings}"
        status=1
    else
        echo "ok: ${file} meets the ${type} readability limits"
    fi
done
exit "${status}"
