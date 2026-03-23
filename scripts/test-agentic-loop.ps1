param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-agentic-loop.ps1"
. "$PSScriptRoot\wechat-task-dispatch.ps1"

$result = Invoke-AgenticLoop `
    -Task 'test Ralph Loop' `
    -DeployTarget 'none' `
    -AutoMode $true `
    -MaxFixRounds 3 `
    -ValidationMode 'embedded'

Assert-True ($result.status -in @('validated', 'done')) 'agentic loop should complete'
Assert-True (@($result.steps).Count -ge 1) 'agentic loop should produce at least one step'
$validateStep = @($result.steps | Where-Object { $_.step -eq 'validate' })[0]
Assert-NotEmpty $validateStep 'validate step should exist'
Assert-Equal $validateStep.status 'success' 'embedded validation should pass'
Assert-True ($result.elapsed_s -lt 60) 'agentic loop should finish in under 60 seconds'

$commandValidation = Invoke-AgenticValidation `
    -ValidationMode 'command' `
    -ValidationCommand "Write-Output 'ok'; exit 0"
Assert-Equal $commandValidation.status 'success' 'command validation should pass for a zero-exit command'
Assert-Equal $commandValidation.passed 1 'command validation should report one passing validation step'

$repoRoot = Split-Path $PSScriptRoot -Parent
$loopStatePath = Join-Path $repoRoot 'artifacts\loop-state.json'
Assert-True (Test-Path $loopStatePath) 'loop-state.json must exist'

$env:WRITE_GUARD_AUTO_CONFIRM = 'no'
$cancelled = Invoke-AgenticLoop `
    -Task 'cancel preview deploy' `
    -DeployTarget 'preview' `
    -AutoMode $false `
    -MaxFixRounds 3 `
    -ValidationMode 'embedded'
Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue

Assert-Equal $cancelled.status 'done' 'cancelled deploy loop should still complete'
$deployStep = @($cancelled.steps | Where-Object { $_.step -eq 'deploy' })[0]
Assert-NotEmpty $deployStep 'deploy step should exist'
Assert-Equal $deployStep.status 'cancelled' 'preview deploy should be cancelled by confirmation guard'

$specPath = Join-Path $repoRoot 'specs\task-deploy-changed.json'
Assert-True (Test-Path $specPath) 'spec file should exist'
$env:WRITE_GUARD_AUTO_CONFIRM = 'no'
$specRun = Invoke-AgenticLoopFromSpec -SpecPath $specPath -ValidationModeOverride 'embedded'
Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue
Assert-True ($specRun.status -in @('validated', 'done')) 'spec-driven agentic loop should complete'
Assert-True (@($specRun.steps).Count -ge 2) 'spec-driven run should include validate and deploy'

$previewRoute = Invoke-WechatTask -TaskText 'preview current project' -ResolveOnly
Assert-Equal $previewRoute.intent 'spec' 'preview text should resolve to a spec route'
Assert-Equal $previewRoute.mode 'preview' 'preview text should resolve to preview mode'
Assert-True (Test-Path $previewRoute.spec_path) 'preview route spec should exist'

$validationRoute = Invoke-WechatTask -TaskText 'run layer 4 validation' -ResolveOnly
Assert-Equal $validationRoute.intent 'validation' 'validation text should resolve to validation route'

$diagnosticRoute = Invoke-WechatTask -TaskText 'run a read-only cloud function diagnostic' -ResolveOnly
Assert-Equal $diagnosticRoute.mode 'list-functions' 'diagnostic text should resolve to list-functions mode'

$writeRoute = Invoke-WechatTask -TaskText 'add log to order function' -ResolveOnly
Assert-Equal $writeRoute.intent 'unknown' 'public dispatcher should not route business-specific write intents'

$writeBlocked = Invoke-WechatTask -TaskText 'add log to order function'
Assert-Equal $writeBlocked.status 'unroutable' 'business-specific write intents should stay unroutable in the public repo'

$suggestions = @(Invoke-WechatTask -TaskText 'add log to order function' -SuggestOnly)
Assert-True ($suggestions.Count -eq 0) 'public dispatcher should not suggest private business write routes'

$recommended = Invoke-WechatTask -TaskText 'add log to order function' -RecommendOnly
Assert-True ($null -eq $recommended) 'public dispatcher should not recommend private business write routes'

$handoff = Invoke-WechatTask -TaskText 'add log to order function' -HandoffOnly
Assert-NotEmpty $handoff 'handoff object should still be produced'
Assert-Equal $handoff.guard_status 'no_match' 'public dispatcher should report no_match for private business write intents'
Assert-True (-not $handoff.requires_approval) 'no approval should be requested when no route matches'

$unknownRoute = Invoke-WechatTask -TaskText 'do something completely unrelated' -ResolveOnly
Assert-Equal $unknownRoute.intent 'unknown' 'unknown text should stay unresolved'

$unknownDispatch = Invoke-WechatTask -TaskText 'do something completely unrelated'
Assert-Equal $unknownDispatch.status 'unroutable' 'unknown task should remain unroutable'
Assert-True (@($unknownDispatch.suggestions).Count -eq 0) 'unrelated text should not invent suggestions'
Assert-True ($null -eq $unknownDispatch.recommended) 'unrelated text should not invent a recommended task'

$unknownHandoff = Invoke-WechatTask -TaskText 'do something completely unrelated' -HandoffOnly
Assert-Equal $unknownHandoff.guard_status 'no_match' 'unknown handoff should report no_match'

New-TestResult -Name 'agentic-loop' -Data @{
    pass      = $true
    exit_code = 0
    elapsed_s = $result.elapsed_s
    steps     = @($result.steps).Count
}
