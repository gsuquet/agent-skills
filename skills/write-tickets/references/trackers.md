# Trackers

The commands `scripts/publish-tickets.sh` runs on each tracker, and what is known about them.
"In `--help`" means the flag is listed by the `--help` of the version named; it was not run against
a live tracker. Everything marked `(unverified)` comes from documentation or memory only.

## map.tsv

One row per published item, tab-separated: `<draft> <id> <url>`. Special rows: `tracker <name>
<project>` (written first; a re-run on another tracker stops) and, on GitLab, `spec-tasks <count>`
(how many tickets the spec task list holds), and `refs-NN 1 -` (the body of ticket NN had its
`ticket NN` references rewritten) and, on Jira, `base-NN <Jira version> <draft version>` (hashes of
the title and description read back right after the script wrote them, for `--sync`). To recover from an issue created without a row (the script says
so and exits 4), add its row by hand, then re-run. To rewrite the references again (for example
after adding `site` to the config), delete the `refs-NN` rows, then re-run: the script skips every
published draft and rewrites only those descriptions.

## GitHub (`gh` 2.103.3)

GitHub links `#26` to issue or pull request 26 of the same repository, and `owner/repo#26` to
another repository
([autolinked references](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls)).

| Operation | Command | Status |
| --- | --- | --- |
| Create | `gh issue create --title <t> --body-file <f>` | in `--help` |
| Parent | `--parent <spec>`: the ticket is a sub-issue of the spec | in `--help` |
| Blocking | `--blocked-by <n>,<n>` | in `--help` |
| Labels | `--label <name>`, repeated; existence checked with `gh label list --json name` | in `--help` |
| Ticket references | `gh issue edit <n> --body-file <f>`, `<f>` with each `ticket NN` rewritten to `#<n>` by `scripts/jira-payload.py refs --format markdown` | in `--help` |
| Issue id | last `https://.../issues/<n>` URL in the output | output format (unverified) |

- Sub-issues and issue dependencies need the repository to have them enabled; a repository without
  them refuses `--parent` or `--blocked-by` (unverified). Whether `gh` creates the issue before it
  fails on the relationship is unverified: the script records any issue URL it finds in the output
  and warns.

## GitLab (`glab` 1.126.0)

