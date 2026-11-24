# PRs and MRs

Read this in step 8 when the work goes through PRs/MRs. Merging stays the user's action unless they
allowed it.

- **Before each push to a PR branch**, check that the PR is still open: `gh pr view <n> --json
  state,baseRefName`. When it is merged or closed, push to a new branch and open a new PR.
- **Stacked PRs** merge bottom up, one at a time:
  1. Check that the base of the bottom PR is the default branch, then have it merged.
  2. Check that the next PR was retargeted to the default branch; when it was not, retarget it
     (`gh pr edit <n> --base <default>`) before it is merged.
  3. After the last merge, `git fetch` and check that the default branch holds each PR's content:
     `git merge-base --is-ancestor <head> origin/<default>` for a merge commit, else compare the
     PR's files with `git diff <head> origin/<default> -- <files>`.

A "Merged" state proves nothing about the default branch: a PR merged into a branch that was itself
already merged shows it too.
