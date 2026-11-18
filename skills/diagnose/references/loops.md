# Loop recipes

Read the section for the stack of the problem. Each recipe gives a command that goes red on the
symptom. Adapt names and paths; keep the shape. Read credentials from environment variables.

Try loop types in this order, and stop at the first that goes red: a failing test at a seam that
reaches the bug, a CLI call with a fixture diffed against a known-good output, an HTTP call against a
running service, a replay of a captured payload, a minimal harness with mocked dependencies, a
differential run (old vs new version or config), `git bisect run`, a human-in-the-loop script.

## Go

```bash
# Run one test many times with the race detector: catches flaky and racy failures.
go test ./pkg/foo -run 'TestParse$' -count=100 -race -failfast
```

- Turn the symptom into a table test case: one row per minimised input, `t.Run(tc.name, ...)`, and
  run only the new row with `-run 'TestParse/<name>$'`.
- Pin time, seeds and the filesystem: inject a clock, seed `math/rand`, use `t.TempDir()`.
- Raise a low flake rate with `-count=1000 -parallel=16` or `-cpu=1,2,8` before you hypothesise.

## Terraform

```bash
# Exit code 0: no diff, 1: error, 2: diff. Drift is red when the code is 2.
terraform plan -detailed-exitcode -input=false -lock=false -refresh=true > plan.txt; echo "exit=$?"
```

- Run it against the affected workspace and backend, with the same provider versions
  (`terraform version`, `.terraform.lock.hcl`).
- Narrow with `-target=<address>` once you know the resource, and read
  `terraform state show <address>` for the recorded value.
- Compare state serials (`terraform state pull | jq .serial`) to know whether someone applied since
  the last known-good run.

## Kubernetes

```bash
# Wait for the workload to become ready; a timeout is red.
kubectl -n "$NS" rollout status deploy/"$APP" --timeout=120s

# Or poll any condition.
kubectl -n "$NS" wait --for=condition=Ready pod -l app="$APP" --timeout=60s
```

- Facts first: `kubectl -n "$NS" get pod -l app="$APP" -o wide`, `kubectl -n "$NS" describe pod
  <pod>`, `kubectl -n "$NS" get events --sort-by=.lastTimestamp`.
- Crash loops: `kubectl -n "$NS" logs <pod> --previous` shows the run that crashed.
- Drift against Git: `kubectl diff -f <rendered manifests>` (exit code 1 means a diff), or
  `kustomize build <overlay> | kubectl diff -f -`.
- Repeat a flaky startup: delete the pod in a loop and `kubectl wait` each time; count failures.

## Bisect

Use when the problem appeared between a known-good and a known-bad commit.

```bash
git bisect start <bad> <good>
git bisect run ./loop.sh   # exit 0: good, 1-124: bad, 125: skip this commit
git bisect reset
```

The loop script must build what it needs on each commit and exit 125 when the commit cannot be
tested.

## Performance

Measure a baseline before any change.

```bash
go test ./pkg/foo -run '^$' -bench 'BenchmarkParse$' -benchmem -count=10 > old.txt
# apply one change
go test ./pkg/foo -run '^$' -bench 'BenchmarkParse$' -benchmem -count=10 > new.txt
benchstat old.txt new.txt   # red when the delta is significant and in the wrong direction
```

- Profile the slow path: `go test -bench ... -cpuprofile cpu.out` then `go tool pprof -top cpu.out`;
  for a running service, `go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30`.
- Check the variance in `benchstat` output (`±`) before trusting a delta.

## TypeScript

```bash
# Run one test file, filtered by name, without watch mode.
npx vitest run src/foo.test.ts -t 'parses empty input'
```

- Pick the seam where the bug path is pure: export the function, or inject the dependency (HTTP
  client, clock) and stub it with `vi.fn()`.
- Pin time with `vi.useFakeTimers()` and `vi.setSystemTime(...)`.
- Repeat a flaky test with `--retry=0` and a loop: `for i in $(seq 50); do npx vitest run <file> ||
  break; done`.
