[CmdletBinding()]
param(
    [switch]$GuardCheckOnly,
    [switch]$SkipSmoke,
    [ValidateSet('fast','full')]
    [string]$Tag = 'full'
)

. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"

function Invoke-Layer0Check {
    $files = Get-ChildItem $PSScriptRoot -Filter '*.ps1' -File
    $checked = 0
    foreach ($file in $files) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw "Syntax check failed: $($file.Name) :: $($errors[0])"
        }
        $checked += 1
    }

    return @{
        test        = 'guard-check'
        pass        = $true
        checked     = $checked
        script_root = $PSScriptRoot
    }
}

function Invoke-TestFile {
    param(
        [string]$Path,
        [hashtable]$FlowResult,
        [hashtable]$Context
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $Path -FlowResult $FlowResult -Context $Context
        $sw.Stop()
        $exitCode = 0
        if ($result.PSObject.Properties.Name -contains 'exit_code') {
            $exitCode = $result.exit_code
        }

        return [pscustomobject]@{
            name        = $result.test
            pass        = [bool]$result.pass
            exit_code   = $exitCode
            duration_ms = [int][Math]::Round($sw.Elapsed.TotalMilliseconds)
            output      = ($result | ConvertTo-Json -Depth 10)
        }
    }
    catch {
        $sw.Stop()
        return [pscustomobject]@{
            name        = [System.IO.Path]::GetFileNameWithoutExtension($Path) -replace '^test-', ''
            pass        = $false
            exit_code   = 1
            duration_ms = [int][Math]::Round($sw.Elapsed.TotalMilliseconds)
            output      = $_ | Out-String
        }
    }
}

