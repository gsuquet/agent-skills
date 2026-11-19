# Reference template

Replace each `<...>` field with text that follows its rule. Repeat the entry group for each group.

````markdown
# <thing> reference

<one sentence: what this reference covers, the version it describes, and its source of truth (the code, schema or `--help` it mirrors)>

## <entry group, named as in the thing itself: a command, a resource, a config file section>

<one sentence: what the group is for>

| Name | Type | Default | Description |
|---|---|---|---|
| `<name>` | <type> | `<default>` or none | <what it does, its allowed values and limits> |

<optional: one minimal example for the group>

```<language>
<example>
```
````

- The structure mirrors the thing: the order of commands, resources or config sections it has.
- Every entry has the same shape; list every entry, not a selection.
- When a generator exists (`--help`, OpenAPI, terraform-docs), generate the reference and link the
  command that regenerates it.
- No steps and no explanations: link the how-to and the concept doc.
