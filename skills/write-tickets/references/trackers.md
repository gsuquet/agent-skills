# Trackers

The commands `scripts/publish-tickets.sh` runs on each tracker, and what is known about them.
"In `--help`" means the flag is listed by the `--help` of the version named; it was not run against
a live tracker. Everything marked `(unverified)` comes from documentation or memory only.

## map.tsv

One row per published item, tab-separated: `<draft> <id> <url>`. Special rows: `tracker <name>
<project>` (written first; a re-run on another tracker stops) and, on GitLab, `spec-tasks <count>`
(how many tickets the spec task list holds). To recover from an issue created without a row (the
script says so and exits 4), add its row by hand, then re-run.

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

## Jira (Atlassian CLI `acli`, not installed: every command is unverified)

| Operation | Command | Status |
| --- | --- | --- |
| Auth | `acli jira auth login` once per machine | (unverified) |
| Create spec | `acli jira workitem create --project <KEY> --type Epic --summary <t> --description-file <f> --json` | (unverified) |
| Create ticket | same with `--type Task --parent <epic key>` | (unverified) |
| Blocking | `Blocked by: <KEY>-<n>` line in the description, always; then `acli jira workitem link create --out <blocker> --in <ticket> --type Blocks` | (unverified) |
| Labels | `--label <a>,<b>`; no existence check: Jira creates a label on first use | (unverified) |
| Issue key | `.key` of the JSON printed by `--json` | (unverified) |

- The description is sent as written (Markdown). Jira renders its own wiki or ADF format, so
  headings and task lists may show as plain text (unverified).
- A project whose hierarchy has no Epic type, or where Tasks cannot take an Epic parent, refuses the
  spec or `--parent` (unverified).
- No URL is recorded for Jira (`-` in `map.tsv`): the site name is not known to the script.
