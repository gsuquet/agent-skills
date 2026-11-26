# date | version | what went wrong | PR, MR or commit link
2026-11-26 | 0.2.0 | the brief banned push only in the worktree: a subagent testing deploy steps tried a force push to a bare repository it had created, and its permission rules refused it | -
2026-11-26 | 0.2.0 | after a refused command, a subagent sent nothing for 19 minutes; step 6 had no check on a quiet agent, and stopping then resuming it with read-only rules unblocked it | -
