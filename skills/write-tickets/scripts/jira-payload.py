#!/usr/bin/env python3
"""Build the Jira payloads that publish-tickets.sh sends with acli, and rewrite the ticket
references of every tracker. No network call.

  jira-payload.py payload --kind spec|ticket --project KEY --title T --body FILE
                          [--config FILE] [--parent KEY] [--label NAME]...
      Print the JSON for `acli jira workitem create --from-json`: the Markdown body converted to
      Atlassian Document Format (ADF), labels, custom fields and the epic link from the config.

  jira-payload.py refs --body FILE --map MAP_TSV [--config FILE] [--placeholder] [--always]
      Print the ADF description with each "ticket NN" replaced by the key of draft NN in map.tsv,
      or nothing when the body names no ticket. The key links to <site>/browse/KEY when the config
      sets "site"; without it the key stays plain text and a warning is printed. Code spans, fenced
      code blocks and Markdown links are left as they are. --placeholder writes @NN for a draft not
      in map.tsv. --always prints the description also when the body names no ticket.

  jira-payload.py refs --format markdown --body FILE --map MAP_TSV [--placeholder]
      GitHub and GitLab: print the Markdown body with each "ticket NN" replaced by #<id> of draft
      NN, or nothing when the body names no ticket. Code spans, fenced code blocks and Markdown
      links are left as they are.

  jira-payload.py check --title T --body FILE [--config FILE]
      Fail when a session reference (Q23) is left; payload and refs (ADF) fail on it too.

  jira-payload.py digest --file JSON
      Print a short hash of {summary, description}, ignoring the ADF localId values.

The config keys are documented in ../references/trackers.md. Exit 1 on a bad config or body.
"""
import argparse
import hashlib
import json
import re
import sys
import uuid
from pathlib import Path

FENCE = re.compile(r"^(\s*)(`{3,}|~{3,})\s*([^\s`]*)[^`]*$")
HEADING = re.compile(r"^ {0,3}(#{1,6}) (.*)$")
RULE = re.compile(r"^ {0,3}(?:(?:-\s*){3,}|(?:\*\s*){3,}|(?:_\s*){3,})$")
ITEM = re.compile(r"^(\s*)([-*+]\s+\[[ xX]\]\s|[-*+]\s|\d{1,9}[.)]\s)(.*)$")
ROW = re.compile(r"^\s*\|.*\|")
QUOTE = re.compile(r"^\s*>\s?")
# A "Blocked by: 01" line: above the first "## " heading, it starts its own paragraph.
LABEL = re.compile(r"^[*_]{0,2}\w[\w '()/&-]{0,30}[*_]{0,2}:[*_]{0,2}\s")
INLINE = re.compile(r"(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))")
# "ticket 05", "Tickets 05, 09 and 12": the word goes, each number becomes a key.
REFS = re.compile(r"\b(?i:tickets?) ([0-9]{2}(?:(?:,? and |,? or |, )[0-9]{2})*)\b")
NUM = re.compile(r"[0-9]{2}")
# What these nodes hold in ADF. Any other block goes after them.
LIST_ITEM = {"paragraph", "bulletList", "orderedList", "taskList", "codeBlock"}
BLOCKQUOTE = {"paragraph", "bulletList", "orderedList", "codeBlock"}
SESSION_REFS = "Q[0-9]+"
# Ordinary text that looks like a question number: "Q4 2026", "2026-Q4", "Q1 and Q2 FY26".
_YEAR = r"(?:20\d\d|FY ?(?:20)?\d\d|['\u2019]\d\d)\b"
_QS = r"Q[1-4](?:\s*(?:,|and|or|to|/|-|\u2013)\s*Q[1-4])*\b"
QUARTER = re.compile(rf"\b{_QS}(?:\s+of)?[\s/-]*{_YEAR}|(?<!\w){_YEAR}[\s/-]*{_QS}")


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


# --- Markdown to ADF ----------------------------------------------------------------------------


