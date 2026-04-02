param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$recommendWrite = Invoke-WechatTask -TaskText 'add log for order query' -RecommendOnly
Assert-True ($null -ne $recommendWrite) 'recommend should return a candidate for write-like text'
Assert-Equal $recommendWrite.label 'write-log-getorder' 'getOrder should be the top write recommendation'
Assert-Equal $recommendWrite.requires_confirmation $true 'top write recommendation should require confirmation'

$recommendPreview = Invoke-WechatTask -TaskText 'please preview qrcode' -RecommendOnly
Assert-True ($null -ne $recommendPreview) 'recommend should return a candidate for preview text'
Assert-Equal $recommendPreview.label 'preview-current-project' 'preview should be the top recommendation for preview text'
Assert-Equal $recommendPreview.safe $true 'preview recommendation should be safe'

$handoff = Invoke-WechatTask -TaskText 'please preview qrcode' -HandoffOnly
Assert-Equal $handoff.guard_status 'safe_to_run' 'safe recommendation should produce safe_to_run handoff guard status'
Assert-Equal $handoff.recommended.label 'preview-current-project' 'handoff recommended candidate should match recommend-only result'

New-TestResult -Name 'wechat-task-dispatch-recommend' -Data @{
    pass = $true
    exit_code = 0
    write_recommendation = $recommendWrite.label
    preview_recommendation = $recommendPreview.label
    handoff_guard_status = $handoff.guard_status
}
