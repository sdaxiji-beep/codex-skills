function Get-DiagnosticsMetricsSummary {
    [CmdletBinding()]
    param(
        [string]$Path,
        [switch]$AsJson
    )

    function Get-TopCountEntries {
        param(
            [object]$Counts,
            [int]$Limit = 3
        )

        if ($null -eq $Counts) {
            return @()
        }

        $entries = @()

        if ($Counts -is [System.Collections.IDictionary]) {
            foreach ($key in $Counts.Keys) {
                $entries += [pscustomobject]@{
                    name = [string]$key
                    count = [int]$Counts[$key]
                }
            }
        }
        else {
            foreach ($prop in $Counts.PSObject.Properties) {
                if ($prop.MemberType -ne 'NoteProperty' -and $prop.MemberType -ne 'Property') {
                    continue
                }
                $entries += [pscustomobject]@{
                    name = [string]$prop.Name
                    count = [int]$prop.Value
                }
            }
        }

        return @(
            $entries |
                Sort-Object @{ Expression = 'count'; Descending = $true }, @{ Expression = 'name'; Descending = $false } |
                Select-Object -First $Limit
        )
    }

    function Format-CountEntries {
        param([object[]]$Entries)

        if (-not $Entries -or $Entries.Count -eq 0) {
            return 'none'
        }

        return ($Entries | ForEach-Object { "$($_.name)=$($_.count)" }) -join ', '
    }

    function Get-TopEntryName {
        param([object[]]$Entries)

        if (-not $Entries -or $Entries.Count -eq 0) {
            return 'none'
        }

        return [string]$Entries[0].name
    }

    function Get-Percent {
        param(
            [double]$Numerator,
            [double]$Denominator
        )

        if ($Denominator -le 0) {
            return 0
        }

        return [Math]::Round(($Numerator / $Denominator) * 100, 2)
    }

    function Get-OperatorFocus {
        param(
            [object]$Summary,
            [double]$RepairSuccessRate
        )

        $quickcheckAverage = [double]$Summary.quickcheck_average_wall_clock_seconds
        $detectorFallback = [int]$Summary.detector_fallback_used_total
        $repairBlocked = [int]$Summary.repair_blocked_total
        $quickcheckRuns = [int]$Summary.quickcheck_runs_total

        if ($quickcheckRuns -gt 0 -and $quickcheckAverage -ge 90) {
            return [pscustomobject]@{
                focus = 'fast_path_fixture_reduction'
                reason = "quickcheck average wall clock is $quickcheckAverage seconds"
            }
        }

        if ($detectorFallback -gt 0) {
            return [pscustomobject]@{
                focus = 'detector_stability'
                reason = "detector fallback used $detectorFallback time(s)"
            }
        }

        if ($repairBlocked -gt 0) {
            return [pscustomobject]@{
                focus = 'repair_coverage'
                reason = "repair blocked $repairBlocked time(s) while repair success rate is $RepairSuccessRate%"
            }
        }

        if ($quickcheckRuns -gt 0) {
            return [pscustomobject]@{
                focus = 'steady_state'
                reason = "quickcheck average wall clock is $quickcheckAverage seconds and no dominant blocker remains"
            }
        }

        return [pscustomobject]@{
            focus = 'insufficient_data'
            reason = 'metrics summary unavailable'
        }
    }

    function Get-OperatorNextActions {
        param([string]$OperatorFocus)

        switch ($OperatorFocus) {
            'fast_path_fixture_reduction' {
                return @(
                    'merge repeated fast-path fixtures',
                    'separate heavy doctor and get-port setup from shared quickcheck paths'
                )
            }
            'detector_stability' {
                return @(
                    'review automator fallback and project-scoped port selection',
                    'reduce stale session reuse before widening detector coverage'
                )
            }
            'repair_coverage' {
                return @(
                    'expand deterministic repair coverage for narrow runtime or data blockers',
                    'avoid broad UI guessing and keep selector targets explicit'
                )
            }
            'steady_state' {
                return @(
                    'keep current guardrails stable',
                    'watch trend breakdown for regressions'
                )
            }
            default {
                return @(
                    'collect more detector, repair, and quickcheck samples'
                )
            }
        }
    }

    function Get-OperatorTaskHint {
        param(
            [string]$OperatorFocus,
            [string]$NextStepCategory
        )

        switch ($OperatorFocus) {
            'fast_path_fixture_reduction' {
                return 'If the goal is faster validation, start with shared fixture reuse and repeated fast-path setup reduction.'
            }
            'detector_stability' {
                return 'If the goal is more reliable inspection, start with detector fallback and stale-session reuse reduction.'
            }
            'repair_coverage' {
                return 'If the goal is more automatic fixes, start with narrow deterministic repair expansion.'
            }
            'steady_state' {
                return 'If the goal is steady operation, keep the current guardrails and watch the trend breakdown.'
            }
            default {
                if ($NextStepCategory -eq 'collect_more_data') {
                    return 'If the goal is to decide the next move, collect more detector, repair, and quickcheck samples first.'
                }
                return 'If the goal is to continue, follow the next-step category and keep the public surface stable.'
            }
        }
    }

    function Get-OperatorPriorityAction {
        param([object[]]$OperatorNextActions)

        if (-not $OperatorNextActions -or $OperatorNextActions.Count -eq 0) {
            return 'collect more detector, repair, and quickcheck samples'
        }

        return [string]$OperatorNextActions[0]
    }

    function Get-OperatorPriorityLevel {
        param(
            [string]$OperatorFocus,
            [string]$TrendState
        )

        switch ($OperatorFocus) {
            'fast_path_fixture_reduction' { return 'high' }
            'detector_stability' { return 'high' }
            'repair_coverage' { return 'high' }
            'steady_state' { return 'normal' }
            default {
                if ($TrendState -eq 'insufficient_data') {
                    return 'needs_data'
                }
                return 'normal'
            }
        }
    }

    function Get-NextStepCategory {
        param(
            [string]$OperatorFocus,
            [string]$TrendState
        )

        switch ($OperatorFocus) {
            'fast_path_fixture_reduction' { return 'optimize_test_fixtures' }
            'detector_stability' { return 'stabilize_detection' }
            'repair_coverage' { return 'expand_repair_coverage' }
            'steady_state' { return 'maintain_and_watch' }
            default {
                if ($TrendState -eq 'insufficient_data') {
                    return 'collect_more_data'
                }
                return 'general_follow_up'
            }
        }
    }

    function Get-TrendState {
        param([string]$OperatorFocus)

        switch ($OperatorFocus) {
            'steady_state' {
                return [pscustomobject]@{
                    state = 'steady'
                    reason = 'no dominant blocker remains'
                }
            }
            'insufficient_data' {
                return [pscustomobject]@{
                    state = 'insufficient_data'
                    reason = 'metrics summary unavailable'
                }
            }
            default {
                return [pscustomobject]@{
                    state = 'attention'
                    reason = 'operator focus requires active follow-up'
                }
            }
        }
    }

    function Get-PublicSummary {
        param([string]$OperatorFocus)

        switch ($OperatorFocus) {
            'fast_path_fixture_reduction' {
                return 'Fast-path fixture reduction remains the active optimization area.'
            }
            'detector_stability' {
                return 'Detector stability needs follow-up; reduce fallback and stale-session reuse.'
            }
            'repair_coverage' {
                return 'Repair coverage needs follow-up; keep repairs narrow and deterministic.'
            }
            'steady_state' {
                return 'Metrics are in steady state; keep guardrails stable and watch trend breakdowns.'
            }
            default {
                return 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
            }
        }
    }

    function Get-OperatorSnapshot {
        param(
            [string]$OperatorFocus,
            [string]$OperatorFocusReason,
            [object[]]$OperatorNextActions,
            [string]$NextStepCategory,
            [string]$OperatorPriorityAction,
            [string]$OperatorPriorityLevel,
            [string]$OperatorTaskHint,
            [string]$PublicSummary,
            [string]$TrendState,
            [string]$TrendStateReason,
            [string]$TrendDigest,
            [object]$TrendBreakdown
        )

        return [pscustomobject]@{
            focus = $OperatorFocus
            reason = $OperatorFocusReason
            next_actions = $OperatorNextActions
            next_step_category = $NextStepCategory
            priority_action = $OperatorPriorityAction
            priority_level = $OperatorPriorityLevel
            task_hint = $OperatorTaskHint
            public_summary = $PublicSummary
            trend = [pscustomobject]@{
                state = $TrendState
                reason = $TrendStateReason
                digest = $TrendDigest
                breakdown = $TrendBreakdown
            }
        }
    }

    function Get-TrendDigest {
        param(
            [object]$Summary,
            [int]$RepairRuns,
            [double]$RepairSuccessRate,
            [string]$OperatorFocus
        )

        $detectorRuns = [int]$Summary.detector_runs_total
        $detectorFallback = [int]$Summary.detector_fallback_used_total
        $quickcheckRuns = [int]$Summary.quickcheck_runs_total
        $quickcheckTests = [int]$Summary.quickcheck_tests_total
        $quickcheckAverage = [double]$Summary.quickcheck_average_wall_clock_seconds
        $topIssues = Format-CountEntries (Get-TopCountEntries -Counts $Summary.issue_type_counts -Limit 3)
        $topFamilies = Format-CountEntries (Get-TopCountEntries -Counts $Summary.quickcheck_family_counts -Limit 3)

        $parts = @()

        $detectorPart = "detector=$detectorRuns"
        if ($detectorFallback -gt 0) {
            $detectorPart += ", fallback=$detectorFallback"
        }
        $parts += $detectorPart

        $repairPart = "repair=$RepairRuns"
        if ($RepairRuns -gt 0) {
            $repairPart += ", success=$RepairSuccessRate%"
            $repairPart += ", avgRounds=$([double]$Summary.average_completed_rounds)"
        }
        $parts += $repairPart

        $quickcheckPart = "quickcheck=$quickcheckRuns"
        if ($quickcheckRuns -gt 0) {
            $quickcheckPart += ", tests=$quickcheckTests"
            $quickcheckPart += ", avgSeconds=$quickcheckAverage"
        }
        $parts += $quickcheckPart

        $parts += "topIssues=$topIssues"
        $parts += "topFamilies=$topFamilies"
        $parts += "focus=$OperatorFocus"

        return ($parts -join '; ')
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path $repoRoot 'artifacts\wechat-devtools\diagnostics\latest-metrics-summary.json'
    }

    if (-not (Test-Path $Path)) {
        $result = [pscustomobject]@{
            status = 'missing'
            path = $Path
            schema_version = 'diagnostics_metrics_summary_v1'
            detector_runs_total = 0
            detector_fallback_used_total = 0
            repair_runs_total = 0
            repair_success_runs_total = 0
            repair_success_rate = 0
            average_completed_rounds = 0
            quickcheck_runs_total = 0
            quickcheck_average_wall_clock_seconds = 0
            operator_focus = 'insufficient_data'
            operator_focus_reason = 'metrics summary unavailable'
            operator_next_actions = @('collect more detector, repair, and quickcheck samples')
            operator_priority_action = 'collect more detector, repair, and quickcheck samples'
            operator_priority_level = 'needs_data'
            operator_task_hint = 'If the goal is to decide the next move, collect more detector, repair, and quickcheck samples first.'
            public_summary = 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
            next_step_category = 'collect_more_data'
            operator_snapshot = [pscustomobject]@{
                focus = 'insufficient_data'
                reason = 'metrics summary unavailable'
                next_actions = @('collect more detector, repair, and quickcheck samples')
                next_step_category = 'collect_more_data'
                priority_action = 'collect more detector, repair, and quickcheck samples'
                priority_level = 'needs_data'
                task_hint = 'If the goal is to decide the next move, collect more detector, repair, and quickcheck samples first.'
                public_summary = 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
                trend = [pscustomobject]@{
                    state = 'insufficient_data'
                    reason = 'metrics summary unavailable'
                    digest = 'metrics summary unavailable'
                    breakdown = [pscustomobject]@{
                        detector = [pscustomobject]@{
                            runs = 0
                            fallback_used = 0
                            fallback_rate = 0
                        }
                        repair = [pscustomobject]@{
                            runs = 0
                            success_runs = 0
                            success_rate = 0
                            average_completed_rounds = 0
                        }
                        quickcheck = [pscustomobject]@{
                            runs = 0
                            tests_total = 0
                            pass_rate = 0
                            average_wall_clock_seconds = 0
                        }
                        top_issue_family = 'none'
                        top_quickcheck_family = 'none'
                        operator_focus = 'insufficient_data'
                        operator_focus_reason = 'metrics summary unavailable'
                        operator_next_actions = @('collect more detector, repair, and quickcheck samples')
                    }
                }
            }
            trend_state = 'insufficient_data'
            trend_state_reason = 'metrics summary unavailable'
            trend_digest = 'metrics summary unavailable'
            trend_breakdown = [pscustomobject]@{
                detector = [pscustomobject]@{
                    runs = 0
                    fallback_used = 0
                    fallback_rate = 0
                }
                repair = [pscustomobject]@{
                    runs = 0
                    success_runs = 0
                    success_rate = 0
                    average_completed_rounds = 0
                }
                quickcheck = [pscustomobject]@{
                    runs = 0
                    tests_total = 0
                    pass_rate = 0
                    average_wall_clock_seconds = 0
                }
                top_issue_family = 'none'
                top_quickcheck_family = 'none'
                operator_focus = 'insufficient_data'
                operator_focus_reason = 'metrics summary unavailable'
            }
        }

        if ($AsJson) {
            return ($result | ConvertTo-Json -Depth 6)
        }

        return $result
    }

        $summary = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $repairRuns = [int]$summary.repair_runs_total
        $repairSuccessRuns = [int]$summary.repair_success_runs_total
        $repairSuccessRate = Get-Percent -Numerator $repairSuccessRuns -Denominator $repairRuns
    $detectorRuns = [int]$summary.detector_runs_total
    $detectorFallback = [int]$summary.detector_fallback_used_total
    $detectorFallbackRate = Get-Percent -Numerator $detectorFallback -Denominator $detectorRuns
        $quickcheckRuns = [int]$summary.quickcheck_runs_total
        $quickcheckPassed = [int]$summary.quickcheck_passed_total
        $quickcheckPassRate = Get-Percent -Numerator $quickcheckPassed -Denominator ([int]$summary.quickcheck_tests_total)
        $topIssueTypes = @(Get-TopCountEntries -Counts $summary.issue_type_counts -Limit 5)
        $topQuickcheckFamilies = @(Get-TopCountEntries -Counts $summary.quickcheck_family_counts -Limit 5)
        $operatorFocus = Get-OperatorFocus -Summary $summary -RepairSuccessRate $repairSuccessRate
        $trendState = Get-TrendState -OperatorFocus ([string]$operatorFocus.focus)
        $operatorNextActions = Get-OperatorNextActions -OperatorFocus ([string]$operatorFocus.focus)
        $operatorPriorityAction = Get-OperatorPriorityAction -OperatorNextActions $operatorNextActions
        $nextStepCategory = Get-NextStepCategory -OperatorFocus ([string]$operatorFocus.focus) -TrendState ([string]$trendState.state)
        $operatorPriorityLevel = Get-OperatorPriorityLevel -OperatorFocus ([string]$operatorFocus.focus) -TrendState ([string]$trendState.state)
        $operatorTaskHint = Get-OperatorTaskHint -OperatorFocus ([string]$operatorFocus.focus) -NextStepCategory $nextStepCategory
        $trendDigest = Get-TrendDigest -Summary $summary -RepairRuns $repairRuns -RepairSuccessRate $repairSuccessRate -OperatorFocus ([string]$operatorFocus.focus)
        $trendBreakdown = [pscustomobject]@{
            detector = [pscustomobject]@{
                runs = $detectorRuns
                fallback_used = $detectorFallback
                fallback_rate = $detectorFallbackRate
            }
            repair = [pscustomobject]@{
                runs = $repairRuns
                success_runs = $repairSuccessRuns
                success_rate = $repairSuccessRate
                average_completed_rounds = [double]$summary.average_completed_rounds
            }
            quickcheck = [pscustomobject]@{
                runs = $quickcheckRuns
                tests_total = [int]$summary.quickcheck_tests_total
                tests_passed = [int]$summary.quickcheck_passed_total
                tests_failed = [int]$summary.quickcheck_failed_total
                pass_rate = $quickcheckPassRate
                average_wall_clock_seconds = [double]$summary.quickcheck_average_wall_clock_seconds
            }
            top_issue_family = Get-TopEntryName -Entries $topIssueTypes
            top_quickcheck_family = Get-TopEntryName -Entries $topQuickcheckFamilies
            operator_focus = [string]$operatorFocus.focus
            operator_focus_reason = [string]$operatorFocus.reason
            operator_next_actions = $operatorNextActions
            operator_priority_action = $operatorPriorityAction
            operator_priority_level = $operatorPriorityLevel
            operator_task_hint = $operatorTaskHint
            next_step_category = $nextStepCategory
            public_summary = $publicSummary
        }
        $publicSummary = if ($summary.PSObject.Properties.Name -contains 'public_summary' -and -not [string]::IsNullOrWhiteSpace([string]$summary.public_summary)) {
            [string]$summary.public_summary
        }
        else {
            Get-PublicSummary -OperatorFocus ([string]$operatorFocus.focus)
        }
    $result = [pscustomobject]@{
        status = 'ok'
        path = $Path
        schema_version = [string]$summary.schema_version
        detector_runs_total = $detectorRuns
        detector_fallback_used_total = $detectorFallback
        repair_runs_total = $repairRuns
        repair_success_runs_total = $repairSuccessRuns
        repair_success_rate = $repairSuccessRate
        average_completed_rounds = [double]$summary.average_completed_rounds
        quickcheck_runs_total = $quickcheckRuns
        quickcheck_average_wall_clock_seconds = [double]$summary.quickcheck_average_wall_clock_seconds
            operator_focus = [string]$operatorFocus.focus
            operator_focus_reason = [string]$operatorFocus.reason
            operator_next_actions = $operatorNextActions
            operator_priority_action = $operatorPriorityAction
            operator_priority_level = $operatorPriorityLevel
            operator_task_hint = $operatorTaskHint
            next_step_category = $nextStepCategory
            public_summary = $publicSummary
            operator_snapshot = Get-OperatorSnapshot `
            -OperatorFocus ([string]$operatorFocus.focus) `
            -OperatorFocusReason ([string]$operatorFocus.reason) `
            -OperatorNextActions $operatorNextActions `
            -NextStepCategory $nextStepCategory `
            -OperatorPriorityAction $operatorPriorityAction `
            -OperatorPriorityLevel $operatorPriorityLevel `
            -OperatorTaskHint $operatorTaskHint `
            -PublicSummary $publicSummary `
            -TrendState ([string]$trendState.state) `
            -TrendStateReason ([string]$trendState.reason) `
            -TrendDigest $trendDigest `
            -TrendBreakdown $trendBreakdown
        trend_state = [string]$trendState.state
        trend_state_reason = [string]$trendState.reason
        trend_digest = $trendDigest
        trend_breakdown = $trendBreakdown
        top_issue_types = $topIssueTypes
    }

    if ($AsJson) {
        return ($result | ConvertTo-Json -Depth 6)
    }

    return $result
}
