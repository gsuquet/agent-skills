# Runbook template

Replace each `<...>` field with text that follows its rule. Keep every section, in this order.

````markdown
# Runbook: <alert name, or the symptom when no alert exists>

- **Alert:** <alert name and link to its definition, or "None: reported by <source>">
- **Service:** <service, cluster or environment it covers>
- **Owner:** <team or handle>
- **Last tested:** <YYYY-MM-DD, the date the steps were last run>

## Symptoms

<what the on-call sees: the alert text, the dashboard panel, the error message, the user report>

## Impact

<who or what is affected and how badly; the SLO it burns; how urgent the response is>

## Diagnosis

```sh
<one VARIABLE=value line per variable the commands below use, for example the kube context, namespace or Terraform workspace>
```

1. <read-only command>

   ```sh
   <command>
   ```

   <how to read the output: "if X, go to Mitigation A; if Y, go to Mitigation B">

## Mitigation

### <A: name of the mitigation>

1. <command, and the result that shows it worked>

## Rollback

<how to undo each mitigation, in the same order as Mitigation>

## Escalation

<when to escalate (a condition or a time box), to whom, through which channel, and the facts to include>

## Verification

<the command, metric or alert state that proves the service recovered, and how long to watch it>
````

- Diagnosis commands are read-only. Every command that changes state sits under Mitigation or
  Rollback.
- Every command is one the on-call can paste: variables declared in the first block.
- Link dashboards, alert definitions and postmortems inline where they are used.
