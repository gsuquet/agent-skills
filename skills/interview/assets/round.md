# Round template

Send one message per round. Replace each `<...>` field. Separate questions with `---`. Write nothing
before the first question, except a flag from step 5 or the answer to a question of the user. After
the last question, write one line that lists the open questions not asked in this message, oldest
first (`Open: Q3 <title>, Q7 <title>`), and one that lists the other decisions left for later rounds.
Leave out a line with nothing to list.

```markdown
❓ **Q<n>** - **<title, 2 to 6 words>**: <the decision and why it matters, in 1 to 3 sentences>

- (a) <option>
- (b) <option>

➡️ <recommended option>: <reason in one sentence>
```

- Give between 2 and 4 options. Drop the option list for a yes/no question.
- `<n>` continues from the highest number used; a question asked again keeps its number.
- The recommended option is the one "yes" accepts.
