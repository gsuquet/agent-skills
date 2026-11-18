# How-to template

Replace each `<...>` field with text that follows its rule. Delete a section marked *optional*
when it does not apply; keep every other section, in this order.

````markdown
# How to <verb> <object>

<one sentence: the goal and the situation in which the reader needs it>

## Before you start

- <prerequisite: access or role, tool and version, state the system must be in>

## Steps

1. <imperative action>

   ```sh
   <command>
   ```

   <the result that shows the step worked>

## Verify

<the command or check that proves the goal is reached, and its expected output>

## Undo

<optional; required when a step changes shared state: the steps that restore the previous state>

## Troubleshooting

<optional: a table `Symptom | Cause | Fix`, for the failures seen in practice>

## Related

- <link to the concept or reference doc a reader needs next>
````

- One task per how-to. More than 10 steps: split it into two how-tos.
- Explain nothing beyond one sentence per step: link the concept doc instead.
