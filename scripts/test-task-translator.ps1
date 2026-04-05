param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\\test-common.ps1"
. "$PSScriptRoot\\wechat.ps1"

$translation = Invoke-WechatTaskTranslator -TaskText 'build a coupon center empty-state page with a claim button and rules copy'

Assert-Equal $translation.status 'success' 'minimal translator test should succeed'
Assert-Equal $translation.task_spec.task_intent 'generated-product' 'minimal translator test should produce generated-product intent'
Assert-Equal $translation.task_spec.route_mode 'coupon-empty-state' 'minimal translator test should produce coupon-empty-state route'

New-TestResult -Name 'task-translator' -Data @{
  pass = $true
  exit_code = 0
  task_intent = $translation.task_spec.task_intent
  route_mode = $translation.task_spec.route_mode
}