GitLab Flavored Markdown links `#123` (issue), `!123` (merge request) and
`namespace/project#123` or `namespace/project!123` (another project) of the same GitLab
instance ([GitLab-specific references](https://docs.gitlab.com/user/markdown/#gitlab-specific-references)).
On another forge or on Jira these are plain text, hence full URLs in the drafts.

| Operation | Command | Status |
| --- | --- | --- |
| Create | `glab issue create --title <t> --description-file <f> --yes` | in `--help` |
| Parent | `--linked-issues <spec> --link-type relates_to`, then `glab issue update <spec> --description-file <f>` with a `## Tickets` task list `- [ ] #<iid>` | in `--help` |
| Blocking | `Blocked by: #<iid>` line in the description, always; then `glab api --method POST projects/:id/issues/<iid>/links -F target_project_id=<id> -F target_issue_iid=<blocker> -f link_type=is_blocked_by` | `glab api` in `--help`; the endpoint and `link_type` values from the GitLab issue links API (unverified) |
| Project id | `glab api projects/:id`, field `.id` | `:id` placeholder in `--help` |
| Labels | `--label <name>`, repeated; existence checked with `glab label list --output json`, page by page | in `--help` |
| Ticket references | `glab issue update <iid> --description-file <f>`, `<f>` with each `ticket NN` rewritten to `#<iid>` | in `--help` |
| Issue id | last `https://.../-/issues/<n>` URL in stdout or stderr | output format (unverified) |

Tier limits, all (unverified):

- `blocks` and `is_blocked_by` link types need GitLab Premium; Free accepts only `relates_to`. On
  Free the script warns once per refused link and the `Blocked by:` line carries the edge.
- Epics (`glab issue create --epic`) need Premium; the script does not use them.
- Self-managed instances may run older API versions that lack the issue links endpoint.

## Jira (`acli` 1.3.40)

| Operation | Command | Status |
| --- | --- | --- |
| Auth | `acli jira auth login` once per machine | (unverified) |
| Create | `acli jira workitem create --from-json <f> --json`; `<f>` from `scripts/jira-payload.py`: `{projectKey, type, summary, labels, description (ADF), parentIssueId, additionalAttributes}` | in `--generate-json` |
| Parent | `parentIssueId` (default), or the epic key in a custom field (`epicLink` in the config) | in `--generate-json`; that either one sets the epic is unverified |
| Custom fields | `additionalAttributes: {"customfield_<id>": <value>}` | in `--generate-json` |
| Blocking | `Blocked by: <KEY>-<n>` line in the description, always; then `acli jira workitem link create --out <ticket> --in <blocker> --type Blocks --yes` (`--in` blocks `--out`: see below) | run |
| Link check | `acli jira workitem view <ticket> --json --fields issuelinks`: links at `.fields.issuelinks[]`, each with `id`, `type.name` and one of `inwardIssue` (it blocks the ticket) or `outwardIssue` (the ticket blocks it) | run |
| Link delete | `acli jira workitem link delete --id <link-id> --yes` | run |
| Sync | `acli jira workitem view <key> --json --fields summary,description`, then `acli jira workitem edit --key <key> --summary <t> --description-file <adf.json> --yes` | the JSON shape and `--summary` (unverified): the script stops when a field is missing, and checks the title after the edit |
| Link types | `acli jira workitem link type` lists the names the site accepts (`Blocks`, `Relates`, ...) | run |
| Ticket references | `acli jira workitem edit --key <key> --description-file <adf.json> --yes` | in `--help` |
| Labels | `labels` in the payload; no existence check: Jira creates a label on first use | (unverified) |
| Issue key | `.key` of the JSON printed by `--json` | (unverified) |

- The description is converted from Markdown to Atlassian Document Format: headings, lists, task
  lists, tables, quotes, rules, fenced code blocks, hard breaks, inline code, bold, links.
  Hard-wrapped lines are joined, also one that starts with a number other than 1 (`13) to merge`)
  when it is indented as the paragraph it continues. Above the first `## ` heading, a line that starts with a label
  (`Name: value`, `Name (team): value` or `**Name:** value`, with no indentation and a name of at
  most 31 characters) starts its own paragraph.
- A change of list kind starts a new list. A block that its container cannot hold follows it, and
  the next items or lines start a new list or quote: a task item holds only text and task lists, a
  list item no table, quote or rule, a quote no table, task list or rule. A heading in a list item
  or a quote becomes a paragraph.
- Not converted, the text is kept: indented code, underlined (`===`) headings, tables whose rows do
  not start with `|`, reference links and HTML are joined like a paragraph. A checkbox after a number
  (`1. [ ] a`) or without text (`- [ ]`) stays text.
- That Jira renders an ADF description sent through
  `--from-json` or `--description-file` is unverified: publish with `--max 1` first and check it.
- `parentIssueId` is documented for sub-tasks. A project where Tasks cannot take an Epic parent
  refuses it; some sites set the epic through an Epic Link custom field instead (unverified).
- The URL column of `map.tsv` holds `<site>/browse/<KEY>` when the config sets `site`, `-`
  otherwise.
- Once every ticket is published, the script rewrites `ticket 05`, `Ticket 05` and `tickets 05, 09
  and 12` in each description with the keys (map.tsv row `refs-NN`): no key exists before its
  ticket. Each key is a text node with a `link` mark to `<site>/browse/<KEY>`
  ([link mark](https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/link/)),
  not an `inlineCard`, which Jira renders as a smart link card resolved from the URL
  ([inlineCard](https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/inlineCard/)).
  Code spans, fenced code blocks and Markdown links are left as they are. Without `site`, the key stays plain text and
  the script warns: whether Jira links a plain key in an ADF text node is (unverified), as the ADF
  reference does not say.

### acli link quirks (observed with acli 1.3.40)

- `acli jira workitem link create --out X --in Y --type Blocks` makes **Y block X**, yet its success
  message prints "X Blocks Y". The script passes the blocker as `--in` and the blocked ticket as
  `--out`, prints the intended "A blocks B" in the dry run, and reads back the first link of each run:
  it exits 4 when Jira shows that link inverted. Never judge a link by the success message.
- `acli jira workitem link delete --id <link-id>` without `--yes` asks for confirmation and waits on
  the prompt forever when stdin is not a terminal.

### Inverted Blocks links

The `Blocked by:` lines of the drafts give the direction, not the ticket numbers: a ticket added
later can block a lower number. Run the script with `--verify-links`: it prints each inverted link,
and `--apply` deletes it and creates it the right way round.

### Sync limits

- Jira has no conditional edit: a change made between the last read and the write of one issue is
  overwritten.
- An issue published before `base-NN` rows existed is a conflict as soon as it differs from its draft.
- A new version of the converter changes the description of an unchanged draft, so `--sync` lists it
  as an edit, or as a conflict when the issue was edited on Jira since.
- `--sync` writes the title and the description only. Labels, fields and the epic stay as they are.

### Jira config (`--config <file.json>`)

Project rules that flags do not cover. Every key is optional; start from
[../assets/jira-config.json](../assets/jira-config.json). Regular expressions in `ignore` and
`titlePrefix` use jq syntax, the others Python syntax.

| Key | Effect |
| --- | --- |
| `site` | Base URL of the Jira site, for example `https://example.atlassian.net`: ticket references link to `<site>/browse/<KEY>`, and `map.tsv` records that URL. |
| `ignore` | Skip draft files whose name matches, for example `^00-` for a breakdown file. |
| `titlePrefix` | Remove this prefix from each title, for example `^[0-9]+: ` for `# 05: Title`. |
| `issueType` | Type of the tickets (default `Task`). |
| `epic` | Parent when there is no `spec.md`: `{"key": "PROJ-1"}` reuses an epic; `{"summary", "descriptionFile", "labels", "type"}` creates one (`descriptionFile` relative to the config). |
| `epicLink` | `{"mode": "parent"}` (default) or `{"mode": "field", "field": "customfield_XXXXX"}`. |
| `fields` | `additionalAttributes` set on the epic and every ticket, for example a team field. |
| `labels` | Labels of every ticket, added to `--label`. |
| `metaLabels` | Header fields whose value becomes a label: `["Component"]` reads `Component: infra` in a `Key: value · Key: value` line before the first `##`. |
| `titleLabels` | `[{"pattern": "\\(ADR", "label": "adr"}]`: a label for each title that matches. |
| `sessionRefs` | References refused in titles and descriptions, outside code and URLs (default `Q[0-9]+`, session question numbers; `""` refuses none). A quarter with its year (`Q4 2026`) is never refused. The old name `stripRefs` sets the same refusal: nothing is removed from the text any more. |
| `dropLines` | Lines to remove from descriptions, for example a header line or a dependency line that the tracker links replace. A heading left empty goes too. |
| `blocksLinkType` | Name of the blocking link type (default `Blocks`). |
| `links` | Extra links made when the ticket is created: `[{"ticket": "18", "type": "Relates", "key": "PROJ-123"}]` reads "18 relates to PROJ-123"; `"direction": "in"` reads "PROJ-123 relates to 18". That `--in`/`--out` work for other types as for `Blocks` (below) is (unverified). |

Drafts in another format (title `# NN: Title`, a header line `Epic: ... · Component: ...`, a
breakdown file in the folder) publish unchanged with `ignore`, `titlePrefix`, `metaLabels` and
`dropLines`. The `Blocked by:` line stays required, as in [../assets/ticket.md](../assets/ticket.md).
