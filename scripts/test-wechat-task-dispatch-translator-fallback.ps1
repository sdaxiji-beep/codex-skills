param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$task = 'build a menu showcase mini program homepage with price cards and featured picks'
$resolved = Invoke-WechatTask -TaskText $task -ResolveOnly

Assert-Equal $resolved.intent 'generated-product' 'translator fallback should resolve as generated-product'
Assert-Equal $resolved.mode 'product-listing' 'translator fallback should resolve product-listing mode'
Assert-Equal $resolved.task_family 'product-listing' 'translator fallback should expose task family'
Assert-Equal $resolved.translation_source 'translator' 'translator fallback should record translation source'

$recommended = Invoke-WechatTask -TaskText $task -RecommendOnly
Assert-Equal $recommended.label 'translated-product-listing' 'translator fallback should provide translated recommendation'

New-TestResult -Name 'wechat-task-dispatch-translator-fallback' -Data @{
  pass = $true
  exit_code = 0
  resolved_mode = $resolved.mode
  translation_source = $resolved.translation_source
  recommendation = $recommended.label
}
