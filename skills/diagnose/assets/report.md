# Report template

Send this as the last message of the diagnosis. Replace each `<...>` field. Keep every section;
write `None.` in a section that has nothing. Redact every secret as `<REDACTED>`.

````markdown
## Diagnosis: <one-line symptom>

**Loop:** `<the one command>` (red before the fix, green after)

**Minimised repro:**

```text
<smallest input, config or steps that still go red>
```

## Hypotheses

| # | Hypothesis | Prediction | Verdict |
|---|---|---|---|
| 1 | <cause> | If <X>, then <changing Y> turns the loop green | confirmed / refuted / untested |

## Cause

<what is wrong, where (file:line, resource address, manifest), and since when>

## Fix

<what changed and why it removes the cause; commit or PR/MR link>

## Regression test

<test name and path, red before the fix and green after>, or: No seam: <why no test point reaches
the real path, and what would make one>

## Prevention

<the guard beyond the test that catches the next occurrence: an alert, a policy (OPA/Conftest,
admission), a validation, a CI check>, or: None: <why>

## Cleanup

- [x] Loop green on the original scenario
- [x] Regression test passes, or missing seam recorded
- [x] No `[DEBUG-<tag>]` left
- [x] Throwaway scripts removed
- [x] Confirmed hypothesis stated in the commit or PR/MR
````

- One table row per hypothesis, in the ranked order.
- Leave a cleanup box unchecked, with the reason on the same line, when an item does not pass.