def text_node(text, marks):
    node = {"type": "text", "text": text}
    if marks:
        node["marks"] = marks
    return node


def ref_nodes(text, marks, ref):
    """Text nodes of text, each "ticket NN" replaced by ref(NN): a (key, href or None) pair."""
    if ref is None:
        return [text_node(text, marks)]
    nodes, pos = [], 0
    for m in REFS.finditer(text):
        if m.start() > pos:
            nodes.append(text_node(text[pos:m.start()], marks))
        last = m.start(1)  # the word "ticket" goes
        for n in NUM.finditer(text, m.start(1), m.end(1)):
            if n.start() > last:
                nodes.append(text_node(text[last:n.start()], marks))  # ", " or " and "
            key, href = ref(n.group(0))
            link = [{"type": "link", "attrs": {"href": href}}] if href else []
            nodes.append(text_node(key, marks + link))
            last = n.end()
        pos = m.end()
    if pos < len(text):
        nodes.append(text_node(text[pos:], marks))
    return nodes


def hard_breaks(nodes):
    """The text nodes, each hard break of join_lines replaced by a hardBreak node."""
    out = []
    for node in nodes:
        for n, text in enumerate(re.split(r"[\n\r]", node["text"])):
            if n:
                out.append({"type": "hardBreak"})
            if text:
                out.append({**node, "text": text})
    return out


def inline(text, ref=None):
    """ADF nodes of one paragraph. ref, when set, rewrites "ticket NN" outside code and links."""
    nodes = []
    for part in INLINE.split(text):
        if not part:
            continue
        if not INLINE.fullmatch(part):  # also text that only starts like one: "[x] done", "**"
            nodes.extend(ref_nodes(part, [], ref))
        elif part.startswith("`"):
            code = part[1:-1].replace("\n", " ").replace("\r", "\\ ")  # no hard break in a code span
            nodes.append(text_node(code, [{"type": "code"}]))
        elif part.startswith("**"):
            nodes.extend(ref_nodes(part[2:-2], [{"type": "strong"}], ref))
        else:
            m = re.match(r"\[([^\]]+)\]\(([^)]+)\)", part)
            href = re.sub(r"[\x00-\x1f\x7f]", "", m.group(2)).strip()  # a wrapped URL holds hard breaks
            nodes.append(text_node(m.group(1), [{"type": "link", "attrs": {"href": href}}]))
    return hard_breaks(nodes)


def para(text, ref=None):
    return {"type": "paragraph", "content": inline(text, ref)}


def list_item(line):
    return None if RULE.match(line) else ITEM.match(line)


def is_block_start(line):
    """True for a line that ends a paragraph: blank, or the first line of another block."""
    return not line.strip() or any(r.match(line) for r in (HEADING, FENCE, RULE, ITEM, ROW, QUOTE))


def wraps_number(line):
    """True for wrapped prose that looks like an item: a list that interrupts a paragraph starts at 1."""
    item = list_item(line)
    return bool(item) and item_kind(item.group(2)) == "ordered" and (
        int(item.group(2).strip()[:-1]) != 1 and not fence_at(line))


def join_lines(text, lines, i, labels=False):
    """Join text and the hard-wrapped lines from i on. Returns the text and the next index.

    A hard break is kept as \\n (two spaces) or \\r (backslash): no line holds these characters.
    """
    text = text.lstrip()
    while i < len(lines) and (not is_block_start(lines[i]) or wraps_number(lines[i])) and not (
            labels and LABEL.match(lines[i])):
        if text.endswith("  "):
            text = text.rstrip() + "\n"
        elif re.search(r"(?<!\\)\\$", text):
            text = text[:-1] + "\r"
        else:
            text = text.rstrip() + " "
        text += lines[i].lstrip()
        i += 1
    return text.strip(), i


def fence_at(line):
    """The match of a fence that opens on the line, also after list markers."""
    while item := list_item(line):
        line = item.group(3).strip()
    return FENCE.match(line)


