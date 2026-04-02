param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$resolved = Invoke-WechatTask -TaskText 'run readonly check now' -ResolveOnly
Assert-Equal $resolved.intent 'readonly-check' 'readonly check text should resolve to readonly-check intent'
Assert-Equal $resolved.mode 'readonly-check' 'readonly check text should resolve to readonly-check mode'

$suggestions = @(Invoke-WechatTask -TaskText 'mcp status check' -SuggestOnly)
Assert-True ($suggestions.Count -ge 1) 'readonly check text should produce at least one suggestion'
Assert-Equal $suggestions[0].label 'readonly-mcp-check' 'readonly-mcp-check should be top suggestion for readonly check text'

$run = Invoke-WechatTask -TaskText 'run readonly check now'
Assert-Equal $run.intent 'readonly-check' 'dispatch run intent should be readonly-check'
Assert-Equal $run.status 'success' 'readonly check dispatch should return success'
Assert-True ($run.result.stable -eq $true) 'readonly check dispatch result should be stable'

New-TestResult -Name 'wechat-task-dispatch-readonly-check' -Data @{
    pass = $true
    exit_code = 0
    stable = $run.result.stable
}
