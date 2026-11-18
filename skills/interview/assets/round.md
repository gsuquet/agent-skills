# Round template

Send one message per round. Replace each `<...>` field. Separate questions with `---`. Write nothing
before the first question, except a flag from step 5. After the last question, write one line that
lists the decisions left for later rounds, or nothing if there are none.

```markdown
❓ **Q<n>** - **<title, 2 to 6 words>**: <the decision and why it matters, in 1 to 3 sentences>

- (a) <option>
- (b) <option>

➡️ <recommended option>: <reason in one sentence>
```

- Give between 2 and 4 options. Drop the option list for a yes/no question.
- `<n>` continues from the last question of the previous round.
- The recommended option is the one "yes" accepts.