def fence_end(lines, i, fence):
    """The index of the line that closes the fence opened at line i. An unclosed fence runs to the end."""
    mark = fence.group(2)
    for j in range(i + 1, len(lines)):
        end = lines[j].strip()
        if len(end) >= len(mark) and set(end) == {mark[0]}:
            return j
    return len(lines)


def in_fence(lines):
    """For each line, whether it belongs to a fenced code block."""
    flags, i = [False] * len(lines), 0
    while i < len(lines):
        fence = fence_at(lines[i])
        end = fence_end(lines, i, fence) if fence else i
        if fence:
            flags[i:end + 1] = [True] * len(flags[i:end + 1])
        i = end + 1
    return flags


def indent_of(line):
    return len(line) - len(line.lstrip())


def dedent(line, width):
    return line[min(width, indent_of(line)):]


def code_block(lines, i):
    """The fenced block that starts at line i, and the next index."""
    fence = FENCE.match(lines[i])
    end = fence_end(lines, i, fence)
    code = [dedent(line, len(fence.group(1))) for line in lines[i + 1:end]]
    node = {"type": "codeBlock"}
    if fence.group(3):
        node["attrs"] = {"language": fence.group(3)}
    if any(code):
        node["content"] = [{"type": "text", "text": "\n".join(code)}]
    return node, end + 1


def item_kind(marker):
    if "[" in marker:
        return "task"
    return "ordered" if marker[0].isdigit() else "bullet"


def list_node(kind, items, start):
    if kind == "task":
        return {"type": "taskList", "attrs": {"localId": uuid.uuid4().hex[:12]}, "content": items}
    node = {"type": "orderedList" if kind == "ordered" else "bulletList", "content": items}
    if kind == "ordered" and start != 1:
        node["attrs"] = {"order": start}
    return node


def item_lines(lines, i, indent, labels):
    """The lines that belong to the list item at line i, without its own line, and the next index."""
    end = j = i + 1
    fence, wraps = fence_at(lines[i]), True
    if fence:
        end = j = fence_end(lines, i, fence) + 1
        wraps = False
    while j < len(lines):
        line = lines[j]
        if not line.strip():
            wraps, j = False, j + 1
            continue
        # A line that is not indented belongs to the item only as the next line of its paragraph.
        if indent_of(line) <= indent and (not wraps or is_block_start(line) or labels and LABEL.match(line)):
            break
        fence = fence_at(line)
        j = fence_end(lines, j, fence) + 1 if fence else j + 1
        wraps = not fence and (not is_block_start(line.strip()) or bool(list_item(line)))
        end = j
    return lines[i + 1:end], end


def item_blocks(match, rest, ref):
    """The blocks of one list item: the text of its own line is a paragraph, unless a fence opens on it."""
    start = len(match.group(1))
    width = start + len(re.match(r"\S+\s", match.group(2)).group(0))
    own = match.group(3).strip()
    fence = fence_at(own)
    first = next((indent_of(x) for x in rest if x.strip() and indent_of(x) > start), 0)
    inner = []
    for line, code in zip(rest, in_fence([own if fence else ""] + rest)[1:]):
        columns = len(line[:indent_of(line)].expandtabs(4))
        if not code and list_item(line) and columns < width:
            inner.append("")  # not indented as the text of the item: it starts a list, whatever its number
        inner.append(dedent(line, width if fence else min(width, first)))
    if fence:
        return blocks([own] + inner, ref)
    text, n = join_lines(match.group(3), inner, 0)
    return [para(text, ref)] + blocks(inner[n:], ref)


def as_paragraph(node):
    return {"type": "paragraph", "content": node["content"]} if node["type"] == "heading" else node


