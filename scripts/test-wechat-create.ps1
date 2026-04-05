param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$result = Invoke-WechatCreate `
  -Prompt "build a notebook mini program" `
  -Open $false `
  -Preview $false `
  -RunFastGate $false

Assert-Equal $result.status "success" "create should succeed"
Assert-Equal $result.template "notebook" "should match notebook template"
Assert-True (Test-Path $result.project_dir) "project dir should exist"
Assert-Equal $result.open_status "skipped" "open should be skipped in unit test"
Assert-Equal $result.preview_status "skipped" "preview should be skipped in unit test"
Assert-Equal $result.fast_gate.status "skipped" "fast gate should be skipped in unit test"
Assert-True (Test-Path (Join-Path $result.project_dir "app.json")) "app.json should exist"

$result2 = Invoke-WechatCreate `
  -Prompt "build a notebook mini program" `
  -Open $false `
  -Preview $false `
  -RunFastGate $false
Assert-True ($result2.project_dir -ne $result.project_dir) "project dir should be unique across consecutive creates"

New-TestResult -Name "wechat-create" -Data @{
  pass        = $true
  exit_code   = 0
  template    = $result.template
  project_dir = $result.project_dir
}
