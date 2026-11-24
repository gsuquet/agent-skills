// Claude Code workflow template for orchestrate step 5. Do not edit per run: pass the tasks as args.
//
// args = {
//   schema: <the content of assets/report.schema.json>,
//   tasks: [{ name: "<task>", brief: "<absolute path of the brief>", check: "<Finish condition check>", worktree: "<path from the brief>" }]
// }
//
// Each task: one agent implements the brief, one agent re-runs the check in the brief's worktree,
// and on a failed check one fix agent gets the failure, then the check runs once more.
// Returns [{ name, report, check, fixed }]; report follows report.schema.json, null when the agent died.
export const meta = {
  name: 'orchestrate-briefs',
  description: 'Run one agent per orchestrate brief, re-run each brief check, one fix round on failure',
  phases: [{ title: 'Implement' }, { title: 'Check' }, { title: 'Fix' }],
}

const CHECK_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['exit_code', 'output'],
  properties: {
    exit_code: { type: 'integer' },
    output: { type: 'string' },
  },
}

if (!args || !args.schema || !Array.isArray(args.tasks) || args.tasks.length === 0) {
  throw new Error('args must be { schema, tasks: [{ name, brief, check, worktree }] }')
}
for (const t of args.tasks) {
  if (!t.name || !t.brief || !t.check || !t.worktree) {
    throw new Error(`task ${JSON.stringify(t)} needs name, brief, check and worktree`)
  }
}

const implement = (t) =>
  agent(
    `Read the brief at ${t.brief} fully before anything else and treat it as binding. ` +
      'Do the task it describes. Return your report in its Report format, as the structured output.',
    { label: `implement:${t.name}`, phase: 'Implement', schema: args.schema },
  )

const check = (t, phase) =>
  agent(
    `In the directory ${t.worktree}, run exactly this command and nothing else: ${t.check}\n` +
      'Change no file. Return its exit code and its last 100 lines of output.',
    { label: `check:${t.name}`, phase, schema: CHECK_SCHEMA, effort: 'low' },
  )

const fix = (t, failure) =>
  agent(
    `Read the brief at ${t.brief} fully before anything else and treat it as binding. ` +
      `The task is done in ${t.worktree}, but its check fails.\n` +
      `Command: ${t.check}\nExit code: ${failure.exit_code}\nOutput:\n${failure.output}\n` +
      'Fix the cause in the worktree. Return your report in the Report format, as the structured output.',
    { label: `fix:${t.name}`, phase: 'Fix', schema: args.schema },
  )

return await pipeline(
  args.tasks,
  (t) => implement(t),
  async (report, t) => {
    if (!report) return { name: t.name, report: null, check: null, fixed: false }
    const first = await check(t, 'Check')
    if (!first || first.exit_code === 0) return { name: t.name, report, check: first, fixed: false }
    const fixed = await fix(t, first)
    if (!fixed) return { name: t.name, report, check: first, fixed: false }
    return { name: t.name, report: fixed, check: await check(t, 'Fix'), fixed: true }
  },
)
