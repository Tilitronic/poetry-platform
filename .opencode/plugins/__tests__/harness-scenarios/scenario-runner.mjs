import { createTempWorkspace } from "../helpers/plugin-harness.mjs"

class ScenarioFailure extends Error {}

// runScenario: single cleanup path for standalone bun-run scenarios.
// body receives { directory, fail }; fail(msg) throws the sentinel so the
// finally block below is the ONLY cleanup site. process.exit() skipping
// finally is why the old per-branch manual cleanup existed; throwing
// instead of exiting is what lets one finally cover every failure branch.
// fail() must be called from the awaited body only; never let it escape
// into unawaited or shared scope.
export async function runScenario(prefix, body) {
  const { directory, cleanup } = createTempWorkspace(prefix)
  let code = 0
  const fail = (message) => {
    throw new ScenarioFailure(message)
  }
  try {
    await body({ directory, fail })
  } catch (err) {
    if (err instanceof ScenarioFailure) {
      console.error(`FAIL: ${err.message}`)
    } else {
      console.error("ERROR: unexpected scenario failure")
      console.error(err)
    }
    code = 1
  } finally {
    try {
      cleanup()
    } catch (e) {
      console.error(`[cleanup] scenario cleanup failed: ${e?.message ?? e}`)
    }
  }
  process.exit(code)
}
