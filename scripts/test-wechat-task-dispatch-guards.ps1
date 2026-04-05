param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$handoff = Invoke-WechatTask -TaskText 'add log to getOrder' -HandoffOnly
Assert-Equal $handoff.guard_status 'confirmation_required' 'write route handoff should require explicit confirmation'
Assert-True ($handoff.requires_approval -eq $true) 'write route handoff should mark requires_approval=true'
Assert-True (-not [string]::IsNullOrWhiteSpace($handoff.recommended_spec)) 'write route handoff should include a recommended spec path'

$blocked = Invoke-WechatTask -TaskText 'add log to getOrder'
Assert-Equal $blocked.status 'confirmation_required' 'write route should be blocked by default'
Assert-Equal $blocked.error 'unsafe_route_requires_explicit_confirmation' 'blocked write route should return explicit guard error'

$resolved = Invoke-WechatTask -TaskText 'add log to getOrder' -ResolveOnly
Assert-Equal $resolved.intent 'spec' 'write route should still resolve to spec intent when asked to resolve only'
Assert-Equal $resolved.requires_confirmation $true 'write route resolve result should require confirmation'

New-TestResult -Name 'wechat-task-dispatch-guards' -Data @{
    pass = $true
    exit_code = 0
    handoff_guard_status = $handoff.guard_status
    blocked_status = $blocked.status
    resolved_intent = $resolved.intent
}
