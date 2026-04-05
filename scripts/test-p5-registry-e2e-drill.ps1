param([hashtable]$FlowResult, [hashtable]$Context)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"
. "$PSScriptRoot\wechat-mcp-pipeline-bridge.ps1"

function Write-RegistryDrillLog {
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

$artifactsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\real-drill'
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
$logPath = Join-Path $artifactsRoot 'registry-e2e-latest.log'
$summaryPath = Join-Path $artifactsRoot 'registry-e2e-summary.json'
Set-Content -Path $logPath -Value '' -Encoding UTF8

$timings = [ordered]@{}
$overall = [System.Diagnostics.Stopwatch]::StartNew()
$prompt = 'build a product listing mini program with a CTA button'

try {
    Write-RegistryDrillLog -LogPath $logPath -Message 'registry e2e drill started'

    $doctorWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $doctor = Invoke-WechatDoctor
    $doctorWatch.Stop()
    $timings.doctor_ms = [math]::Round($doctorWatch.Elapsed.TotalMilliseconds, 2)
    Write-RegistryDrillLog -LogPath $logPath -Message ("doctor status={0} port={1}" -f $doctor.status, $doctor.port)
    Assert-In ([string]$doctor.status) @('pass', 'warn', 'ready') 'registry e2e drill requires doctor pass/warn/ready'

    $pipelineWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-RegistryDrillLog -LogPath $logPath -Message ("running pipeline prompt={0}" -f $prompt)
    $result = Invoke-McpTaskPipeline -Prompt $prompt -Open $true
    $pipelineWatch.Stop()
    $timings.pipeline_ms = [math]::Round($pipelineWatch.Elapsed.TotalMilliseconds, 2)
    Write-RegistryDrillLog -LogPath $logPath -Message ("pipeline status={0} route_mode={1}" -f $result.status, $result.route_mode)

    Assert-Equal ([string]$result.status) 'success' 'registry e2e drill pipeline should succeed'
    Assert-Equal ([string]$result.route_mode) 'product-listing' 'registry e2e drill should resolve to product-listing'
    Assert-Equal ([string]$result.bundle_sources.component) 'registry' 'registry e2e drill should load product-card from registry'
    Assert-Equal ([string]$result.bundle_sources.page) 'registry' 'registry e2e drill should load product-listing page from registry'
    Assert-True ([bool]$result.registry_hits.component) 'registry e2e drill should report component registry hit'
    Assert-True ([bool]$result.registry_hits.page) 'registry e2e drill should report page registry hit'
    Assert-NotEmpty $result.project_path 'registry e2e drill should produce a generated project path'
    Assert-True (Test-Path $result.project_path) 'registry e2e drill generated project should exist on disk'
    Assert-True (Test-Path (Join-Path $result.project_path 'pages\index\index.wxml')) 'registry e2e drill should generate pages/index/index.wxml'
    Assert-True (Test-Path (Join-Path $result.project_path 'components\product-card\index.wxml')) 'registry e2e drill should generate components/product-card/index.wxml'
    Assert-Equal ([string]$result.acceptance_result.status) 'pass' 'registry e2e drill acceptance should pass'
    Assert-In ([string]$result.open_status) @('success', 'warning') 'registry e2e drill should open or attach the project in DevTools'

    $overall.Stop()
    $timings.total_ms = [math]::Round($overall.Elapsed.TotalMilliseconds, 2)

    $summary = [ordered]@{
        drill = 'p5-registry-e2e'
        prompt = $prompt
        doctor_status = [string]$doctor.status
        devtools_port = $doctor.port
        status = [string]$result.status
        route_mode = [string]$result.route_mode
        task_family = [string]$result.task_family
        project_path = [string]$result.project_path
        bundle_sources = $result.bundle_sources
        registry_hits = $result.registry_hits
        acceptance_status = if ($null -ne $result.acceptance_result) { [string]$result.acceptance_result.status } else { 'unknown' }
        open_status = [string]$result.open_status
        preview_status = [string]$result.preview_status
        timings = $timings
        log_path = $logPath
    }
    $summary | ConvertTo-Json -Depth 12 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-RegistryDrillLog -LogPath $logPath -Message 'registry e2e drill completed'

    return New-TestResult -Name 'p5-registry-e2e-drill' -Data @{
        pass = $true
        exit_code = 0
        status = 'success'
        summary_path = $summaryPath
        project_path = $summary.project_path
        route_mode = $summary.route_mode
        registry_component = [string]$summary.bundle_sources.component
        registry_page = [string]$summary.bundle_sources.page
        open_status = $summary.open_status
        acceptance_status = $summary.acceptance_status
        total_ms = $timings.total_ms
    }
}
catch {
    $overall.Stop()
    $timings.total_ms = [math]::Round($overall.Elapsed.TotalMilliseconds, 2)
    Write-RegistryDrillLog -LogPath $logPath -Message ("registry e2e drill failed: {0}" -f $_.Exception.Message)

    $summary = [ordered]@{
        drill = 'p5-registry-e2e'
        prompt = $prompt
        status = 'failed'
        error = $_.Exception.Message
        timings = $timings
        log_path = $logPath
    }
    $summary | ConvertTo-Json -Depth 12 | Set-Content -Path $summaryPath -Encoding UTF8

    return New-TestResult -Name 'p5-registry-e2e-drill' -Data @{
        pass = $false
        exit_code = 1
        status = 'failed'
        error = $_.Exception.Message
        summary_path = $summaryPath
        total_ms = $timings.total_ms
    }
}
