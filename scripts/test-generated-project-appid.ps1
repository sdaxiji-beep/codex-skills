param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

$built = Invoke-WechatBuildFromPrompt `
  -Prompt "build a notebook mini program" `
  -AutoPreview $false

$before = Get-GeneratedProjectMetadata -ProjectPath $built.project_dir
Assert-Equal $before.appid "touristappid" "initial appid should be touristappid"

$updated = Invoke-GeneratedProjectSetAppId `
  -ProjectPath $built.project_dir `
  -AppId "wx1234567890abcdef" `
  -ProjectName "generated-notebook" `
  -RequireConfirm $false
Assert-Equal $updated.status "success" "appid update should succeed"
Assert-Equal $updated.appid "wx1234567890abcdef" "appid should be updated"
Assert-Equal $updated.projectname "generated-notebook" "project name should be updated"

$guard = Invoke-GeneratedProjectDeployGuard -ProjectPath $built.project_dir
Assert-Equal $guard.status "eligible" "non-tourist appid should be eligible"

$reverted = Invoke-GeneratedProjectSetAppId `
  -ProjectPath $built.project_dir `
  -AppId "touristappid" `
  -ProjectName "notebook-app" `
  -RequireConfirm $false
Assert-Equal $reverted.appid "touristappid" "appid should revert to touristappid"

New-TestResult -Name "generated-project-appid" -Data @{
  pass        = $true
  exit_code   = 0
  project_dir = $built.project_dir
  appid       = $updated.appid
}