def parse_list(lines, i, ref=None, labels=False):
    """The bullet, ordered or task list at line i, as a list of blocks, and the next index.

    A change of kind ends the list. So does a block that an item cannot hold: it follows the list
    with the rest of its item, and the next items start a new list.
    """
    match = list_item(lines[i])
    indent, kind = len(match.group(1)), item_kind(match.group(2))
    number = int(match.group(2).strip()[:-1]) if kind == "ordered" else 1
    out, items = [], []
    while match and len(match.group(1)) == indent and item_kind(match.group(2)) == kind:
        rest, i = item_lines(lines, i, indent, labels)
        held = [as_paragraph(b) for b in item_blocks(match, rest, ref)]
        if kind == "task":  # a task item holds only text, and a nested task list is next to it
            text = held.pop(0)["content"] if held[0]["type"] == "paragraph" else []
            state = "TODO" if "[ ]" in match.group(2) else "DONE"
            attrs = {"localId": uuid.uuid4().hex[:12], "state": state}
            items.append({"type": "taskItem", "attrs": attrs, "content": text})
            n = next((n for n, b in enumerate(held) if b["type"] != "taskList"), len(held))
            items += held[:n]
        else:
            if held[0]["type"] not in ("paragraph", "codeBlock"):
                held.insert(0, para(""))  # a list item cannot start with a list
            n = next((n for n, b in enumerate(held) if b["type"] not in LIST_ITEM), len(held))
            items.append({"type": "listItem", "content": held[:n]})
        if held[n:]:
            out += [list_node(kind, items, number), *held[n:]]
            number, items = number + len(items), []
        while i < len(lines) and not lines[i].strip():
            i += 1
        match = list_item(lines[i]) if i < len(lines) else None
    return out + ([list_node(kind, items, number)] if items else []), i


def quote(inner):
    """The blocks of a quote. A block that a quote cannot hold splits it."""
    out = []
    for b in map(as_paragraph, inner):
        nested = b["type"] == "blockquote"
        if not nested and b["type"] not in BLOCKQUOTE:
            out.append(b)
            continue
        if not out or out[-1]["type"] != "blockquote":
            out.append({"type": "blockquote", "content": []})
        out[-1]["content"] += b["content"] if nested else [b]
    return out


def table(rows, ref=None):
    out = []
    for n, row in enumerate(rows):
        if n == 1 and re.fullmatch(r"\|[\s:|-]+\|?", row.strip()):
            continue  # header separator
        ctype = "tableHeader" if n == 0 else "tableCell"
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        out.append({"type": "tableRow", "content": [{"type": ctype, "content": [para(c, ref)]} for c in cells]})
    return {"type": "table", "attrs": {"isNumberColumnEnabled": False, "layout": "default"}, "content": out}


def blocks(lines, ref=None, labels=False):
    content, i = [], 0
    while i < len(lines):
        line = lines[i]
        heading = HEADING.match(line)
        if not line.strip():
            i += 1
        elif FENCE.match(line):
            node, i = code_block(lines, i)
            content.append(node)
        elif heading:
            level = {"level": len(heading.group(1))}
            content.append({"type": "heading", "attrs": level, "content": inline(heading.group(2), ref)})
            i += 1
        elif ROW.match(line):
            j = i
            while j < len(lines) and ROW.match(lines[j]):
                j += 1
            content.append(table(lines[i:j], ref))
            i = j
        elif RULE.match(line):
            content.append({"type": "rule"})
            i += 1
        elif QUOTE.match(line):
            j = i
            while j < len(lines) and QUOTE.match(lines[j]):
                j += 1
            content += quote(blocks([QUOTE.sub("", x) for x in lines[i:j]], ref))
            i = j
        elif ITEM.match(line):
            nodes, i = parse_list(lines, i, ref, labels)
            content += nodes
        else:
            text, i = join_lines(line, lines, i + 1, labels)
            content.append(para(text, ref))
    return content


def to_adf(lines, ref=None):
    first_section = next((n for n, (x, code) in enumerate(zip(lines, in_fence(lines)))
                          if x.startswith("## ") and not code), len(lines))
    content = blocks(lines[:first_section], ref, labels=True) + blocks(lines[first_section:], ref)
    return {"type": "doc", "version": 1, "content": content}


# --- Config rules -------------------------------------------------------------------------------


