param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"

if ($null -eq $Context) {
  $Context = @{}
}

if ($Context.ContainsKey('GeneratedShoplistProject') -and $null -ne $Context.GeneratedShoplistProject) {
  $r = $Context.GeneratedShoplistProject
} else {
  $r = Invoke-WechatBuildFromPrompt `
    -Prompt "build a shop list mini program" `
    -AutoPreview $false
}
Assert-Equal $r.status "success" "shoplist build should succeed"
Assert-Equal $r.template "shoplist" "template should be shoplist"
Assert-True (Test-Path $r.project_dir) "project dir should exist"
Assert-True (Test-Path "$($r.project_dir)\app.json") "app.json should exist"
Assert-True (Test-Path "$($r.project_dir)\pages\index\index.js") "shoplist index page should exist"

New-TestResult -Name "build-from-prompt-shoplist" -Data @{
  pass        = $true
  exit_code   = 0
  template    = $r.template
  project_dir = $r.project_dir
}
