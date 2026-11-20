# Trackers

The commands `scripts/publish-tickets.sh` runs on each tracker, and what is known about them.
"In `--help`" means the flag is listed by the `--help` of the version named; it was not run against
a live tracker. Everything marked `(unverified)` comes from documentation or memory only.

## map.tsv

One row per published item, tab-separated: `<draft> <id> <url>`. Special rows: `tracker <name>
<project>` (written first; a re-run on another tracker stops) and, on GitLab, `spec-tasks <count>`
(how many tickets the spec task list holds), and on Jira `refs-NN 1 -` (the description of ticket
NN had its references rewritten). To recover from an issue created without a row (the script says
so and exits 4), add its row by hand, then re-run. To rewrite the references again (for example
after adding `site` to the config), delete the `refs-NN` rows, then re-run: the script skips every
published draft and rewrites only those descriptions.

## GitHub (`gh` 2.103.3)

| Operation | Command | Status |
| --- | --- | --- |
| Create | `gh issue create --title <t> --body-file <f>` | in `--help` |
| Parent | `--parent <spec>`: the ticket is a sub-issue of the spec | in `--help` |
| Blocking | `--blocked-by <n>,<n>` | in `--help` |
| Labels | `--label <name>`, repeated; existence checked with `gh label list --json name` | in `--help` |
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
| Blocking | `Blocked by: <KEY>-<n>` line in the description, always; then `acli jira workitem link create --out <blocker> --in <ticket> --type Blocks --yes` (`--out` blocks `--in`) | in `--help` |
| Link types | `acli jira workitem link type` lists the names the site accepts (`Blocks`, `Relates`, ...) | run |
| Ticket references | `acli jira workitem edit --key <key> --description-file <adf.json> --yes` | in `--help` |
| Labels | `labels` in the payload; no existence check: Jira creates a label on first use | (unverified) |
| Issue key | `.key` of the JSON printed by `--json` | (unverified) |

- The description is converted from Markdown to Atlassian Document Format (headings, lists, task
  lists, tables, code, bold, links). That Jira renders an ADF description sent through
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
  Code spans and Markdown links are left as they are. Without `site`, the key stays plain text and
  the script warns: whether Jira links a plain key in an ADF text node is (unverified), as the ADF
  reference does not say.

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
| `stripRefs` | References to remove from descriptions, for example `Q[0-9]+` for session question numbers, with the brackets and commas around them. |
| `dropLines` | Lines to remove from descriptions, for example a header line or a dependency line that the tracker links replace. A heading left empty goes too. |
| `blocksLinkType` | Name of the blocking link type (default `Blocks`). |
| `links` | Extra links made when the ticket is created: `[{"ticket": "18", "type": "Relates", "key": "PROJ-123"}]`; `"direction": "in"` makes `key` the outward side. |

Drafts in another format (title `# NN: Title`, a header line `Epic: ... · Component: ...`, a
breakdown file in the folder) publish unchanged with `ignore`, `titlePrefix`, `metaLabels` and
`dropLines`. The `Blocked by:` line stays required, as in [../assets/ticket.md](../assets/ticket.md).
