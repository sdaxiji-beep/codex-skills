param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$taskText = 'build a coupon center mini program with an empty-state page, a claim coupon CTA, simple coupon rules text, and a clean mobile-first layout'
$result = Invoke-WechatTask -TaskText $taskText

Assert-In $result.status @('success', 'blocked', 'failed') 'coupon empty-state routed execution should return a terminal status'
Assert-Equal $result.intent 'generated-product' 'coupon empty-state routed execution should use generated-product intent'
Assert-Equal $result.route.mode 'coupon-empty-state' 'coupon empty-state routed execution should use coupon-empty-state mode'
Assert-True ($null -ne $result.result) 'coupon empty-state routed execution should return a nested result'
Assert-True (($result.result.project_dir -match '[\\/]generated[\\/]') -and (-not ($result.result.project_dir -like 'D:\卤味*'))) 'coupon empty-state routed execution should stay in generated path'
Assert-True ($null -ne $result.result.repair_loop) 'coupon empty-state routed execution should run repair loop'
Assert-Equal $result.result.project_identity.app_title 'Coupon Center' 'coupon empty-state routed execution should override notebook app title'
Assert-Equal $result.result.project_identity.project_name 'coupon-center-app' 'coupon empty-state routed execution should override notebook project name'

New-TestResult -Name 'wechat-task-product-coupon-empty-state-repair-loop' -Data @{
    pass = $true
    exit_code = 0
    status = $result.status
    route_mode = $result.route.mode
    repair_loop_status = $result.result.repair_loop.status
    repair_loop_reason = $result.result.repair_loop.reason
    project_dir = $result.result.project_dir
    app_title = $result.result.project_identity.app_title
    project_name = $result.result.project_identity.project_name
}
