[CmdletBinding()]
param(
    [switch]$GuardCheckOnly,
    [switch]$SkipSmoke,
    [ValidateSet('fast','full')]
    [string]$Tag = 'full'
)

. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Get-SharedDiagnosticsQuickCheck.ps1"
. "$PSScriptRoot\Get-SharedDoctorFixtures.ps1"
. "$PSScriptRoot\Get-SharedReadonlyFlow.ps1"

function ConvertTo-TestHashtableDeep {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[$key] = ConvertTo-TestHashtableDeep -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-TestHashtableDeep -InputObject $property.Value
        }
        return $table
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $InputObject) {
            [void]$items.Add((ConvertTo-TestHashtableDeep -InputObject $item))
        }
        return ,($items.ToArray())
    }

    return $InputObject
}

function Copy-FlowResultForTest {
    param([hashtable]$FlowResult)

    $json = $FlowResult | ConvertTo-Json -Depth 12
    $copy = $json | ConvertFrom-Json -ErrorAction Stop
    return (ConvertTo-TestHashtableDeep -InputObject $copy)
}

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
        $isolatedFlowResult = Copy-FlowResultForTest -FlowResult $FlowResult
        $result = & $Path -FlowResult $isolatedFlowResult -Context $Context
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
        'test-automator-project-port.ps1',
        'test-automator-page-signature.ps1',
        'test-p3-operational-fixtures.ps1',
        'test-p3-operational-cache-stability.ps1',
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
        'test-validation-tiers-doc.ps1',
        'test-cleanup-runtime-data.ps1',
        'test-public-api-surface-doc.ps1',
        'test-external-client-boundary-dry-run.ps1',
        'test-diagnostics-focused.ps1',
        'test-release-package-candidate.ps1',
        'test-mcp-v1-freeze.ps1',
        'test-mcp-stage3-preflight.ps1',
        'test-wechat-task-dispatch-readonly-check.ps1',
        'test-wechat-task-dispatch-guards.ps1',
        'test-wechat-task-dispatch-recommend.ps1',
        'test-wechat-task-dispatch-product-route.ps1',
        'test-wechat-task-dispatch-translator-fallback.ps1',
        'test-wechat-task-dispatch-sandbox.ps1',
        'test-wechat-task-spec.ps1',
        'test-wechat-task-translator.ps1',
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
        'test-wechat-task-product-coupon-empty-state.ps1',
        'test-wechat-task-product-activity-not-started.ps1',
        'test-wechat-task-product-listing.ps1',
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
        'test-p3-operational-fixtures.ps1',
        'test-p3-operational-cache-stability.ps1',
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
        'test-wechat-task-product-coupon-empty-state.ps1',
        'test-wechat-task-product-activity-not-started.ps1',
        'test-wechat-task-product-listing.ps1',
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
        $MiniSummary,
        [hashtable]$PreflightBreakdown,
        [double]$PreflightSeconds,
        [double]$UnitSeconds,
        [double]$P2FastSeconds,
        [double]$P2MiniSeconds,
        [double]$TotalWallSeconds
    )

    $doc = @{
        mode      = 'test-wechat-skill'
        timestamp = (Get-Date).ToString('o')
        tag       = $Tag
        total     = $Results.Count
        passed    = @($Results | Where-Object { $_.pass }).Count
        failed    = @($Results | Where-Object { -not $_.pass }).Count
        success   = @($Results | Where-Object { -not $_.pass }).Count -eq 0
        timing    = @{
            preflight_seconds = [Math]::Round($PreflightSeconds, 2)
            preflight_breakdown = @{
                diagnostics_seconds = [Math]::Round([double]$PreflightBreakdown.DiagnosticsSeconds, 3)
                doctor_seconds = [Math]::Round([double]$PreflightBreakdown.DoctorSeconds, 3)
                p3_fixture_seconds = [Math]::Round([double]$PreflightBreakdown.P3FixtureSeconds, 3)
                readonly_seconds = [Math]::Round([double]$PreflightBreakdown.ReadonlySeconds, 3)
                port_seconds = [Math]::Round([double]$PreflightBreakdown.PortSeconds, 3)
            }
            unit_seconds = [Math]::Round($UnitSeconds, 2)
            p2_fast_seconds = [Math]::Round($P2FastSeconds, 2)
            p2_mini_seconds = [Math]::Round($P2MiniSeconds, 2)
            internal_seconds = [Math]::Round(($UnitSeconds + $P2FastSeconds + $P2MiniSeconds), 2)
            total_wall_seconds = [Math]::Round($TotalWallSeconds, 2)
        }
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

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path $PSScriptRoot -Parent
$preflightSw = [System.Diagnostics.Stopwatch]::StartNew()
$preflightBreakdown = @{
    DiagnosticsSeconds = 0.0
    DoctorSeconds = 0.0
    P3FixtureSeconds = 0.0
    ReadonlySeconds = 0.0
    PortSeconds = 0.0
}
$stepSw = [System.Diagnostics.Stopwatch]::StartNew()
$sharedDiagnostics = Get-SharedDiagnosticsQuickCheckResult -RepoRoot $repoRoot
$stepSw.Stop()
$preflightBreakdown.DiagnosticsSeconds = $stepSw.Elapsed.TotalSeconds
$stepSw.Restart()
$sharedDoctorFixtures = Get-SharedDoctorFixtures -RepoRoot $repoRoot
$stepSw.Stop()
$preflightBreakdown.DoctorSeconds = $stepSw.Elapsed.TotalSeconds
$stepSw.Restart()
$sharedP3Fixtures = Get-SharedP3OperationalFixtures -RepoRoot $repoRoot
$stepSw.Stop()
$preflightBreakdown.P3FixtureSeconds = $stepSw.Elapsed.TotalSeconds
$stepSw.Restart()
$sharedReadonlyFlow = Get-SharedReadonlyFlowResult -RepoRoot $repoRoot
$stepSw.Stop()
$preflightBreakdown.ReadonlySeconds = $stepSw.Elapsed.TotalSeconds
$flowResult = $sharedReadonlyFlow.flowResult
$sharedDevtoolsPort = 0
if ($null -ne $sharedReadonlyFlow -and $sharedReadonlyFlow.PSObject.Properties.Name -contains 'devtoolsPort') {
    $sharedDevtoolsPort = [int]$sharedReadonlyFlow.devtoolsPort
}
if ($sharedDevtoolsPort -le 0 -and $null -ne $flowResult -and $flowResult.ContainsKey('devtools_port')) {
    $sharedDevtoolsPort = [int]$flowResult.devtools_port
}
if ($sharedDevtoolsPort -le 0) {
    $stepSw.Restart()
    $sharedDevtoolsPort = Get-WechatDevtoolsPort
    $stepSw.Stop()
    $preflightBreakdown.PortSeconds = $stepSw.Elapsed.TotalSeconds
}
$preflightSw.Stop()
$context = @{
    ScriptRoot = $PSScriptRoot
    ArtifactsRoot = (Join-Path $repoRoot 'artifacts\wechat-devtools')
    DiagnosticsQuickCheckSummary = $sharedDiagnostics.summary
    DiagnosticsQuickCheckArtifactPath = $sharedDiagnostics.artifactPath
    DoctorSharedResult = $sharedDoctorFixtures.doctorResult
    DoctorReportPathResult = $sharedDoctorFixtures.doctorResult
    DoctorRuntimeResult = $sharedDoctorFixtures.doctorResult
    DoctorSimulatedFailureResult = $sharedDoctorFixtures.doctorFailureResult
    McpBoundaryDescribeContract = $sharedP3Fixtures.describeContract
    McpBoundaryExecutionProfile = $sharedP3Fixtures.executionProfile
    McpBoundaryContracts = $sharedP3Fixtures.boundaryContracts
    McpBoundaryValidWorkspace = $sharedP3Fixtures.boundaryWorkspace
    McpBoundaryValidPayloadPath = $sharedP3Fixtures.boundaryPayloadPath
    ExternalClientDryRunWorkspace = $sharedP3Fixtures.externalWorkspace
    ExternalClientDryRunPayloadPath = $sharedP3Fixtures.externalPayloadPath
    GeneratedNotebookProject = $sharedP3Fixtures.generatedNotebookProject
    GeneratedNotebookEligibleProject = $sharedP3Fixtures.generatedNotebookEligibleProject
    GeneratedTodoProject = $sharedP3Fixtures.generatedTodoProject
    GeneratedShoplistProject = $sharedP3Fixtures.generatedShoplistProject
    SharedDevtoolsPort = $sharedDevtoolsPort
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

$totalSw.Stop()
$summary = New-SummaryDocument `
    -Results $results `
    -FlowResult $flowResult `
    -FastSummary $fastSummary `
    -MiniSummary $miniSummary `
    -PreflightBreakdown $preflightBreakdown `
    -PreflightSeconds $preflightSw.Elapsed.TotalSeconds `
    -UnitSeconds $unitSw.Elapsed.TotalSeconds `
    -P2FastSeconds $fastSw.Elapsed.TotalSeconds `
    -P2MiniSeconds $miniSw.Elapsed.TotalSeconds `
    -TotalWallSeconds $totalSw.Elapsed.TotalSeconds
$artifactsDir = Join-Path $context.ArtifactsRoot 'tests'
New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null
$summaryPath = Join-Path $artifactsDir 'test-wechat-skill-summary-latest.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8

$totalMs = $unitSw.Elapsed.TotalMilliseconds + $fastSw.Elapsed.TotalMilliseconds + $miniSw.Elapsed.TotalMilliseconds
Write-Output '========= Timing Summary ========='
Write-Output ('preflight  : {0}s' -f [Math]::Round($preflightSw.Elapsed.TotalSeconds, 2))
Write-Output ('  diag     : {0}s' -f [Math]::Round([double]$preflightBreakdown.DiagnosticsSeconds, 3))
Write-Output ('  doctor   : {0}s' -f [Math]::Round([double]$preflightBreakdown.DoctorSeconds, 3))
Write-Output ('  p3       : {0}s' -f [Math]::Round([double]$preflightBreakdown.P3FixtureSeconds, 3))
Write-Output ('  readonly : {0}s' -f [Math]::Round([double]$preflightBreakdown.ReadonlySeconds, 3))
Write-Output ('  port     : {0}s' -f [Math]::Round([double]$preflightBreakdown.PortSeconds, 3))
Write-Output ('unit       : {0}s' -f [Math]::Round($unitSw.Elapsed.TotalSeconds, 2))
Write-Output ('p2-fast    : {0}s' -f [Math]::Round($fastSw.Elapsed.TotalSeconds, 2))
Write-Output ('p2-mini    : {0}s' -f [Math]::Round($miniSw.Elapsed.TotalSeconds, 2))
Write-Output ('internal   : {0}s' -f [Math]::Round(($totalMs / 1000), 2))
Write-Output ('wall-clock : {0}s' -f [Math]::Round($totalSw.Elapsed.TotalSeconds, 2))
Write-Output '==============================='
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
