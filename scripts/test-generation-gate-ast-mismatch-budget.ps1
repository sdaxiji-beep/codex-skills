param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactDir = Join-Path $repoRoot 'artifacts\wechat-devtools\generation-gate'

$windowMinutesRaw = [string]$env:WECHAT_AST_MISMATCH_WINDOW_MINUTES
$windowMinutes = 120
if (-not [string]::IsNullOrWhiteSpace($windowMinutesRaw) -and ($windowMinutesRaw -as [int])) {
    $windowMinutes = [int]$windowMinutesRaw
}

$mismatchBudgetRaw = [string]$env:WECHAT_AST_MISMATCH_BUDGET
$mismatchBudget = 0
if (-not [string]::IsNullOrWhiteSpace($mismatchBudgetRaw) -and ($mismatchBudgetRaw -as [int]) -ge 0) {
    $mismatchBudget = [int]$mismatchBudgetRaw
}

$diagnosticBudgetRaw = [string]$env:WECHAT_AST_DIAGNOSTIC_ISSUE_BUDGET
$diagnosticBudget = 0
if (-not [string]::IsNullOrWhiteSpace($diagnosticBudgetRaw) -and ($diagnosticBudgetRaw -as [int]) -ge 0) {
    $diagnosticBudget = [int]$diagnosticBudgetRaw
}

if (-not (Test-Path $artifactDir)) {
    New-TestResult -Name 'generation-gate-ast-mismatch-budget' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'artifact_dir_not_found'
    }
    return
}

$threshold = (Get-Date).ToUniversalTime().AddMinutes(-1 * $windowMinutes)
$candidates = Get-ChildItem -Path $artifactDir -File | Where-Object {
    $_.Name -like 'ast-shadow-*.json' -or $_.Name -like 'component-ast-shadow-*.json'
}
$selected = @($candidates | Where-Object { $_.LastWriteTimeUtc -ge $threshold })

if ($selected.Count -eq 0) {
    New-TestResult -Name 'generation-gate-ast-mismatch-budget' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'no_artifacts_in_window'
        window_minutes = $windowMinutes
    }
    return
}

$records = @()
$parseFailures = 0
foreach ($file in $selected) {
    try {
        $obj = Get-Content $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
        $records += [pscustomobject]@{
            file = $file.FullName
            hybrid_mode = [bool]$obj.hybrid_mode
            shadow_mismatch = [bool]$obj.shadow_mismatch
            diagnostics = @($obj.diagnostics)
        }
    }
    catch {
        $parseFailures++
    }
}

$hybridRecords = @($records | Where-Object { $_.hybrid_mode })
$mismatchCount = @($hybridRecords | Where-Object { $_.shadow_mismatch }).Count

$diagnosticIssues = 0
foreach ($record in $hybridRecords) {
    foreach ($diag in @($record.diagnostics)) {
        $hasCode = $diag.PSObject.Properties.Name -contains 'code'
        $hasFile = $diag.PSObject.Properties.Name -contains 'file'
        $hasMessage = $diag.PSObject.Properties.Name -contains 'message'
        $hasSeverity = $diag.PSObject.Properties.Name -contains 'severity'
        if (-not ($hasCode -and $hasFile -and $hasMessage -and $hasSeverity)) {
            $diagnosticIssues++
        }
    }
}

Assert-True ($parseFailures -eq 0) "AST artifact parse failure count exceeded budget. failures=$parseFailures"
Assert-True ($mismatchCount -le $mismatchBudget) "AST mismatch budget exceeded. count=$mismatchCount budget=$mismatchBudget"
Assert-True ($diagnosticIssues -le $diagnosticBudget) "AST diagnostic issue budget exceeded. count=$diagnosticIssues budget=$diagnosticBudget"

New-TestResult -Name 'generation-gate-ast-mismatch-budget' -Data @{
    pass = $true
    exit_code = 0
    window_minutes = $windowMinutes
    selected_artifacts = $selected.Count
    parsed_records = $records.Count
    hybrid_records = $hybridRecords.Count
    mismatch_count = $mismatchCount
    mismatch_budget = $mismatchBudget
    diagnostic_issue_count = $diagnosticIssues
    diagnostic_issue_budget = $diagnosticBudget
}
