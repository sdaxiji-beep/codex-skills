param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

$built = Invoke-WechatBuildFromPrompt `
  -Prompt "build a notebook mini program" `
  -AutoPreview $false

$denied = Invoke-GeneratedProjectUpload `
  -ProjectPath $built.project_dir `
  -RequireConfirm $false `
  -DryRun $true
Assert-Equal $denied.status "denied" "tourist appid upload should be denied"
Assert-Equal $denied.reason "tourist_appid_not_deployable" "denied reason should match"

$updated = Invoke-GeneratedProjectSetAppId `
  -ProjectPath $built.project_dir `
  -AppId "wx1234567890abcdef" `
  -ProjectName "generated-notebook" `
  -RequireConfirm $false
Assert-Equal $updated.status "success" "appid update should succeed before upload dry-run"

$dryRun = Invoke-GeneratedProjectUpload `
  -ProjectPath $built.project_dir `
  -Version "1.2.3" `
  -Desc "generated dry-run" `
  -RequireConfirm $false `
  -DryRun $true
Assert-Equal $dryRun.status "dry_run" "eligible generated project should reach upload dry-run"
Assert-Equal $dryRun.version "1.2.3" "version should be preserved"
Assert-True ($dryRun.port -gt 0) "dry-run should include a detected port"

$reverted = Invoke-GeneratedProjectSetAppId `
  -ProjectPath $built.project_dir `
  -AppId "touristappid" `
  -ProjectName "notebook-app" `
  -RequireConfirm $false
Assert-Equal $reverted.appid "touristappid" "appid should revert after upload dry-run"

New-TestResult -Name "generated-project-upload" -Data @{
  pass        = $true
  exit_code   = 0
  project_dir = $built.project_dir
  status      = $dryRun.status
}
