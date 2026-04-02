# Diagnostics Metrics Summary

`latest-metrics-summary.json` is the stable aggregate artifact written by `Invoke-WriteDiagnosticsMetrics`.

## Paths

- latest run:
  - `artifacts\wechat-devtools\diagnostics\latest-metrics.json`
- aggregate summary:
  - `artifacts\wechat-devtools\diagnostics\latest-metrics-summary.json`

## Why it exists

The latest-run artifact is useful for per-run details. The summary artifact is useful when you want a readable rollup without inspecting every run.

## Core fields

- `schema_version`
- `generated_at`
- `last_source`
- `detector_runs_total`
- `detector_fallback_used_total`
- `quickcheck_runs_total`
- `quickcheck_wall_clock_seconds_total`
- `quickcheck_average_wall_clock_seconds`
- `quickcheck_tests_total`
- `quickcheck_passed_total`
- `quickcheck_failed_total`
- `repair_attempts_total`
- `repair_applied_total`
- `repair_blocked_total`
- `repair_success_runs_total`
- `completed_rounds_total`
- `repair_runs_total`
- `average_completed_rounds`
- `operator_focus`
- `operator_focus_reason`
- `operator_next_actions`
- `operator_task_hint`
- `operator_priority_action`
- `operator_priority_level`

## Count maps

Each count map is a plain object keyed by the observed label:

- `issue_type_counts`
- `issue_source_counts`
- `decision_action_counts`
- `quickcheck_family_counts`
- `quickcheck_test_counts`
- `final_status_counts`

## Reading rule

Prefer the summary artifact for trend questions and use the latest-run artifact for per-run detail.

## Operator digest

`operator_focus` is the short machine-readable next-step hint. `operator_focus_reason` explains why that focus was chosen. `operator_next_actions` is the short list of concrete next moves that match the current focus.
`operator_task_hint` is the single sentence version of the recommended next move for operator inboxes or dashboards.
`operator_priority_action` is the first recommended action from `operator_next_actions`, kept as a single public-safe pointer for quick decisions.
`operator_priority_level` is the compact urgency label for the current operator focus (`high`, `normal`, or `needs_data`).
`next_step_category` is the compact derived category for the next operator move, suitable for dashboards or inbox routing without exposing machine-local assumptions.

## Public summary

`public_summary` is the machine-neutral one-line status sentence intended for release notes, dashboards, or inbox items. It avoids personal-machine assumptions and does not include local user paths.

## Operator snapshot

`operator_snapshot` is a compact additive object that groups `focus`, `reason`, `next_actions`, `priority_action`, `priority_level`, `task_hint`, `next_step_category`, `public_summary`, and `trend` into one read-only view for humans and clients. It keeps the existing top-level fields stable while providing a single entry point for operator-facing summaries.
