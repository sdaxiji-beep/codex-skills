param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$mcpRoot = Join-Path $repoRoot 'mcp\wechat-devtools-mcp'
$serverScript = Join-Path $mcpRoot 'src\server.ts'
$startScript = Join-Path $mcpRoot 'src\start.ts'
$probeScript = Join-Path $repoRoot 'probe-automator.js'
$deployScript = Join-Path $repoRoot 'wechat-deploy.js'
$projectState = Join-Path $repoRoot 'PROJECT_STATE.md'

Assert-True (Test-Path $serverScript) 'server.ts should exist'
Assert-True (Test-Path $startScript) 'start.ts should exist'
Assert-True (Test-Path $probeScript) 'probe-automator.js should exist'
Assert-True (Test-Path $deployScript) 'wechat-deploy.js should exist'
Assert-True (Test-Path $projectState) 'PROJECT_STATE.md should exist'

Push-Location $mcpRoot
npm run check | Out-Null
$checkCode = $LASTEXITCODE
Pop-Location
Assert-Equal $checkCode 0 'mcp TypeScript should pass npm run check'

$serverRaw = Get-Content $serverScript -Raw
@(
    'get_current_page',
    'get_page_data',
    'run_validation',
    'list_cloud_functions',
    'get_project_state'
) | ForEach-Object {
    Assert-True ($serverRaw -match [regex]::Escape($_)) "tool should exist in server.ts: $_"
}

$swProbe = [System.Diagnostics.Stopwatch]::StartNew()
$probeOut = & node $probeScript 2>$null | Out-String
$probeCode = $LASTEXITCODE
$swProbe.Stop()
Assert-True ($probeCode -in @(0, 1, 2)) "probe should return known exit codes, actual=$probeCode"
Assert-True ($swProbe.Elapsed.TotalSeconds -lt 25) "probe should finish quickly, actual=$([math]::Round($swProbe.Elapsed.TotalSeconds,2))s"

$swList = [System.Diagnostics.Stopwatch]::StartNew()
$listOut = & node $deployScript cloud-list 2>$null | Out-String
$listCode = $LASTEXITCODE
$swList.Stop()
Assert-True ($listCode -in @(0, 1)) "cloud-list should return expected exit codes, actual=$listCode"
Assert-True ($swList.Elapsed.TotalSeconds -lt 25) "cloud-list should finish quickly, actual=$([math]::Round($swList.Elapsed.TotalSeconds,2))s"

$listJsonLine = ($listOut -split "`r?`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match '^\{' } |
    Select-Object -Last 1)

if ($listCode -eq 0) {
    Assert-NotEmpty $listJsonLine 'cloud-list should return a JSON line on success'
    $listPayload = $listJsonLine | ConvertFrom-Json
    Assert-Equal $listPayload.mode 'cloud-list' 'cloud-list JSON mode should match'
    Assert-True ($listPayload.functions.Count -gt 0) 'cloud-list should include at least one function'
}

Assert-NotEmpty (Get-Content $projectState -Raw) 'PROJECT_STATE.md should be readable'

$healthReport = @{
    timestamp              = (Get-Date).ToString('o')
    probe_exit_code        = $probeCode
    cloud_list_exit_code   = $listCode
    cloud_list_ok          = ($listCode -eq 0)
    cloud_function_count   = if ($listPayload) { @($listPayload.functions).Count } else { 0 }
    probe_duration_ms      = [int][Math]::Round($swProbe.Elapsed.TotalMilliseconds)
    cloud_list_duration_ms = [int][Math]::Round($swList.Elapsed.TotalMilliseconds)
}

$artifactsRoot = Join-Path $repoRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
$healthPath = Join-Path $artifactsRoot 'mcp-readonly-health-latest.json'
$healthReport | ConvertTo-Json -Depth 6 | Set-Content -Path $healthPath -Encoding UTF8

New-TestResult -Name 'mcp-readonly-health' -Data @{
    pass                 = $true
    exit_code            = 0
    probe_exit_code      = $probeCode
    cloud_list_exit_code = $listCode
    cloud_function_count = $healthReport.cloud_function_count
    health_report        = $healthPath
}
