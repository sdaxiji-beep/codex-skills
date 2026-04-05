# AST Validation Design

Last updated: 2026-03-24

## Purpose

Define the Phase 2 design for upgrading validation from regex-first checks to parser/AST-backed checks.

This is a design document, not a full implementation.

## Current Problem

Current Generation Gate logic in this workspace relies mostly on regex and lightweight structure checks.

This works for practical v1 usage, but has limits:

1. false positives on valid code patterns
2. false negatives on obfuscated patterns
3. weak confidence for stronger "hard guarantee" claims

## Design Goals

1. Keep existing guardrail behavior semantics (`pass`, `retryable_fail`, `hard_fail`) intact.
2. Upgrade JS/WXML validation reliability using parser-backed analysis.
3. Minimize migration risk by adding AST checks behind feature flags first.
4. Preserve current PowerShell entrypoints while introducing Node-based validators.

## Non-Goals

1. No immediate cross-platform full rewrite in this phase.
2. No behavioral expansion of deploy/upload policy.
3. No major prompt/spec contract redesign in this phase.

## Target Architecture

Keep current PowerShell orchestration as the outer layer:

- `wechat-apply-bundle.ps1`
- `wechat-apply-component-bundle.ps1`
- `wechat-apply-app-json-patch.ps1`

Add a Node validator layer under `scripts/validators/`:

1. `validate-js-ast.mjs`
2. `validate-wxml-ast.mjs`
3. `validate-wxss-rules.mjs` (rule-engine style, not pure regex)
4. `validate-bundle-ast.mjs` (aggregates per-file checks and emits normalized diagnostics)

PowerShell `generation-gate-*.ps1` becomes a coordinator that:

1. keeps path sandbox checks in PowerShell (fast + explicit)
2. calls Node validator for content semantics
3. maps diagnostics to current gate status model

## Parser/Tooling Choice

JS/TS:

- parser: `@babel/parser`
- traversal: `@babel/traverse` (or direct AST walk if minimal)

WXML:

- parser candidate: `htmlparser2` with custom allowlist rules for mini-program tags and directives
- goal: structural parse, tag correctness, attribute rule checks

WXSS:

- parser candidate: `postcss`
- goal: selector and unit policy checks with rule-level severity

## Policy Model (Shared)

Define one shared policy source (JSON or JS object) consumed by validators:

1. allowed JS constructors (`Page`, `Component`)
2. forbidden API symbols (`window`, `document`, `localStorage`, `fetch`, `axios`)
3. allowed WXML tags
4. forbidden global selectors in component wxss
5. warning vs fail rule severity

This removes duplicated rule strings across multiple gate scripts.

## Migration Plan

### Stage 2A - Shadow Mode

1. Add Node validators.
2. Keep existing regex verdict as source of truth.
3. Run AST validators in shadow mode and log diffs.
4. Produce comparison report:
   - regex verdict
   - ast verdict
   - mismatch reason

Exit criteria:

- mismatch rate is understood and bounded.

### Stage 2B - Hybrid Gate

1. Promote AST results to primary for JS/WXML.
2. Keep regex fallback path as safety fallback with telemetry.
3. Keep status contract unchanged (`pass/retryable_fail/hard_fail`).

Exit criteria:

- existing tests still pass.
- golden path drill remains green.

### Stage 2C - AST-Primary

1. Remove redundant regex checks that AST fully covers.
2. Keep only lightweight regex checks where parser cost is not justified.

Exit criteria:

- docs can safely claim parser-backed validation.
- regression remains stable.

## Contract And Diagnostic Format

Node validator output should be stable JSON:

```json
{
  "status": "pass|retryable_fail|hard_fail",
  "errors": [
    {
      "code": "JS_FORBIDDEN_API",
      "file": "pages/about/index.js",
      "message": "Forbidden API: fetch",
      "severity": "error"
    }
  ],
  "warnings": []
}
```

PowerShell gate scripts map this output directly into existing behavior.

## Test Strategy

1. Unit tests for Node validators (positive + bypass-style negative cases).
2. Keep existing PowerShell gate tests.
3. Add AST mismatch comparison tests during shadow mode.
4. Keep focused checks green:
   - `test-golden-path-contract.ps1`
   - `test-golden-path-drill.ps1`
5. Keep regression green:
   - fast
   - full

## Risk And Mitigation

Risk: parser differences with WXML edge syntax.
Mitigation: staged rollout + fallback + mismatch reporting.

Risk: PowerShell/Node integration overhead.
Mitigation: isolated validator process with strict JSON I/O contract.

Risk: slowdown in fast tests.
Mitigation: shadow mode only in selected tests first, then optimize hot paths.

## Implementation Checklist

1. Create `scripts/validators/` and bootstrap Node validator entrypoint.
2. Add shared policy definition and baseline rules.
3. Implement JS AST validator.
4. Implement WXML parser validator.
5. Integrate shadow mode into one gate path first (page gate).
6. Add mismatch report artifact.
7. Promote to hybrid mode after mismatch review.
8. Expand to component gate.

## Phase 2 Entry Condition

Phase 2 implementation starts when:

1. this design is accepted as the migration baseline
2. `fast` and `full` remain green after introducing validator scaffolding
3. golden path checks remain green

