# SKRS AutoFix Contract v1

## Goal
The SKRS pipeline must not return success while known issues remain.
It must keep repairing and re-checking until one of these final states:

- `success`: all checks passed
- `blocked`: external/runtime blocker (manual action required)
- `failed`: max rounds reached without convergence

## Mandatory loop
1. Generate or update code.
2. Run detector round (`automator` preferred, screenshot fallback allowed).
3. Run project health overlay checks (encoding/runtime guard).
4. If issue exists, execute repair action.
5. Re-run detector round.
6. Stop only on `success`, `blocked`, or `failed`.

## v1 blocker policy
- Any external blocker must return non-retryable issue and halt:
  - invalid appid / cannot open project
  - automator startup hard failure
  - missing required runtime dependency

## v1 encoding policy
- Detect suspicious garbled UI text in `app.json`:
  - percent-encoded display text (`%E5%...`)
  - replacement char (`�`)
  - known mojibake patterns in title/tab labels
- Emit issue type `text_encoding_garbled` (retryable critical).
- Auto repair is allowed only for deterministic fields:
  - `window.navigationBarTitleText`
  - `tabBar.list[*].text`

## Success rule
Only return success when:
- detector issue status is `passed`
- overlay checks report no blocker/no encoding issue
- latest repair action (if any) has been applied and verified by a fresh round

## Safety boundary
- Auto repair is scoped and deterministic.
- No deploy/upload operations are triggered by this loop.
- Unknown issue types are never auto-written; they return `blocked`.
