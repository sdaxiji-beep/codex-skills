param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-apply-bundle-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Invoke-ApplyBundleProcess {
    param(
        [Parameter(Mandatory)][string]$Payload,
        [Parameter(Mandatory)][string]$Workspace,
        [Parameter(Mandatory)][string]$ScriptPath
    )

    $payloadFile = Join-Path $Workspace ("bundle-" + [guid]::NewGuid().ToString('N') + '.json')
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
    $validPayload = @{
      page_name = 'todo'
      files = @(
        @{
          path = 'pages/todo/index.wxml'
          content = '<view class="container"><text>{{title}}</text></view>'
        },
        @{
          path = 'pages/todo/index.js'
          content = 'Page({ data: { title: "Todo" }, onLoad() {} })'
        },
        @{
          path = 'pages/todo/index.wxss'
          content = '.container { padding: 20rpx; display: flex; }'
        },
        @{
          path = 'pages/todo/index.json'
          content = '{ "navigationBarTitleText": "Todo", "usingComponents": {} }'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $passResult = Invoke-ApplyBundleProcess -Payload $validPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $passResult.exit_code 0 'valid bundle should apply successfully'
    Assert-True (Test-Path (Join-Path $tempRoot 'pages\todo\index.js')) 'valid bundle should write JS file'
    Assert-True ($passResult.output -match 'Wrote: pages/todo/index.js') 'valid apply output should list written files'

    $retryPayload = @{
      page_name = 'todo'
      files = @(
        @{
          path = 'pages/todo/index.wxml'
          content = '<div>bad</div>'
        },
        @{
          path = 'pages/todo/index.js'
          content = 'Page({ data: {} })'
        },
        @{
          path = 'pages/todo/index.wxss'
          content = '.container { padding: 20rpx; }'
        },
        @{
          path = 'pages/todo/index.json'
          content = '{ "usingComponents": {} }'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $retryResult = Invoke-ApplyBundleProcess -Payload $retryPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $retryResult.exit_code 1 'retryable bundle should exit with code 1'
    Assert-True ($retryResult.output -match '\[GENERATION REJECTED\]') 'retryable bundle should emit retry contract text'

    $hardPayload = @{
      page_name = 'todo'
      files = @(
        @{
          path = 'app.js'
          content = 'App({})'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $hardResult = Invoke-ApplyBundleProcess -Payload $hardPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $hardResult.exit_code 2 'hard-fail bundle should exit with code 2'
    Assert-True ($hardResult.output -match '\[FATAL BOUNDARY VIOLATION\]') 'hard-fail bundle should emit fatal boundary text'

    New-TestResult -Name 'wechat-apply-bundle' -Data @{
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
