param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-apply-app-json-patch.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-apply-app-json-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'pages\home') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempRoot 'pages\index') -Force | Out-Null
Set-Content -Path (Join-Path $tempRoot 'pages\home\index.wxml') -Value '<view />' -Encoding ASCII
Set-Content -Path (Join-Path $tempRoot 'pages\index\index.wxml') -Value '<view />' -Encoding ASCII
@{
  pages = @('pages/index/index')
  window = @{
    navigationBarTitleText = 'Notebook'
  }
} | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempRoot 'app.json') -Encoding UTF8

function Invoke-AppJsonPatchProcess {
    param(
        [Parameter(Mandatory)][string]$Payload,
        [Parameter(Mandatory)][string]$Workspace,
        [Parameter(Mandatory)][string]$ScriptPath
    )

    $payloadFile = Join-Path $Workspace ("patch-" + [guid]::NewGuid().ToString('N') + '.json')
    $stdoutFile = Join-Path $Workspace ("stdout-" + [guid]::NewGuid().ToString('N') + '.log')
    $stderrFile = Join-Path $Workspace ("stderr-" + [guid]::NewGuid().ToString('N') + '.log')
    Set-Content -Path $payloadFile -Value $Payload -Encoding ASCII

    try {
        $process = Start-Process `
          -FilePath 'powershell' `
          -ArgumentList @('-ExecutionPolicy', 'Bypass', '-File', $ScriptPath, '-JsonFilePath', $payloadFile, '-TargetWorkspace', $Workspace) `
          -RedirectStandardOutput $stdoutFile `
          -RedirectStandardError $stderrFile `
          -Wait `
          -PassThru

        $output = ''
        if (Test-Path $stdoutFile) {
            $output += (Get-Content -Path $stdoutFile -Raw)
        }
        if (Test-Path $stderrFile) {
            if ($output) {
                $output += [Environment]::NewLine
            }
            $output += (Get-Content -Path $stderrFile -Raw)
        }

        return @{
            output = $output
            exit_code = $process.ExitCode
        }
    }
    finally {
        if (Test-Path $payloadFile) {
            Remove-Item -Path $payloadFile -Force
        }
        if (Test-Path $stdoutFile) {
            Remove-Item -Path $stdoutFile -Force
        }
        if (Test-Path $stderrFile) {
            Remove-Item -Path $stderrFile -Force
        }
    }
}

try {
    $validPayload = @{ append_pages = @('pages/home/index', 'pages/index/index') } | ConvertTo-Json -Depth 8 -Compress
    $passResult = Invoke-AppJsonPatchProcess -Payload $validPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $passResult.exit_code 0 'valid app.json patch should apply successfully'
    Assert-True ($passResult.output -match 'Registered page: pages/home/index') 'valid apply should register new page'
    Assert-True ($passResult.output -match 'Skipped existing page: pages/index/index') 'valid apply should skip duplicate pages'

    $appJson = ConvertFrom-Json -InputObject (Get-Content -Path (Join-Path $tempRoot 'app.json') -Raw -Encoding UTF8)
    Assert-Equal @($appJson.pages).Count 2 'merged app.json should contain two unique pages'
    Assert-Equal $appJson.window.navigationBarTitleText 'Notebook' 'existing non-page config should be preserved'

    $retryPayload = @{ append_pages = @('pages/missing/index') } | ConvertTo-Json -Depth 8 -Compress
    $retryResult = Invoke-AppJsonPatchProcess -Payload $retryPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $retryResult.exit_code 1 'missing page patch should be retryable'
    Assert-True ($retryResult.output -match '\[PATCH REJECTED\]') 'retryable patch should emit retry contract text'

    $hardPayload = @{ append_pages = @('pages/home/index'); window = @{ bad = $true } } | ConvertTo-Json -Depth 8 -Compress
    $hardResult = Invoke-AppJsonPatchProcess -Payload $hardPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $hardResult.exit_code 2 'extra fields should hard fail'
    Assert-True ($hardResult.output -match '\[FATAL APP.JSON PATCH VIOLATION\]') 'hard fail should emit fatal boundary text'

    New-TestResult -Name 'wechat-apply-app-json-patch' -Data @{
      pass = $true
      exit_code = 0
      retry_exit_code = $retryResult.exit_code
      hard_exit_code = $hardResult.exit_code
    }
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
