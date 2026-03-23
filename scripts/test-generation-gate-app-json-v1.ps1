param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-app-json-v1.ps1"

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-app-json-gate-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'pages\home') -Force | Out-Null
Set-Content -Path (Join-Path $tempRoot 'pages\home\index.wxml') -Value '<view />' -Encoding ASCII

try {
    $validPayload = @{ append_pages = @('pages/home/index') } | ConvertTo-Json -Depth 8 -Compress
    $validResult = Invoke-GenerationGateAppJsonV1 -JsonPayload $validPayload -TargetWorkspace $tempRoot
    Assert-Equal $validResult.Status 'pass' 'valid app.json patch should pass'
    Assert-Equal $validResult.Errors.Count 0 'valid app.json patch should not return errors'

    $missingPagePayload = @{ append_pages = @('pages/missing/index') } | ConvertTo-Json -Depth 8 -Compress
    $missingPageResult = Invoke-GenerationGateAppJsonV1 -JsonPayload $missingPagePayload -TargetWorkspace $tempRoot
    Assert-Equal $missingPageResult.Status 'retryable_fail' 'missing physical page should be retryable'

    $invalidPathPayload = @{ append_pages = @('pages/home/index.wxml') } | ConvertTo-Json -Depth 8 -Compress
    $invalidPathResult = Invoke-GenerationGateAppJsonV1 -JsonPayload $invalidPathPayload -TargetWorkspace $tempRoot
    Assert-Equal $invalidPathResult.Status 'retryable_fail' 'invalid page path format should be retryable'

    $hardFailPayload = @{ append_pages = @('pages/home/index'); window = @{ navigationBarTitleText = 'Bad' } } | ConvertTo-Json -Depth 8 -Compress
    $hardFailResult = Invoke-GenerationGateAppJsonV1 -JsonPayload $hardFailPayload -TargetWorkspace $tempRoot
    Assert-Equal $hardFailResult.Status 'hard_fail' 'extra fields should hard fail'

    New-TestResult -Name 'generation-gate-app-json-v1' -Data @{
      pass = $true
      exit_code = 0
      valid_status = $validResult.Status
      hard_fail_status = $hardFailResult.Status
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
