param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldPromoted = $env:WECHAT_AST_PROMOTED_SEVERITIES

try {
    Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue

    $pageDefaultHybrid = Get-GenerationGateV1AstHybridMode
    $componentDefaultHybrid = Get-GenerationGateComponentV1AstHybridMode
    Assert-Equal $pageDefaultHybrid $true 'Page gate default hybrid should be on'
    Assert-Equal $componentDefaultHybrid $true 'Component gate default hybrid should be on'

    $pageDefaultPromoted = @((Get-GenerationGateV1AstPromotedSeverities) | Sort-Object)
    $componentDefaultPromoted = @((Get-GenerationGateComponentV1AstPromotedSeverities) | Sort-Object)
    Assert-Equal ($pageDefaultPromoted -join ',') 'error' 'Page gate default promoted severities should be error'
    Assert-Equal ($componentDefaultPromoted -join ',') 'error' 'Component gate default promoted severities should be error'

    $env:WECHAT_AST_HYBRID_MODE = 'off'
    $env:WECHAT_AST_PROMOTED_SEVERITIES = 'warn,error'
    $pageCustomHybrid = Get-GenerationGateV1AstHybridMode
    $componentCustomHybrid = Get-GenerationGateComponentV1AstHybridMode
    Assert-Equal $pageCustomHybrid $false 'Page gate should parse hybrid off'
    Assert-Equal $componentCustomHybrid $false 'Component gate should parse hybrid off'

    $pageCustomPromoted = @((Get-GenerationGateV1AstPromotedSeverities) | Sort-Object)
    $componentCustomPromoted = @((Get-GenerationGateComponentV1AstPromotedSeverities) | Sort-Object)
    Assert-Equal ($pageCustomPromoted -join ',') 'error,warn' 'Page gate should parse custom promoted severities'
    Assert-Equal ($componentCustomPromoted -join ',') 'error,warn' 'Component gate should parse custom promoted severities'

    New-TestResult -Name 'generation-gate-ast-policy-parity' -Data @{
        pass = $true
        exit_code = 0
        default_promoted = ($pageDefaultPromoted -join ',')
        custom_promoted = ($pageCustomPromoted -join ',')
        custom_hybrid = $pageCustomHybrid
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldPromoted) { Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_PROMOTED_SEVERITIES = $oldPromoted }
}
