param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-apply-component-bundle-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Invoke-ApplyComponentBundleProcess {
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
      component_name = 'product-card'
      files = @(
        @{
          path = 'components/product-card/index.wxml'
          content = '<view class="card"><slot></slot></view>'
        },
        @{
          path = 'components/product-card/index.js'
          content = 'Component({ properties: {}, data: {}, methods: {} })'
        },
        @{
          path = 'components/product-card/index.wxss'
          content = '.card { padding: 24rpx; display: flex; }'
        },
        @{
          path = 'components/product-card/index.json'
          content = '{ "component": true, "usingComponents": {} }'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $passResult = Invoke-ApplyComponentBundleProcess -Payload $validPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $passResult.exit_code 0 'valid component bundle should apply successfully'
    Assert-True (Test-Path (Join-Path $tempRoot 'components\product-card\index.js')) 'valid component bundle should write JS file'
    Assert-True ($passResult.output -match 'Wrote: components/product-card/index.js') 'valid component apply output should list written files'

    $retryPayload = @{
      component_name = 'product-card'
      files = @(
        @{
          path = 'components/product-card/index.wxml'
          content = '<div>bad</div>'
        },
        @{
          path = 'components/product-card/index.js'
          content = 'Page({ data: {} })'
        },
        @{
          path = 'components/product-card/index.wxss'
          content = '.card { padding: 24rpx; }'
        },
        @{
          path = 'components/product-card/index.json'
          content = '{ "component": true }'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $retryResult = Invoke-ApplyComponentBundleProcess -Payload $retryPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $retryResult.exit_code 1 'retryable component bundle should exit with code 1'
    Assert-True ($retryResult.output -match '\[COMPONENT GENERATION REJECTED\]') 'retryable component bundle should emit retry contract text'

    $hardPayload = @{
      component_name = 'product-card'
      files = @(
        @{
          path = 'pages/home/index.js'
          content = 'Page({})'
        }
      )
    } | ConvertTo-Json -Depth 8 -Compress

    $hardResult = Invoke-ApplyComponentBundleProcess -Payload $hardPayload -Workspace $tempRoot -ScriptPath $scriptPath
    Assert-Equal $hardResult.exit_code 2 'hard-fail component bundle should exit with code 2'
    Assert-True ($hardResult.output -match '\[FATAL COMPONENT BOUNDARY VIOLATION\]') 'hard-fail component bundle should emit fatal boundary text'

    New-TestResult -Name 'wechat-apply-component-bundle' -Data @{
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
