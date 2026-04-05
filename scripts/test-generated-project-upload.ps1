param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

if ($null -eq $Context) {
  $Context = @{}
}

if (-not $Context.ContainsKey('GeneratedNotebookProject')) {
  $Context.GeneratedNotebookProject = Invoke-WechatBuildFromPrompt `
    -Prompt "build a notebook mini program" `
    -AutoPreview $false
}

$built = $Context.GeneratedNotebookProject
$eligible = $null
if ($Context.ContainsKey('GeneratedNotebookEligibleProject')) {
  $eligible = $Context.GeneratedNotebookEligibleProject
}

$denied = Invoke-GeneratedProjectUpload `
  -ProjectPath $built.project_dir `
  -RequireConfirm $false `
  -DryRun $true
Assert-Equal $denied.status "denied" "tourist appid upload should be denied"
Assert-Equal $denied.reason "tourist_appid_not_deployable" "denied reason should match"

$eligiblePath = $null
$sharedPort = 0
if ($null -ne $eligible -and -not [string]::IsNullOrWhiteSpace([string]$eligible.project_dir)) {
  $eligiblePath = [string]$eligible.project_dir
  $eligibleMetadata = Get-GeneratedProjectMetadata -ProjectPath $eligiblePath
  Assert-Equal $eligibleMetadata.appid "wx1234567890abcdef" "eligible shared fixture should already use a non-tourist appid"
  Assert-Equal $eligibleMetadata.projectname "generated-notebook" "eligible shared fixture should already use the release project name"
  if ($Context.ContainsKey('SharedDevtoolsPort')) {
    $sharedPort = [int]$Context.SharedDevtoolsPort
  }
} else {
  $updated = Invoke-GeneratedProjectSetAppId `
    -ProjectPath $built.project_dir `
    -AppId "wx1234567890abcdef" `
    -ProjectName "generated-notebook" `
    -RequireConfirm $false
  Assert-Equal $updated.status "success" "appid update should succeed before upload dry-run"
  $eligiblePath = $built.project_dir
}

$dryRun = Invoke-GeneratedProjectUpload `
  -ProjectPath $eligiblePath `
  -Version "1.2.3" `
  -Desc "generated dry-run" `
  -Port $sharedPort `
  -RequireConfirm $false `
  -DryRun $true
Assert-Equal $dryRun.status "dry_run" "eligible generated project should reach upload dry-run"
Assert-Equal $dryRun.version "1.2.3" "version should be preserved"
Assert-True ($dryRun.port -gt 0) "dry-run should include a detected port"

if ($eligiblePath -eq $built.project_dir) {
  $reverted = Invoke-GeneratedProjectSetAppId `
    -ProjectPath $built.project_dir `
    -AppId "touristappid" `
    -ProjectName "notebook-app" `
    -RequireConfirm $false
  Assert-Equal $reverted.appid "touristappid" "appid should revert after upload dry-run"
}

New-TestResult -Name "generated-project-upload" -Data @{
  pass        = $true
  exit_code   = 0
  project_dir = $built.project_dir
  status      = $dryRun.status
}
