param([hashtable]$FlowResult, [hashtable]$Context)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

function Write-SimplifiedDrillLog {
    param(
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

$artifactsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\real-drill'
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
$logPath = Join-Path $artifactsRoot 'simplified-latest.log'
$summaryPath = Join-Path $artifactsRoot 'simplified-summary.json'
Set-Content -Path $logPath -Value '' -Encoding UTF8

$timings = [ordered]@{}
$overall = [System.Diagnostics.Stopwatch]::StartNew()
$prompt = 'build a product listing mini program'

try {
    Write-SimplifiedDrillLog -LogPath $logPath -Message 'simplified drill started'

    $doctorWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-SimplifiedDrillLog -LogPath $logPath -Message 'running doctor'
    $doctor = Invoke-WechatDoctor
    $doctorWatch.Stop()
    $timings.doctor_ms = [math]::Round($doctorWatch.Elapsed.TotalMilliseconds, 2)
    Write-SimplifiedDrillLog -LogPath $logPath -Message ("doctor complete status={0} port={1}" -f $doctor.status, $doctor.port)

    if ([string]$doctor.status -notin @('pass', 'warn', 'ready')) {
        throw "Environment not ready: $($doctor.status)"
    }

    $translateWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-SimplifiedDrillLog -LogPath $logPath -Message ("translating prompt: {0}" -f $prompt)
    $translation = Invoke-WechatTaskTranslator -TaskText $prompt
    $translateWatch.Stop()
    $timings.translation_ms = [math]::Round($translateWatch.Elapsed.TotalMilliseconds, 2)
    Write-SimplifiedDrillLog -LogPath $logPath -Message ("translator complete status={0}" -f $translation.status)

    Assert-Equal $translation.status 'success' 'simplified drill translator should succeed'
    Assert-NotEmpty $translation.task_spec 'simplified drill requires task_spec'
    Assert-NotEmpty $translation.task_spec.task_intent 'simplified drill requires task_intent'

    $execWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-SimplifiedDrillLog -LogPath $logPath -Message 'running task execution (open=true, preview=false)'
    $execution = Invoke-WechatTaskExecution `
        -TaskSpec $translation.task_spec `
        -PageBundle $translation.page_bundle `
        -ComponentBundle $translation.component_bundle `
        -AppPatch $translation.app_patch `
        -Open $true `
        -Preview $false
    $execWatch.Stop()
    $timings.execution_ms = [math]::Round($execWatch.Elapsed.TotalMilliseconds, 2)
    Write-SimplifiedDrillLog -LogPath $logPath -Message ("execution complete status={0} open={1}" -f $execution.status, $execution.open_result.status)

    $overall.Stop()
    $timings.total_ms = [math]::Round($overall.Elapsed.TotalMilliseconds, 2)

    $summary = [ordered]@{
        real_drill = 'simplified'
        prompt = $prompt
        doctor_status = [string]$doctor.status
        devtools_port = $doctor.port
        translator_status = [string]$translation.status
        task_intent = [string]$translation.task_spec.task_intent
        execution_status = [string]$execution.status
        open_status = if ($execution.PSObject.Properties.Name -contains 'open_result') { [string]$execution.open_result.status } else { 'unknown' }
        preview_status = if ($execution.PSObject.Properties.Name -contains 'preview_result') { [string]$execution.preview_result.status } else { 'skipped' }
        project_dir = if ($execution.PSObject.Properties.Name -contains 'project_dir') { [string]$execution.project_dir } else { '' }
        timings = $timings
        log_path = $logPath
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-SimplifiedDrillLog -LogPath $logPath -Message 'simplified drill completed'

    if ([string]$execution.status -eq 'success') {
        return New-TestResult -Name 'p5-e2e-simplified-drill' -Data @{
            pass = $true
            exit_code = 0
            status = 'success'
            summary_path = $summaryPath
            project_dir = $summary.project_dir
            open_status = $summary.open_status
            preview_status = $summary.preview_status
            total_ms = $timings.total_ms
            log_path = $logPath
        }
    }

    return New-TestResult -Name 'p5-e2e-simplified-drill' -Data @{
        pass = $false
        exit_code = 1
        status = [string]$execution.status
        summary_path = $summaryPath
        project_dir = $summary.project_dir
        open_status = $summary.open_status
        preview_status = $summary.preview_status
        total_ms = $timings.total_ms
        log_path = $logPath
    }
}
catch {
    $overall.Stop()
    $timings.total_ms = [math]::Round($overall.Elapsed.TotalMilliseconds, 2)
    Write-SimplifiedDrillLog -LogPath $logPath -Message ("simplified drill failed: {0}" -f $_.Exception.Message)

    $summary = [ordered]@{
        real_drill = 'simplified'
        prompt = $prompt
        status = 'failed'
        error = $_.Exception.Message
        timings = $timings
        log_path = $logPath
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8

    return New-TestResult -Name 'p5-e2e-simplified-drill' -Data @{
        pass = $false
        exit_code = 1
        status = 'failed'
        error = $_.Exception.Message
        summary_path = $summaryPath
        total_ms = $timings.total_ms
        log_path = $logPath
    }
}
