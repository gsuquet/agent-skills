# Antigravity dynamic workflow template for orchestrate step 5 (unverified: see
# references/engines.md). Do not edit per run: the main agent passes the tasks as args.
#
# args = {
#   "schema": <the content of assets/report.schema.json>,
#   "tasks": [{"name": "<task>", "brief": "<absolute path of the brief>",
#              "check": "<Finish condition check>", "worktree": "<path from the brief>"}],
# }
#
# Each task: one agent implements the brief, one agent re-runs the check in the brief's worktree,
# and on a failed check one fix agent gets the failure, then the check runs once more.
# Logs one line per task: RESULT <json of {name, report, check, fixed}>.
#
# agent, parallel, phase, log and args are provided by the workflow runtime.
import json

CHECK_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["exit_code", "output"],
    "properties": {"exit_code": {"type": "integer"}, "output": {"type": "string"}},
}

schema = args.get("schema")  # noqa: F821
tasks = args.get("tasks") or []  # noqa: F821
if not schema or not tasks:
    raise ValueError("args must be {schema, tasks: [{name, brief, check, worktree}]}")
for t in tasks:
    missing = [k for k in ("name", "brief", "check", "worktree") if not t.get(k)]
    if missing:
        raise ValueError(f"task {json.dumps(t)} misses {', '.join(missing)}")


async def implement(t):
    return await agent(  # noqa: F821
        f"Read the brief at {t['brief']} fully before anything else and treat it as binding. "
        "Do the task it describes. Return your report in its Report format, as the result.",
        schema=schema,
        role=f"implement:{t['name']}",
    )


async def check(t):
    return await agent(  # noqa: F821
        f"In the directory {t['worktree']}, run exactly this command and nothing else: {t['check']}\n"
        "Change no file. Return its exit code and its last 100 lines of output.",
        schema=CHECK_SCHEMA,
        role=f"check:{t['name']}",
    )


async def fix(t, failure):
    return await agent(  # noqa: F821
        f"Read the brief at {t['brief']} fully before anything else and treat it as binding. "
        f"The task is done in {t['worktree']}, but its check fails.\n"
        f"Command: {t['check']}\nExit code: {failure['exit_code']}\nOutput:\n{failure['output']}\n"
        "Fix the cause in the worktree. Return your report in the Report format, as the result.",
        schema=schema,
        role=f"fix:{t['name']}",
    )


async def run(t):
    # parallel() cancels every item when one raises: never let a task raise.
    result = {"name": t["name"], "report": None, "check": None, "fixed": False}
    try:
        result["report"] = await implement(t)
        result["check"] = await check(t)
        if result["check"]["exit_code"] != 0:
            result["report"] = await fix(t, result["check"])
            result["fixed"] = True
            result["check"] = await check(t)
    except Exception as e:  # noqa: BLE001
        result["error"] = f"{type(e).__name__}: {e}"
    return result


phase("Run briefs")  # noqa: F821
# pipeline() runs one item at a time in Antigravity: parallel() is the concurrent form.
for r in await parallel(tasks, run):  # noqa: F821
    log("RESULT " + json.dumps(r))  # noqa: F821
