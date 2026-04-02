param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$resolved = Invoke-WechatTask -TaskText 'run sandbox dispatcher proof' -ResolveOnly
Assert-Equal $resolved.intent 'spec' 'sandbox route should resolve to spec intent'
Assert-Equal $resolved.mode 'sandbox-execute' 'sandbox route should resolve to sandbox-execute mode'
Assert-True ($resolved.safe -eq $true) 'sandbox route should be safe'
Assert-True (-not [string]::IsNullOrWhiteSpace($resolved.spec_path)) 'sandbox route should provide a spec path'
Assert-True (Test-Path $resolved.spec_path) 'sandbox spec path should exist'

$recommended = Invoke-WechatTask -TaskText 'run sandbox dispatcher proof' -RecommendOnly
Assert-Equal $recommended.label 'sandbox-dispatcher-proof' 'sandbox recommendation should be sandbox-dispatcher-proof'

$createResolved = Invoke-WechatTask -TaskText 'sandbox create file' -ResolveOnly
Assert-Equal $createResolved.mode 'sandbox-create' 'create route should resolve to sandbox-create'
Assert-True (Test-Path $createResolved.spec_path) 'create route spec should exist'

$rollbackResolved = Invoke-WechatTask -TaskText 'sandbox modify app.js rollback' -ResolveOnly
Assert-Equal $rollbackResolved.mode 'sandbox-modify-rollback' 'rollback route should resolve to sandbox-modify-rollback'
Assert-True (Test-Path $rollbackResolved.spec_path) 'rollback route spec should exist'

New-TestResult -Name 'wechat-task-dispatch-sandbox' -Data @{
    pass = $true
    exit_code = 0
    resolved_mode = $resolved.mode
    recommended_label = $recommended.label
    create_mode = $createResolved.mode
    rollback_mode = $rollbackResolved.mode
}