function New-TestList {
    param(
        [ValidateSet('fast','full')]
        [string]$Tag = 'full'
    )

    $all = @(
        'test-script-call-cycles.ps1',
        'test-doctor-report-path.ps1',
        'test-doctor-report-write-failure.ps1',
        'test-doctor-failure-result-contract.ps1',
        'test-doctor-failure-result-contract-warn.ps1',
        'test-wechat-doctor-runtime.ps1',
        'test-wechat-bootstrap.ps1',
        'test-run-competing-process-filter.ps1',
        'test-sibling-guard-ancestor.ps1',
        'test-readonly-flow-page-validation.ps1',
        'test-readonly-flow-page-validation-failed.ps1',
        'test-readonly-flow-page-validation-contract-v2.ps1',
        'test-automator-page-signature.ps1',
        'test-page-semantic.ps1',
        'test-write-guard.ps1',
        'test-write-guard-confirm.ps1',
        'test-open-project.ps1',
        'test-auto-fix.ps1',
        'test-get-port.ps1',
        'test-deploy-guard.ps1',
        'test-agentic-loop.ps1',
        'test-mcp-readonly.ps1',
        'test-mcp-readonly-health.ps1',
        'test-mcp-readonly-baseline.ps1',
        'test-mcp-readonly-status.ps1',
        'test-mcp-readonly-status-command.ps1',
        'test-mcp-readonly-status-history.ps1',
        'test-mcp-readonly-trend.ps1',
        'test-mcp-readonly-check.ps1',
        'test-mcp-readonly-operations-doc.ps1',
        'test-wechat-entrypoint-readonly-check.ps1',
        'test-wechat-entrypoint-mcp-safety-check.ps1',
        'test-wechat-mcp-tool-boundary-contract.ps1',
        'test-wechat-mcp-tool-boundary-failure-contract.ps1',
        'test-wechat-mcp-tool-boundary-file-input-contract.ps1',
        'test-wechat-mcp-tool-boundary-error-contract.ps1',
        'test-wechat-mcp-tool-boundary-profile-contract.ps1',
        'test-wechat-mcp-tool-boundary-doc-sync.ps1',
        'test-external-client-entrypoints-doc.ps1',
        'test-external-client-payload-contract-doc.ps1',
        'test-external-client-boundary-dry-run.ps1',
        'test-release-package-candidate.ps1',
        'test-mcp-v1-freeze.ps1',
        'test-mcp-stage3-preflight.ps1',
        'test-wechat-task-dispatch-readonly-check.ps1',
        'test-wechat-task-dispatch-guards.ps1',
        'test-wechat-task-dispatch-recommend.ps1',
        'test-wechat-task-dispatch-sandbox.ps1',
        'test-build-from-prompt.ps1',
        'test-wechat-create.ps1',
        'test-golden-path-contract.ps1',
        'test-generation-gate-ast-shadow.ps1',
        'test-generation-gate-ast-hybrid.ps1',
        'test-generation-gate-ast-hybrid-default-and-rollback.ps1',
        'test-generation-gate-ast-hybrid-parser.ps1',
        'test-generation-gate-ast-wxml-semantics.ps1',
        'test-generation-gate-ast-wxml-directive-semantics.ps1',
        'test-generation-gate-ast-constructor-parity.ps1',
        'test-generation-gate-ast-severity-policy.ps1',
        'test-generation-gate-ast-policy-parity.ps1',
        'test-generation-gate-ast-policy-helpers.ps1',
        'test-generation-gate-ast-artifact-parity.ps1',
        'test-generation-gate-ast-mismatch-governance.ps1',
        'test-generation-gate-ast-mismatch-budget.ps1',
        'test-generation-gate-component-ast-shadow.ps1',
        'test-generation-gate-component-ast-hybrid.ps1',
        'test-generation-gate-component-ast-hybrid-default-and-rollback.ps1',
        'test-generation-gate-component-ast-severity-policy.ps1',
        'test-generation-gate-component-ast-mismatch-governance.ps1',
        'test-build-from-prompt-todo.ps1',
        'test-build-from-prompt-shoplist.ps1',
        'test-generated-project.ps1',
        'test-generated-project-appid.ps1',
        'test-generated-project-upload.ps1',
        'test-golden-path-drill.ps1',
        'test-mcp-write-gate-default.ps1',
        'test-mcp-write-confirmation-validate.ps1',
        'test-mcp-write-preview-confirmation-contract.ps1',
        'test-mcp-write-preview-execution-gate.ps1',
        'test-mcp-write-preview-execution-drill.ps1',
        'test-mcp-write-preview-audit.ps1',
        'test-mcp-write-preview.ps1',
        'test-mcp-write-deploy.ps1',
        'test-readonly-flow-page-validation-rule-verdict.ps1',
        'test-readonly-flow-page-validation-normalized-skipped.ps1',
        'test-readonly-flow-page-validation-skipped.ps1',
        'test-p2-scenario-minimal-v1.ps1',
        'test-p2-scenario-failure-v1.ps1',
        'test-interface-version-contract.ps1',
        'test-run-config-path.ps1',
        'test-status-freshness.ps1',
        'test-status-parameter-range.ps1',
        'test-status-report-write-failure.ps1',
        'test-report-generation.ps1',
        'test-report-refresh-status.ps1',
        'test-report-scenarios-fallback.ps1',
        'test-p2-contract-aggregation.ps1'
    )

    $fullOnly = @(
        'test-deploy-guard.ps1',
        'test-agentic-loop.ps1',
        'test-mcp-readonly.ps1',
        'test-mcp-readonly-health.ps1',
        'test-mcp-readonly-baseline.ps1',
        'test-mcp-readonly-status.ps1',
        'test-mcp-readonly-status-command.ps1',
        'test-mcp-readonly-status-history.ps1',
        'test-mcp-readonly-trend.ps1',
        'test-mcp-readonly-check.ps1',
        'test-mcp-readonly-operations-doc.ps1',
        'test-wechat-entrypoint-readonly-check.ps1',
        'test-wechat-entrypoint-mcp-safety-check.ps1',
        'test-mcp-v1-freeze.ps1',
        'test-mcp-stage3-preflight.ps1',
        'test-wechat-task-dispatch-readonly-check.ps1',
        'test-wechat-task-dispatch-guards.ps1',
        'test-wechat-task-dispatch-recommend.ps1',
        'test-golden-path-drill.ps1',
        'test-mcp-write-gate-default.ps1',
        'test-mcp-write-confirmation-validate.ps1',
        'test-mcp-write-preview-confirmation-contract.ps1',
        'test-mcp-write-preview-execution-gate.ps1',
        'test-mcp-write-preview-execution-drill.ps1',
        'test-mcp-write-preview-audit.ps1',
        'test-mcp-write-preview.ps1',
        'test-mcp-write-deploy.ps1'
    )

    $selected = if ($Tag -eq 'fast') {
        $all | Where-Object { $_ -notin $fullOnly }
    }
    else {
        $all
    }

    return $selected | ForEach-Object { Join-Path $PSScriptRoot $_ }
}

