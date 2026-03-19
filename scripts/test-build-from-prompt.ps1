param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"

$r = Invoke-WechatBuildFromPrompt `
  -Prompt "build a notebook mini program" `
  -AutoPreview $false
Assert-Equal $r.status "success" "build should succeed"
Assert-Equal $r.template "notebook" "template should be notebook"
Assert-True (Test-Path $r.project_dir) "project dir should exist"
Assert-True (Test-Path "$($r.project_dir)\app.json") "app.json should exist"
Assert-True (Test-Path "$($r.project_dir)\pages\index\index.js") "index page should exist"

$r2 = Invoke-WechatBuildFromPrompt `
  -Prompt "build an unknown app type" `
  -AutoPreview $false
Assert-Equal $r2.status "success" "unknown type should fallback to notebook"
Assert-Equal $r2.template "notebook" "fallback template should be notebook"

Write-Host "[TEST] generated project dir: $($r.project_dir)"
New-TestResult -Name "build-from-prompt" -Data @{
  pass        = $true
  exit_code   = 0
  template    = $r.template
  project_dir = $r.project_dir
}
