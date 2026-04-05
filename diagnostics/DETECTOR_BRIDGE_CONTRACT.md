# Detector Bridge Contract

## Purpose
Unified detector entrypoint.
The scheduler calls DetectorBridge only, and does not call automator or screenshot directly.

## Inputs
- `page_path`: target page path to check
- `project_path`: local project path
- `preferred_detector`: preferred detector route, default `automator`

## Output: `DetectorResult`
```json
{
  "issue": "PageIssue",
  "detector_status": "string",
  "detectors_tried": ["string"]
}
```

## `detector_status` values
- `primary_passed`: automator succeeded and page passed
- `primary_detected_issue`: automator succeeded and found an issue
- `primary_failed_fallback_used`: automator failed, then screenshot fallback succeeded
- `preferred_detector_used`: caller preferred screenshot route, screenshot used directly
- `fallback_failed`: automator failed and screenshot fallback also failed

## Routing rules
1. Start with `preferred_detector` (default `automator`)
2. If automator fails (exception or non-zero subprocess), switch to screenshot fallback
3. If screenshot also fails, return `detector_status = fallback_failed`
4. On success, always return standard `PageIssue` plus route status

## Scheduler consumption rule
Scheduler consumes `DetectorResult.issue` as the decision input.
`detector_status` is for logs and reports, not for repair policy decisions.
