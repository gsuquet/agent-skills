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
      sets "site"; without it the key stays plain text and a warning is printed. Code spans and
      Markdown links are left as they are. --placeholder writes @NN for a draft not in map.tsv.
      --always prints the description also when the body names no ticket.

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

INLINE = re.compile(r"(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))")
# "ticket 05", "Tickets 05, 09 and 12": the word goes, each number becomes a key.
REFS = re.compile(r"\b(?i:tickets?) ([0-9]{2}(?:(?:,? and |,? or |, )[0-9]{2})*)\b")
NUM = re.compile(r"[0-9]{2}")
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


def inline(text, ref=None):
    """ADF text nodes of one line. ref, when set, rewrites "ticket NN" outside code and links."""
    nodes = []
    for part in INLINE.split(text):
        if not part:
            continue
        if part.startswith("`"):
            nodes.append(text_node(part[1:-1], [{"type": "code"}]))
        elif part.startswith("**"):
            nodes.extend(ref_nodes(part[2:-2], [{"type": "strong"}], ref))
        elif part.startswith("["):
            m = re.match(r"\[([^\]]+)\]\(([^)]+)\)", part)
            nodes.append(text_node(m.group(1), [{"type": "link", "attrs": {"href": m.group(2)}}]))
        else:
            nodes.extend(ref_nodes(part, [], ref))
    return nodes


def para(text, ref=None):
    return {"type": "paragraph", "content": inline(text, ref)}


def parse_list(lines, i, indent, ref=None):
    """Bullet, ordered and task lists, nested by indentation."""
    items, kind = [], None
    while i < len(lines):
        m = re.match(r"^(\s*)(- \[[ xX]\] |- |\d+\. )(.*)$", lines[i])
        if not m or len(m.group(1)) < indent:
            break
        if len(m.group(1)) > indent:
            if not items:
                die(f"list item indented without a parent: {lines[i]!r}")
            nested, i = parse_list(lines, i, len(m.group(1)), ref)
            items[-1].setdefault("content", []).append(nested)
            continue
        marker = m.group(2)
        k = "task" if marker.startswith("- [") else ("ordered" if marker[0].isdigit() else "bullet")
        kind = kind or k
        text = m.group(3)
        if k == "task":
            attrs = {"localId": uuid.uuid4().hex[:12], "state": "TODO" if marker == "- [ ] " else "DONE"}
            items.append({"type": "taskItem", "attrs": attrs, "content": inline(text, ref)})
        else:
            items.append({"type": "listItem", "content": [para(text, ref)]})
        i += 1
    if kind == "task":
        return {"type": "taskList", "attrs": {"localId": uuid.uuid4().hex[:12]}, "content": items}, i
    return {"type": "orderedList" if kind == "ordered" else "bulletList", "content": items}, i


def table(rows, ref=None):
    out = []
    for n, row in enumerate(rows):
        if n == 1 and re.fullmatch(r"\|[\s:|-]+\|?", row.strip()):
            continue  # header separator
        ctype = "tableHeader" if n == 0 else "tableCell"
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        out.append({"type": "tableRow", "content": [{"type": ctype, "content": [para(c, ref)]} for c in cells]})
    return {"type": "table", "attrs": {"isNumberColumnEnabled": False, "layout": "default"}, "content": out}


def to_adf(lines, ref=None):
    content, i = [], 0
    while i < len(lines):
        line = lines[i]
        heading = re.match(r"^(#{1,6}) (.*)$", line)
        if not line.strip():
            i += 1
        elif heading:
            level = {"level": len(heading.group(1))}
            content.append({"type": "heading", "attrs": level, "content": inline(heading.group(2), ref)})
            i += 1
        elif line.startswith("|"):
            j = i
            while j < len(lines) and lines[j].startswith("|"):
                j += 1
            content.append(table(lines[i:j], ref))
            i = j
        elif re.match(r"^(- |\d+\. )", line):
            node, i = parse_list(lines, i, 0, ref)
            content.append(node)
        else:
            content.append(para(line, ref))
            i += 1
    return {"type": "doc", "version": 1, "content": content}


# --- Config rules -------------------------------------------------------------------------------


def session_refs(text, cfg):
    """References that mean nothing outside the session, such as question numbers, outside code and URLs."""
    pattern = cfg.get("sessionRefs", cfg.get("stripRefs", SESSION_REFS))
    if not pattern:
        return []
    kept, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced:
            kept.append(re.sub(r"`[^`]+`|\]\([^)]+\)|\w+://\S+", " ", line))
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
    out = []
    for i, line in enumerate(kept):
        if line.startswith("#"):
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
