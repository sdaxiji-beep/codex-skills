param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-build-from-prompt.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

$built = Invoke-WechatBuildFromPrompt `
  -Prompt "build a notebook mini program" `
  -AutoPreview $false

$projects = @(Get-GeneratedProjectList)
Assert-True ($projects.Count -gt 0) "generated project list should not be empty"

$resolved = Resolve-GeneratedProjectPath -ProjectPath $built.project_dir
Assert-Equal $resolved $built.project_dir "resolved project path should match the built path"

$metadata = Get-GeneratedProjectMetadata -ProjectPath $built.project_dir
Assert-Equal $metadata.template "notebook" "metadata template should be notebook"
Assert-Equal $metadata.appid "touristappid" "generated project should use tourist appid"

$guard = Invoke-GeneratedProjectDeployGuard -ProjectPath $built.project_dir
Assert-Equal $guard.status "denied" "touristappid project should not be deployable"
Assert-Equal $guard.reason "tourist_appid_not_deployable" "deploy guard reason should match"

$outsideRejected = $false
try {
  $repoRoot = Split-Path $PSScriptRoot -Parent
  Resolve-GeneratedProjectPath -ProjectPath (Join-Path $repoRoot 'templates\\notebook') | Out-Null
} catch {
  $outsideRejected = $true
}
Assert-True $outsideRejected "outside path should be rejected"

New-TestResult -Name "generated-project" -Data @{
  pass        = $true
  exit_code   = 0
  project_dir = $built.project_dir
  guard       = $guard.status
}