def session_refs(text, cfg):
    """References that mean nothing outside the session, such as question numbers, outside code and URLs."""
    pattern = cfg.get("sessionRefs", cfg.get("stripRefs", SESSION_REFS))
    if not pattern:
        return []
    lines = text.splitlines()
    kept = [re.sub(r"`[^`]+`|\]\([^)]+\)|\w+://\S+", " ", line)
            for line, code in zip(lines, in_fence(lines)) if not code]
    text = QUARTER.sub(" ", "\n".join(kept))
    return sorted({m.group(0) for m in re.finditer(rf"\b(?:{pattern})\b", text)})


def refuse_session_refs(text, cfg, where):
    left = session_refs(text, cfg)
    if left:
        die(f"{where}: session reference {', '.join(left)}: write what it refers to instead "
            "(a quarter needs its year: Q4 2026)")


def load_config(path):
    if not path:
        return {}
    try:
        cfg = json.loads(Path(path).read_text())
    except (OSError, json.JSONDecodeError) as e:
        die(f"cannot read config {path}: {e}")
    link = cfg.get("epicLink", {"mode": "parent"})
    if link.get("mode") not in ("parent", "field") or (link["mode"] == "field" and not link.get("field")):
        die(f"{path}: epicLink must be {{\"mode\": \"parent\"}} or {{\"mode\": \"field\", \"field\": \"customfield_...\"}}")
    site = cfg.get("site")
    if site is not None and not re.fullmatch(r"https://[^/\s]+/?", str(site)):
        die(f"{path}: site must be the base URL of the Jira site, for example https://example.atlassian.net")
    patterns = [cfg.get("sessionRefs") or "", cfg.get("stripRefs") or "", *cfg.get("dropLines", [])]
    patterns += [r.get("pattern", "") for r in cfg.get("titleLabels", [])]
    for pattern in patterns:
        try:
            re.compile(pattern)
        except re.error as e:
            die(f"{path}: bad regular expression {pattern!r}: {e}")
    return cfg


def body_lines(path, cfg):
    """The rendered draft body without the lines that match dropLines. A heading left empty goes."""
    lines = Path(path).read_text().splitlines()
    drop = [re.compile(p) for p in cfg.get("dropLines", [])]
    kept = [line for line in lines if not any(p.search(line) for p in drop)]
    out, code = [], in_fence(kept)
    for i, line in enumerate(kept):
        if not code[i] and line.startswith("#"):
            nxt = next((x for x in kept[i + 1:] if x.strip()), None)
            if nxt is None or nxt.startswith("#") and len(nxt.split()[0]) <= len(line.split()[0]):
                continue
        out.append(line)
    return lines, out


def ticket_labels(raw, title, cfg, extra):
    labels = list(cfg.get("labels", []))
    header = raw[: next((i for i, x in enumerate(raw) if x.startswith("## ")), len(raw))]
    for key in cfg.get("metaLabels", []):
        for line in header:
            m = re.search(rf"(?:^|·)\s*{re.escape(key)}:\s*([^·]+)", line)
            if m:
                labels.append(re.sub(r"\s+", "-", m.group(1).strip().lower()))
                break
    for rule in cfg.get("titleLabels", []):
        if re.search(rule["pattern"], title):
            labels.append(rule["label"])
    return list(dict.fromkeys(labels + extra))


# --- Commands -----------------------------------------------------------------------------------


def payload(args):
    cfg = load_config(args.config)
    raw, lines = body_lines(args.body, cfg)
    refuse_session_refs("\n".join([args.title, *lines]), cfg, args.title)
    adf = to_adf(lines)
    epic = cfg.get("epic", {})
    if args.kind == "spec":
        kind, labels = epic.get("type", "Epic"), list(epic.get("labels", []))
    else:
        kind, labels = cfg.get("issueType", "Task"), ticket_labels(raw, args.title, cfg, args.label)
    p = {"projectKey": args.project, "type": kind, "summary": args.title.replace("`", ""),
         "labels": labels, "description": adf}
    attrs = dict(cfg.get("fields", {}))
    if args.parent:
        link = cfg.get("epicLink", {"mode": "parent"})
        if link["mode"] == "field":
            attrs[link["field"]] = args.parent
        else:
            p["parentIssueId"] = args.parent
    if attrs:
        p["additionalAttributes"] = attrs
    json.dump(p, sys.stdout, ensure_ascii=False)


