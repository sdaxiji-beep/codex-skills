param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"

$r = Invoke-WechatBuildFromPrompt `
  -Prompt "build a todo list mini program" `
  -AutoPreview $false
Assert-Equal $r.status "success" "todo build should succeed"
Assert-Equal $r.template "todo" "template should be todo"
Assert-True (Test-Path $r.project_dir) "project dir should exist"
Assert-True (Test-Path "$($r.project_dir)\app.json") "app.json should exist"
Assert-True (Test-Path "$($r.project_dir)\pages\index\index.js") "todo index page should exist"

New-TestResult -Name "build-from-prompt-todo" -Data @{
  pass        = $true
  exit_code   = 0
  template    = $r.template
  project_dir = $r.project_dir
}
