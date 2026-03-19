param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-bootstrap.ps1"

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-bootstrap-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$result = Invoke-WechatBootstrap -RepoRoot $tmpRoot -RunDoctor $false

Assert-Equal $result.status "success" "bootstrap should succeed"
Assert-Equal $result.doctor_status "skipped" "doctor should be skipped when RunDoctor=false"
Assert-Equal $result.repo_root ([System.IO.Path]::GetFullPath($tmpRoot)) "repo root should be normalized"
Assert-True (Test-Path (Join-Path $tmpRoot "generated")) "generated directory should exist"
Assert-True (Test-Path (Join-Path $tmpRoot "artifacts\\wechat-devtools")) "artifacts/wechat-devtools should exist"
Assert-True (Test-Path (Join-Path $tmpRoot "templates")) "templates directory should exist"
Assert-True ($result.next_steps.Count -ge 3) "bootstrap should provide next-step commands"

New-TestResult -Name "wechat-bootstrap" -Data @{
  pass      = $true
  exit_code = 0
  repo_root = $result.repo_root
}

