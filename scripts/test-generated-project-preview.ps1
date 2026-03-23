param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-generated-preview-" + [guid]::NewGuid().ToString('N'))
$projectDir = Join-Path $tempRoot 'generated\preview-case'
New-Item -ItemType Directory -Path $projectDir -Force | Out-Null

try {
    @'
{
  "appid": "touristappid",
  "projectname": "preview-case"
}
'@ | Set-Content -Path (Join-Path $projectDir 'project.config.json') -Encoding ASCII

    @'
{
  "task": { "title": "preview test" },
  "target": { "template": "notebook" }
}
'@ | Set-Content -Path (Join-Path $projectDir 'build-spec.json') -Encoding ASCII

    function Get-GeneratedProjectRoot { return (Join-Path $tempRoot 'generated') }
    function Get-WechatDevtoolsPort { return 32961 }
    function Confirm-DeployAction { param([string]$Description, [bool]$RequireConfirm = $true) return $true }

    function Invoke-WechatCliCommand {
        param([string[]]$Arguments)
        return @{
            raw = @'
√ IDE server has started
× Uploading
[error] {
  "code": 10,
  "message": "Error: AppID 不合法,invalid appid"
}
'@
            parsed = $null
            exit_code = 0
            success = $true
        }
    }

    $result = Invoke-GeneratedProjectPreview -ProjectPath $projectDir -RequireConfirm $false
    Assert-Equal $result.status 'failed' 'preview should fail when CLI output contains a business error'
    Assert-Equal $result.exit_code 0 'exit code can still be zero when CLI output contains an error'
    Assert-True ($result.output -match 'invalid appid') 'preview output should preserve the underlying CLI error'

    New-TestResult -Name 'generated-project-preview' -Data @{
      pass = $true
      exit_code = 0
      status = $result.status
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