def markdown_refs(path, ref):
    """The Markdown body with each "ticket NN" outside code and links replaced by ref(NN)."""
    out, fenced, found = [], False, False

    def sub(m):
        nonlocal found
        found = True
        return NUM.sub(lambda n: ref(n.group(0)), m.group(1))

    for line in Path(path).read_text().splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
        if not fenced:
            parts = INLINE.split(line)
            line = "".join(x if x.startswith(("`", "[")) else REFS.sub(sub, x) for x in parts)
        out.append(line)
    return "\n".join(out) + "\n" if found else ""


def refs(args):
    if args.format == "markdown" and args.config:
        die("--config is only valid with --format adf")
    cfg = load_config(args.config)
    site = (cfg.get("site") or "").rstrip("/")
    keys = {}
    for row in Path(args.map).read_text().splitlines() if Path(args.map).exists() else []:
        cols = row.split("\t")
        if len(cols) >= 2 and re.fullmatch(r"[0-9]{2}", cols[0]):
            keys[cols[0]] = cols[1]

    found = []

    def ref(num):
        if num in keys:
            key = keys[num]
        elif args.placeholder:
            key = f"@{num}"
        else:
            die(f"draft {num} is not in {args.map}: publish every ticket before rewriting references")
        found.append(key)
        if args.format == "markdown":
            return key if key.startswith("@") else f"#{key}"
        # A link mark, not an inlineCard: it renders without smart-link resolution.
        return key, f"{site}/browse/{key}" if site else None

    if args.format == "markdown":
        sys.stdout.write(markdown_refs(args.body, ref))
        return
    _, lines = body_lines(args.body, cfg)
    refuse_session_refs("\n".join(lines), cfg, args.body)
    adf = to_adf(lines, ref)
    if not found and not args.always:
        return
    if found and not site:
        print(f"warning: {args.body}: no \"site\" in the config, so {', '.join(sorted(set(found)))} stay plain keys "
              "(add \"site\" to link them)", file=sys.stderr)
    json.dump(adf, sys.stdout, ensure_ascii=False)


def check(args):
    cfg = load_config(args.config)
    _, lines = body_lines(args.body, cfg)
    refuse_session_refs("\n".join([args.title, *lines]), cfg, args.title)


def without_local_ids(node):
    if isinstance(node, dict):
        return {k: without_local_ids(v) for k, v in node.items() if k != "localId"}
    return [without_local_ids(x) for x in node] if isinstance(node, list) else node


def digest(args):
    doc = without_local_ids(json.loads(Path(args.file).read_text()))
    print(hashlib.sha256(json.dumps(doc, sort_keys=True).encode()).hexdigest()[:16])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("payload")
    p.add_argument("--kind", required=True, choices=["spec", "ticket"])
    p.add_argument("--project", required=True)
    p.add_argument("--title", required=True)
    p.add_argument("--body", required=True)
    p.add_argument("--config")
    p.add_argument("--parent")
    p.add_argument("--label", action="append", default=[])
    r = sub.add_parser("refs")
    r.add_argument("--body", required=True)
    r.add_argument("--map", required=True)
    r.add_argument("--config")
    r.add_argument("--placeholder", action="store_true")
    r.add_argument("--always", action="store_true")
    r.add_argument("--format", choices=["adf", "markdown"], default="adf")
    c = sub.add_parser("check")
    c.add_argument("--title", required=True)
    c.add_argument("--body", required=True)
    c.add_argument("--config")
    h = sub.add_parser("digest")
    h.add_argument("--file", required=True)
    args = ap.parse_args()
    {"payload": payload, "refs": refs, "check": check, "digest": digest}[args.cmd](args)


if __name__ == "__main__":
    main()
