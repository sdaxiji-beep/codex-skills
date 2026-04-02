# Test Tiers

Last updated: 2026-03-25

## Why this exists

This repo now has several different validation paths.

They are not interchangeable:

- a cached deploy/preview gate can become very fast after the first run
- a full regression run is much broader and will stay slower
- diagnostics-focused checks sit in the middle

This document defines which command to run for which purpose.

## The validation tiers

### L0 - Syntax and guard surface

Command:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -GuardCheckOnly
```

What it covers:
- PowerShell syntax parsing for the script surface
- basic guard-entry validity

When to use it:
- after any small script edit
- before running a larger tier
- in remote CI as a stable minimum gate

Expected budget:
- target <= 10s

### L1 - Diagnostics-focused

Command:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-diagnostics-focused.ps1"
```

What it covers:
- detector bridge contracts
- screenshot fallback contracts
- compile/console overlay contracts
- repair loop and repair guard contracts

When to use it:
- after changing anything in `diagnostics\`
- after changing detect/repair behavior

Expected budget:
- target <= 90s

### L2 - Fast core regression

Command:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -SkipSmoke -Tag fast
```

What it covers:
- core local workflow regression
- boundary contracts
- public doc sync checks
- generation gate policy checks
- diagnostics-focused suite

What it avoids:
- the heaviest full-integration checks that are reserved for `full`
- expensive cache-proof or repeated `ForceRefresh` probes
- focused operational hardening drills whose main purpose is to prove cache stability, not routine developer confidence

When to use it:
- before local commit
- after medium-sized changes
- after doc/contract changes that touch the public surface

Expected budget:
- target <= 2 minutes
- current real-world runtime is higher and should be optimized over time

Admission rule:
- a test belongs in `fast` only when it improves routine developer confidence and does not dominate runtime with repeated cache rebuilds or forced refreshes
- if a test exists mainly to prove cache reuse, artifact persistence, or heavy operational hardening, it should stay focused/manual or move to `full`

### L3 - Full integration regression

Command:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -Tag full
```

What it covers:
- everything in `fast`
- heavier local integration checks
- MCP write/deploy contract coverage
- golden path drill
- readonly/mcp/deploy-flow integration checks
- cache-stability and operational hardening probes that are too heavy for routine `fast`

When to use it:
- before release-candidate work
- after infrastructure or contract changes
- after major boundary/gate/diagnostics changes

Expected budget:
- target <= 4 minutes
- current real-world runtime is roughly 3 to 4 minutes for `full` alone

## Important distinction: cached gate vs full regression

These two are different:

### Cached deploy/preview gate

This is the path where:
- first run is slower
- later runs can become much faster because the gate cache is reused

That is the source of the "first run ~2 minutes, later runs ~20 seconds" experience.

It is valid for that specific guarded path.

It is **not** the same as running the entire regression suite.

### Full regression

`test-wechat-skill.ps1 -Tag full` runs the broad regression surface.

It includes many checks that do not collapse into a 20-second cached path:
- diagnostics suites
- boundary contracts
- AST policy checks
- generated project checks
- integration and write/deploy contract checks

So a slow `full` does not mean the cache path is broken.
It means the regression surface is broader.

## Recommended usage

### Normal development

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File ".\scripts\test-diagnostics-focused.ps1"
```

### Before commit

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -SkipSmoke -Tag fast
```

### Before release or boundary changes

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\test-wechat-skill.ps1" -Tag full
```

## Sequencing rule

Do not run `fast` and `full` in parallel.

Run them sequentially to avoid write-guard and integration interference.

Do not run artifact-sharing acceptance tests in parallel when they write or refresh shared `latest` outputs.

## Timing rule

Treat `fast` and `full` timing as two different numbers:

- `internal` time:
  the test-body time inside the runner
- `wall-clock` time:
  the full end-to-end elapsed time, including shared preflight, diagnostics cache lookup, fixture setup, and automator/bootstrap work

When judging developer experience, prefer wall-clock time.
When comparing coverage density inside the same runner, internal time is still useful.