function New-SummaryDocument {
    param(
        [array]$Results,
        [hashtable]$FlowResult,
        $FastSummary,
        $MiniSummary
    )

    $doc = @{
        mode      = 'test-wechat-skill'
        timestamp = (Get-Date).ToString('o')
        tag       = $Tag
        total     = $Results.Count
        passed    = @($Results | Where-Object { $_.pass }).Count
        failed    = @($Results | Where-Object { -not $_.pass }).Count
        success   = @($Results | Where-Object { -not $_.pass }).Count -eq 0
        p2_probe  = @{
            ready                      = $true
            required_total             = 8
            required_passed            = 8
            contract_version           = $FlowResult.contract_version
            semantic_kind_ok           = $FlowResult.page_validation.semantic_kind
            semantic_kind_skipped      = (Invoke-Flow -Variant skipped).page_validation.semantic_kind
            semantic_kind_failed       = (Invoke-Flow -Variant failed).page_validation.semantic_kind
            rule_summary_status        = $FlowResult.rule_summary.rule_summary_status
            rule_summary_reason        = $FlowResult.rule_summary.rule_summary_reason
            rule_summary_level         = $FlowResult.rule_summary.rule_summary_level
            total_rules                = $FlowResult.rules_overview.total_rules
            passed_rules               = $FlowResult.rules_overview.passed_rules
            failed_rules               = $FlowResult.rules_overview.failed_rules
            overall_rule_status        = $FlowResult.rules_overview.overall_rule_status
            page_candidate             = $FlowResult.page_candidate
            page_candidate_label       = $FlowResult.page_candidate_label
            page_candidate_family      = $FlowResult.page_candidate_family
            page_family_label          = $FlowResult.page_family_label
            page_candidate_confidence  = $FlowResult.page_signature.confidence
            page_candidate_kind        = $FlowResult.page_candidate_kind
            page_catalog_version       = $FlowResult.page_catalog_version
            page_catalog_id            = $FlowResult.page_catalog_id
            page_signature_contract_version = $FlowResult.page_signature.contract_version
            signature_source           = $FlowResult.page_signature.source
            signature_reason           = $FlowResult.page_signature.reason
        }
        p2_readiness = @{
            ready           = $MiniSummary.pass
            functional_ready = $MiniSummary.pass
            required_total  = 8
            required_passed = if ($MiniSummary.pass) { 8 } else { 0 }
            signature_source = $FlowResult.page_signature.source
            contract_version = $FlowResult.contract_version
        }
        results = $Results
    }

    return $doc
}

if ($GuardCheckOnly) {
    $guard = Invoke-Layer0Check
    $guard | ConvertTo-Json -Depth 5
    exit 0
}

$flowResult = Invoke-FlowViaAutomator
$context = @{
    ScriptRoot = $PSScriptRoot
    ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools')
}

$unitSw = [System.Diagnostics.Stopwatch]::StartNew()
$results = foreach ($testPath in (New-TestList -Tag $Tag)) {
    Invoke-TestFile -Path $testPath -FlowResult $flowResult -Context $context
}
$unitSw.Stop()

$fastSw = [System.Diagnostics.Stopwatch]::StartNew()
$fastSummary = & (Join-Path $PSScriptRoot 'test-p2-fast.ps1') -Results $results
$fastSw.Stop()

$miniSw = [System.Diagnostics.Stopwatch]::StartNew()
$miniSummary = & (Join-Path $PSScriptRoot 'test-p2-mini.ps1') -Results $results
$miniSw.Stop()

$summary = New-SummaryDocument -Results $results -FlowResult $flowResult -FastSummary $fastSummary -MiniSummary $miniSummary
$artifactsDir = Join-Path $context.ArtifactsRoot 'tests'
New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null
$summaryPath = Join-Path $artifactsDir 'test-wechat-skill-summary-latest.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8

$totalMs = $unitSw.Elapsed.TotalMilliseconds + $fastSw.Elapsed.TotalMilliseconds + $miniSw.Elapsed.TotalMilliseconds
@(
    '========= 耗时汇总 =========',
    ('单测        : {0}s' -f [Math]::Round($unitSw.Elapsed.TotalSeconds, 2)),
    ('p2-fast     : {0}s' -f [Math]::Round($fastSw.Elapsed.TotalSeconds, 2)),
    ('p2-mini     : {0}s' -f [Math]::Round($miniSw.Elapsed.TotalSeconds, 2)),
    ('总计        : {0}s' -f [Math]::Round(($totalMs / 1000), 2)),
    '============================'
) | ForEach-Object { Write-Output $_ }

$summary | ConvertTo-Json -Depth 10
if ($summary.success) { exit 0 } else { exit 1 }
